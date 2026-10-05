import ballerina/time;
import ballerina/uuid;
import ballerinax/kafka;

configurable string kafkaBootstrap = "localhost:9092";

public const TOPIC_RESTAURANT_ORDER_STATUS = "restaurant.order.status";

final readonly & string[] ALLOWED_STATUSES = ["PREPARING", "READY", "REJECTED"];

public type OrderStatusUpdate record {|
    string status;
    string reason?;
|};

final kafka:Producer producer = check new (kafkaBootstrap, {
    clientId: "restaurant-service-producer",
    acks: kafka:ACKS_ALL,
    retryCount: 5,
    enableIdempotence: true
});

public function publishOrderStatus(string restaurantId, string orderId, string status, string? reason)
        returns error? {
    json payload = {status: status, restaurantId: restaurantId};
    if reason is string {
        payload = {status: status, restaurantId: restaurantId, reason: reason};
    }
    json envelope = {
        eventId: uuid:createType4AsString(),
        eventType: "RestaurantOrderStatus",
        occurredAt: time:utcToString(time:utcNow()),
        orderId: orderId,
        sourceService: "restaurant-service",
        schemaVersion: 1,
        payload: payload
    };
    check producer->send({
        topic: TOPIC_RESTAURANT_ORDER_STATUS,
        key: orderId.toBytes(),
        value: envelope.toJsonString().toBytes()
    });
    check producer->'flush();
}
