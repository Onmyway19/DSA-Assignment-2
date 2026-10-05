import ballerina/log;
import ballerinax/kafka;
import ballerina/http;
import ballerinax/mongodb;

listener kafka:Listener notificationListener = new (kafkaBootstrap, {
    groupId: "notification-service",
    topics: ["orders.created", "orders.status-changed", "payments.completed",
             "payments.failed", "delivery.assigned", "delivery.picked-up",
             "delivery.completed", "notifications.requests"],
    autoCommit: false,
    offsetReset: kafka:OFFSET_RESET_EARLIEST
});

service on notificationListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            check processNotificationRecord(rec);
        }
        check caller->commit();
    }
}

function processNotificationRecord(kafka:BytesConsumerRecord rec) returns error? {
    string raw = check string:fromBytes(rec.value);
    NotificationEvent event = check (check raw.fromJsonString()).cloneWithType();
    string topic = rec.offset.partition.topic;
    map<json> payload = event.payload;

    if topic == "notifications.requests" {
        string recipientType = payloadString(payload, "recipientType");
        string recipientId = payloadString(payload, "recipientId");
        string channel = payloadString(payload, "channel");
        string message = payloadString(payload, "message");
        if recipientType == "" || recipientId == "" || message == "" ||
                channels.indexOf(channel) is () ||
                (recipientType != "CUSTOMER" && recipientType != "RESTAURANT" &&
                 recipientType != "DRIVER") {
            return error("Invalid notification request: recipientType, recipientId, channel and message are required");
        }
        return dispatchNotification(event, recipientType, recipientId, channel, message);
    }

    string customerId = payloadString(payload, "customerId");
    string restaurantId = payloadString(payload, "restaurantId");
    if topic == "orders.created" {
        check cacheOrderRecipients(event, customerId, restaurantId);
    } else if customerId == "" || restaurantId == "" {
        OrderRecipients? recipients = check findOrderRecipients(event.orderId);
        if recipients is OrderRecipients {
            if customerId == "" {
                customerId = recipients.customerId;
            }
            if restaurantId == "" {
                restaurantId = recipients.restaurantId;
            }
        }
    }

    string message = notificationMessage(event, payload);
    match topic {
        "orders.created" => {
            check dispatchIfPresent(event, "CUSTOMER", customerId, message);
            check dispatchIfPresent(event, "RESTAURANT", restaurantId, message);
        }
        "orders.status-changed" => {
            check dispatchIfPresent(event, "CUSTOMER", customerId, message);
            check dispatchIfPresent(event, "RESTAURANT", restaurantId, message);
            check dispatchIfPresent(event, "DRIVER", payloadString(payload, "driverId"), message);
        }
        "payments.completed"|"payments.failed" => {
            check dispatchIfPresent(event, "CUSTOMER", customerId, message);
        }
        "delivery.assigned" => {
            check dispatchIfPresent(event, "CUSTOMER", customerId, message);
            check dispatchIfPresent(event, "DRIVER", payloadString(payload, "driverId"), message);
        }
        "delivery.picked-up"|"delivery.completed" => {
            check dispatchIfPresent(event, "CUSTOMER", customerId, message);
            check dispatchIfPresent(event, "RESTAURANT", restaurantId, message);
            check dispatchIfPresent(event, "DRIVER", payloadString(payload, "driverId"), message);
        }
    }
}

function cacheOrderRecipients(NotificationEvent event, string customerId, string restaurantId)
        returns error? {
    mongodb:Collection collection = check recipientsCollection();
    record {}|() existing = check collection->findOne({orderId: event.orderId});
    if existing is record {} {
        return;
    }
    OrderRecipients recipients = {
        _id: event.orderId,
        orderId: event.orderId,
        customerId,
        restaurantId
    };
    check collection->insertOne(recipients);
}

function findOrderRecipients(string orderId) returns OrderRecipients?|error {
    mongodb:Collection collection = check recipientsCollection();
    record {}|() result = check collection->findOne({orderId}, projection = {"_id": 0});
    if result is record {} {
        return check result.cloneWithType();
    }
    return ();
}

function dispatchIfPresent(NotificationEvent event, string recipientType, string recipientId, string message)
        returns error? {
    if recipientId == "" {
        return;
    }
    foreach string channel in channels {
        check dispatchNotification(event, recipientType, recipientId, channel, message);
    }
}

function notificationMessage(NotificationEvent event, map<json> payload) returns string {
    string status = payloadString(payload, "newStatus");
    if status == "" {
        status = payloadString(payload, "status");
    }
    if status == "" {
        status = event.eventType;
    }
    return "Order " + event.orderId + ": " + status + ".";
}

function dispatchNotification(NotificationEvent event, string recipientType, string recipientId,
        string channel, string message) returns error? {
    string deliveryId = event.eventId + ":" + recipientType + ":" + recipientId + ":" + channel;
    mongodb:Collection collection = check notificationsCollection();
    record {}|() saved = check collection->findOne({id: deliveryId}, projection = {"_id": 0});

    if saved is record {} {
        NotificationDelivery existing = check saved.cloneWithType();
        if existing.status == "SENT" || existing.status == "SIMULATED" {
            return;
        }
    } else {
        string timestamp = notificationTime();
        NotificationDelivery delivery = {
            _id: deliveryId,
            id: deliveryId,
            eventId: event.eventId,
            orderId: event.orderId,
            recipientType,
            recipientId,
            channel,
            message,
            status: "PENDING",
            createdAt: timestamp,
            updatedAt: timestamp
        };
        check collection->insertOne(delivery);
    }

    string endpoint = channelWebhook(channel);
    string resultStatus = "SIMULATED";
    if endpoint == "" {
        log:printInfo("Notification channel has no webhook; recording simulated delivery",
            recipientType = recipientType, recipientId = recipientId, channel = channel,
            eventId = event.eventId);
    } else {
        http:Client client = check new (endpoint);
        http:Response response = check client->post("/", {
            deliveryId,
            eventId: event.eventId,
            orderId: event.orderId,
            recipientType,
            recipientId,
            channel,
            message
        });
        if response.statusCode < 200 || response.statusCode >= 300 {
            return error("Notification webhook returned HTTP " + response.statusCode.toString());
        }
        resultStatus = "SENT";
    }

    check collection->updateOne({id: deliveryId}, {
        set: {status: resultStatus, updatedAt: notificationTime()}
    });
    log:printInfo("Notification processed", recipientType = recipientType,
        recipientId = recipientId, channel = channel, status = resultStatus);
}

function channelWebhook(string channel) returns string {
    match channel {
        "EMAIL" => return emailWebhook;
        "SMS" => return smsWebhook;
        "PUSH" => return pushWebhook;
    }
    return "";
}
