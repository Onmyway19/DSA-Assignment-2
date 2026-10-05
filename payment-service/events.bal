import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

public const TOPIC_ORDERS_CREATED = "orders.created";
public const TOPIC_ORDERS_CANCELLED = "orders.cancelled";
public const TOPIC_PAYMENTS_COMPLETED = "payments.completed";
public const TOPIC_PAYMENTS_FAILED = "payments.failed";

final kafka:Producer producer = check new (kafkaBootstrap, {
    clientId: "payment-service-producer",
    acks: kafka:ACKS_ALL,
    retryCount: 5,
    enableIdempotence: true
});

function nowIso() returns string => time:utcToString(time:utcNow());

// Key = orderId so all events of one order land on the same partition (contract rule)
public function publish(string topic, string eventType, string orderId, json payload) returns error? {
    EventEnvelope ev = {
        eventId: uuid:createType4AsString(),
        eventType,
        occurredAt: nowIso(),
        orderId,
        sourceService: "payment-service",
        payload
    };
    check producer->send({
        topic,
        key: orderId.toBytes(),
        value: ev.toJsonString().toBytes()
    });
    check producer->'flush();
}
