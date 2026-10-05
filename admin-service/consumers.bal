import ballerina/log;
import ballerinax/kafka;
import ballerinax/mongodb;

listener kafka:Listener adminListener = new (kafkaBootstrap, {
    groupId: "admin-service",
    topics: ["orders.created", "orders.status-changed", "delivery.assigned",
             "delivery.picked-up", "delivery.completed"],
    autoCommit: false,
    offsetReset: kafka:OFFSET_RESET_EARLIEST
});

service on adminListener {
    remote function onConsumerRecord(kafka:Caller caller, kafka:BytesConsumerRecord[] records) returns error? {
        foreach kafka:BytesConsumerRecord rec in records {
            check storeAdminEvent(rec);
        }
        check caller->commit();
    }
}

function storeAdminEvent(kafka:BytesConsumerRecord rec) returns error? {
    string raw = check string:fromBytes(rec.value);
    AdminEventEnvelope event = check (check raw.fromJsonString()).cloneWithType();
    mongodb:Collection collection = check eventsCollection();
    record {}|() existing = check collection->findOne({eventId: event.eventId});
    if existing is record {} {
        return;
    }

    AdminEvent stored = {
        _id: event.eventId,
        eventId: event.eventId,
        eventType: event.eventType,
        occurredAt: event.occurredAt,
        orderId: event.orderId,
        sourceService: event.sourceService,
        schemaVersion: event.schemaVersion,
        topic: rec.offset.partition.topic,
        payload: event.payload
    };
    check collection->insertOne(stored);
    log:printInfo("Admin event stored", eventId = event.eventId,
        topic = rec.offset.partition.topic);
}
