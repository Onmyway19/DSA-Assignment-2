import ballerina/log;
import ballerinax/kafka;


listener kafka:Listener orderListener = new (kafkaBootstrap, {
    groupId: "order-service",
    topics: ["payments.completed", "payments.failed", "restaurant.order.status",
             "delivery.picked-up", "delivery.completed"],
    autoCommit: false,
    offsetReset: kafka:OFFSET_RESET_EARLIEST
});

service on orderListener {
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
        "payments.completed" => { _ = check applyTransition(ev.orderId, CONFIRMED, "PAYMENT", ()); }
        "payments.failed" => { _ = check applyTransition(ev.orderId, CANCELLED, "PAYMENT", "Payment failed"); }
        "delivery.picked-up" => { _ = check applyTransition(ev.orderId, OUT_FOR_DELIVERY, "DELIVERY", ()); }
        "delivery.completed" => { _ = check applyTransition(ev.orderId, DELIVERED, "DELIVERY", ()); }
        "restaurant.order.status" => {
            json s = check ev.payload.status;
            string st = s.toString();
            if st == "REJECTED" {
                _ = check applyTransition(ev.orderId, CANCELLED, "RESTAURANT", "Rejected by restaurant");
            } else if st == "PREPARING" {
                _ = check applyTransition(ev.orderId, PREPARING, "RESTAURANT", ());
            } else if st == "READY" {
                _ = check applyTransition(ev.orderId, READY, "RESTAURANT", ());
            }
        }
    }
}
