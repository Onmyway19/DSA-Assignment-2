import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

public const TOPIC_ORDERS_STATUS = "orders.status-changed";
public const TOPIC_ORDERS_CANCELLED = "orders.cancelled";
public const TOPIC_DELIVERY_ASSIGNED = "delivery.assigned";
public const TOPIC_DELIVERY_PICKED_UP = "delivery.picked-up";
public const TOPIC_DELIVERY_COMPLETED = "delivery.completed";

final kafka:Producer producer = check new (kafkaBootstrap, {
    clientId: "delivery-service-producer",
    acks: kafka:ACKS_ALL,
    retryCount: 5,
    enableIdempotence: true
});

function nowIso() returns string => time:utcToString(time:utcNow());

public function publish(string topic, string eventType, string orderId, json payload) returns error? {
    EventEnvelope ev = {
        eventId: uuid:createType4AsString(),
        eventType,
        occurredAt: nowIso(),
        orderId,
        sourceService: "delivery-service",
        payload
    };
    check producer->send({
        topic,
        key: orderId.toBytes(),
        value: ev.toJsonString().toBytes()
    });
    check producer->'flush();
}
