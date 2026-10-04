import ballerinax/mongodb;

configurable string mongoHost = "localhost";
configurable int mongoPort = 27017;
configurable string mongoDb = "orders_db";

final mongodb:Client mongoClient = check new ({
    connection: {serverAddress: {host: mongoHost, port: mongoPort}}
});

function orders() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDb);
    return db->getCollection("orders");
}

public function insertOrder(Order o) returns error? {
    mongodb:Collection col = check orders();
    check col->insertOne(o);
}

public function findOrder(string id) returns Order|error? {
    mongodb:Collection col = check orders();
    return col->findOne({id: id}, projection = {"_id": 0}, targetType = Order);
}

public function findOrders(string? customerId, string? restaurantId, string? status) returns Order[]|error {
    mongodb:Collection col = check orders();
    map<json> filter = {};
    if customerId is string { filter["customerId"] = customerId; }
    if restaurantId is string { filter["restaurantId"] = restaurantId; }
    if status is string { filter["status"] = status; }
    stream<Order, error?> s = check col->find(filter, projection = {"_id": 0}, targetType = Order);
    return from Order o in s select o;
}


public function saveTransition(Order o, int expectedVersion) returns boolean|error {
    mongodb:Collection col = check orders();
    mongodb:UpdateResult r = check col->updateOne(
        {id: o.id, version: expectedVersion},
        {set: {status: o.status, history: o.history.toJson(), version: o.version, updatedAt: o.updatedAt}}
    );
    return r.modifiedCount == 1;
}
