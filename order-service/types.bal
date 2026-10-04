
public enum OrderStatus {
    CREATED,
    CONFIRMED,
    PREPARING,
    READY,
    OUT_FOR_DELIVERY,
    DELIVERED,
    CANCELLED
}

public type OrderItem record {|
    string menuItemId;
    string name;
    int quantity;
    float unitPrice;
|};

public type StatusChange record {|
    OrderStatus status;
    string changedAt;
    string changedBy;   // CUSTOMER | RESTAURANT | PAYMENT | DELIVERY | ADMIN | SYSTEM
    string? reason = ();
|};

public type Order record {|
    string id;
    string customerId;
    string restaurantId;
    OrderItem[] items;
    string deliveryAddress;
    float totalAmount;
    OrderStatus status;
    StatusChange[] history;
    int version;        
    string createdAt;
    string updatedAt;
|};

// Payloads
public type NewOrder record {|
    string customerId;
    string restaurantId;
    OrderItem[] items;
    string deliveryAddress;
|};

public type StatusUpdate record {|
    OrderStatus status;
    string actor;
    string? reason = ();
|};

public type CancelRequest record {|
    string actor;
    string? reason = ();
|};

//  Kafka event envelope 
public type EventEnvelope record {|
    string eventId;
    string eventType;
    string occurredAt;
    string orderId;
    string sourceService;
    int schemaVersion = 1;
    json payload;
|};
