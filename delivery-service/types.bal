public enum DeliveryStatus {
    ASSIGNED,
    PICKED_UP,
    DELIVERED,
    CANCELLED
}

public type Delivery record {|
    string deliveryId;
    string orderId;
    string customerId;
    string restaurantId;
    string driverId;
    int etaMinutes;
    DeliveryStatus status;
    string assignedAt;
    string? pickedUpAt = ();
    string? deliveredAt = ();
    string updatedAt;
|};

public type EventEnvelope record {|
    string eventId;
    string eventType;
    string occurredAt;
    string orderId;
    string sourceService;
    int schemaVersion = 1;
    json payload;
|};
