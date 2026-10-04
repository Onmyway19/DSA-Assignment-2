import ballerina/time;
import ballerinax/mongodb;

public type NotificationEvent record {|
    string eventId;
    string eventType;
    string occurredAt;
    string orderId;
    string sourceService;
    int schemaVersion = 1;
    map<json> payload;
|};

public type NotificationDelivery record {|
    string _id?;
    string id;
    string eventId;
    string orderId;
    string recipientType;
    string recipientId;
    string channel;
    string message;
    string status;
    string createdAt;
    string updatedAt;
|};

type OrderRecipients record {|
    string _id?;
    string orderId;
    string customerId;
    string restaurantId;
|};

configurable string kafkaBootstrap = "localhost:9092";
configurable string mongoUrl = "mongodb://localhost:27017";
configurable string mongoDb = "notification_db";
configurable string emailWebhook = "";
configurable string smsWebhook = "";
configurable string pushWebhook = "";

final mongodb:Client mongoClient = check new ({connection: mongoUrl});
final string[] channels = ["EMAIL", "SMS", "PUSH"];

function notificationsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDb);
    return db->getCollection("deliveries");
}

function recipientsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDb);
    return db->getCollection("order_recipients");
}

function notificationTime() returns string => time:utcToString(time:utcNow());

function payloadString(map<json> payload, string key) returns string {
    if payload.hasKey(key) {
        return payload[key].toString();
    }
    return "";
}
