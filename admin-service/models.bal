import ballerina/time;
import ballerinax/mongodb;

public type AdminEvent record {|
    string _id?;
    string eventId;
    string eventType;
    string occurredAt;
    string orderId;
    string sourceService;
    int schemaVersion = 1;
    string topic;
    map<json> payload;
|};

type AdminEventEnvelope record {|
    string eventId;
    string eventType;
    string occurredAt;
    string orderId;
    string sourceService;
    int schemaVersion = 1;
    map<json> payload;
|};

configurable string kafkaBootstrap = "localhost:9092";
configurable string mongoUrl = "mongodb://localhost:27017";
configurable string mongoDb = "admin_db";

final mongodb:Client mongoClient = check new ({connection: mongoUrl});

function eventsCollection() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDb);
    return db->getCollection("events");
}

function payloadString(map<json> payload, string key) returns string {
    if payload.hasKey(key) {
        return payload[key].toString();
    }
    return "";
}

function isWithinRange(string occurredAt, string? startAt, string? endAt) returns boolean {
    if startAt is string && occurredAt < startAt {
        return false;
    }
    if endAt is string && occurredAt > endAt {
        return false;
    }
    return true;
}

function elapsedMinutes(string startAt, string endAt) returns float|error {
    time:Utc start = check time:utcFromString(startAt);
    time:Utc end = check time:utcFromString(endAt);
    time:Seconds seconds = time:utcDiffSeconds(end, start);
    if seconds < 0.0 {
        return error("Event timestamp precedes its starting timestamp");
    }
    return seconds.toFloat() / 60.0;
}
