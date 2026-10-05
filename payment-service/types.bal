public enum PaymentStatus {
    COMPLETED,
    FAILED,
    REFUNDED
}

public type Payment record {|
    string paymentId;
    string orderId;
    string customerId;
    float amount;
    string method;
    PaymentStatus status;
    string? reason = ();   // set when FAILED
    string createdAt;
    string updatedAt;
|};

// Same envelope as every other service (see kafka/TOPICS.md)
public type EventEnvelope record {|
    string eventId;
    string eventType;
    string occurredAt;
    string orderId;
    string sourceService;
    int schemaVersion = 1;
    json payload;
|};
