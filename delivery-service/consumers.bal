import ballerina/log;
import ballerina/uuid;
import ballerinax/kafka;

configurable string[] drivers = ["d1", "d2", "d3"];
configurable int etaMinutes = 25;

listener kafka:Listener deliveryListener = new (kafkaBootstrap, {
    groupId: "delivery-service",
    topics: [TOPIC_ORDERS_STATUS, TOPIC_ORDERS_CANCELLED],
    autoCommit: false,
    offsetReset: kafka:OFFSET_RESET_EARLIEST
});

service on deliveryListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            error? res = processRecord(rec);
            if res is error {
                log:printError("Failed to process event", 'error = res);
            }
        }
        check caller->commit();
    }
}

function processRecord(kafka:BytesConsumerRecord rec) returns error? {
    string raw = check string:fromBytes(rec.value);
    EventEnvelope ev = check (check raw.fromJsonString()).cloneWithType();
    string topic = rec.offset.partition.topic;

    match topic {
        "orders.status-changed" => {
            string newStatus = (check ev.payload.newStatus).toString();
            if newStatus == "READY" {
                check assignDriver(ev);
            }
        }
        "orders.cancelled" => { check cancelDelivery(ev.orderId); }
    }
}

// Order is READY -> pick a driver and announce it.
function assignDriver(EventEnvelope ev) returns error? {
    // Idempotent: one delivery per order, duplicates are ignored
    Delivery? existing = check findDelivery(ev.orderId);
    if existing is Delivery {
        log:printInfo("Delivery already assigned, ignoring duplicate", orderId = ev.orderId);
        return;
    }
    string driverId = check pickDriver();
    string ts = nowIso();
    Delivery d = {
        deliveryId: uuid:createType4AsString(),
        orderId: ev.orderId,
        customerId: (check ev.payload.customerId).toString(),
        restaurantId: (check ev.payload.restaurantId).toString(),
        driverId,
        etaMinutes,
        status: ASSIGNED,
        assignedAt: ts,
        updatedAt: ts
    };
    check insertDelivery(d);
    check publish(TOPIC_DELIVERY_ASSIGNED, "DeliveryAssigned", d.orderId,
        {driverId: d.driverId, etaMinutes: d.etaMinutes});
}

// Least-busy driver wins (ties -> first in the list)
function pickDriver() returns string|error {
    string best = drivers[0];
    int bestLoad = int:MAX_VALUE;
    foreach string d in drivers {
        int load = check activeCount(d);
        if load < bestLoad {
            best = d;
            bestLoad = load;
        }
    }
    return best;
}

function cancelDelivery(string orderId) returns error? {
    Delivery? d = check findDelivery(orderId);
    if d is () || d.status != ASSIGNED {
        return;
    }
    check updateDelivery(orderId, {status: "CANCELLED", updatedAt: nowIso()});
}
