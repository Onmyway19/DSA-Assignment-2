import ballerinax/mongodb;

configurable string mongoHost = "localhost";
configurable int mongoPort = 27017;
configurable string mongoDb = "delivery_db";

final mongodb:Client mongoClient = check new ({
    connection: {serverAddress: {host: mongoHost, port: mongoPort}}
});

function deliveries() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDb);
    return db->getCollection("deliveries");
}

public function insertDelivery(Delivery d) returns error? {
    mongodb:Collection col = check deliveries();
    check col->insertOne(d);
}

public function findDelivery(string orderId) returns Delivery|error? {
    mongodb:Collection col = check deliveries();
    return col->findOne({orderId: orderId}, projection = {"_id": 0}, targetType = Delivery);
}

public function findDeliveries(string? driverId, string? status) returns Delivery[]|error {
    mongodb:Collection col = check deliveries();
    map<json> filter = {};
    if driverId is string { filter["driverId"] = driverId; }
    if status is string { filter["status"] = status; }
    stream<Delivery, error?> s = check col->find(filter, projection = {"_id": 0}, targetType = Delivery);
    return from Delivery d in s select d;
}

// How many open deliveries does this driver have? Used to pick the least-busy driver.
public function activeCount(string driverId) returns int|error {
    mongodb:Collection col = check deliveries();
    map<json> filter = {driverId: driverId, status: {"$in": ["ASSIGNED", "PICKED_UP"]}};
    return col->countDocuments(filter);
}

public function updateDelivery(string orderId, map<json> fields) returns error? {
    mongodb:Collection col = check deliveries();
    _ = check col->updateOne({orderId: orderId}, {set: fields});
}
