import ballerina/log;
import ballerina/uuid;
import ballerinax/kafka;

configurable float maxPaymentAmount = 1000.0;

listener kafka:Listener paymentListener = new (kafkaBootstrap, {
    groupId: "payment-service",          // own consumer group = service name (contract rule)
    topics: [TOPIC_ORDERS_CREATED, TOPIC_ORDERS_CANCELLED],
    autoCommit: false,                   // manual commit after the batch is processed
    offsetReset: kafka:OFFSET_RESET_EARLIEST
});

service on paymentListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            error? res = processRecord(rec);
            if res is error {
                // bad/poison message: log and move on so one event can't block the partition
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
        "orders.created" => { check handleOrderCreated(ev); }
        "orders.cancelled" => { check handleOrderCancelled(ev); }
    }
}

function handleOrderCreated(EventEnvelope ev) returns error? {
    // Idempotency: a duplicate orders.created must not charge twice.
    // We re-publish the stored outcome instead, which also heals a crash between "save" and "publish".
    Payment? existing = check findPaymentByOrder(ev.orderId);
    if existing is Payment {
        log:printInfo("Duplicate orders.created, re-publishing stored outcome", orderId = ev.orderId);
        return publishOutcome(existing);
    }

    string customerId = (check ev.payload.customerId).toString();
    float amount = check float:fromString((check ev.payload.totalAmount).toString());

    // Simulated payment gateway: deterministic so the demo is predictable
    boolean approved = amount > 0.0 && amount <= maxPaymentAmount;
    string ts = nowIso();
    Payment p = {
        paymentId: uuid:createType4AsString(),
        orderId: ev.orderId,
        customerId,
        amount,
        method: "CARD",
        status: approved ? COMPLETED : FAILED,
        reason: approved ? () : "INSUFFICIENT_FUNDS",
        createdAt: ts,
        updatedAt: ts
    };
    check insertPayment(p);
    check publishOutcome(p);
}

function publishOutcome(Payment p) returns error? {
    if p.status == FAILED {
        check publish(TOPIC_PAYMENTS_FAILED, "PaymentFailed", p.orderId,
            {paymentId: p.paymentId, reason: p.reason});
    } else {
        // COMPLETED (or REFUNDED later on): the payment itself did succeed
        check publish(TOPIC_PAYMENTS_COMPLETED, "PaymentCompleted", p.orderId,
            {paymentId: p.paymentId, amount: p.amount, method: p.method});
    }
}

// Order cancelled after we charged the customer -> refund. Cancellation caused by our own
// payments.failed finds no COMPLETED payment, so nothing happens.
function handleOrderCancelled(EventEnvelope ev) returns error? {
    Payment? p = check findPaymentByOrder(ev.orderId);
    if p is () || p.status != COMPLETED {
        return;
    }
    check markRefunded(ev.orderId);
    log:printInfo("Payment refunded", orderId = ev.orderId, paymentId = p.paymentId);
}
