import ballerinax/mongodb;

configurable string mongoHost = "localhost";
configurable int mongoPort = 27017;
configurable string mongoDb = "payments_db";

final mongodb:Client mongoClient = check new ({
    connection: {serverAddress: {host: mongoHost, port: mongoPort}}
});

function payments() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase(mongoDb);
    return db->getCollection("payments");
}

public function insertPayment(Payment p) returns error? {
    mongodb:Collection col = check payments();
    check col->insertOne(p);
}

public function findPaymentByOrder(string orderId) returns Payment|error? {
    mongodb:Collection col = check payments();
    return col->findOne({orderId: orderId}, projection = {"_id": 0}, targetType = Payment);
}

public function findPayments(string? status) returns Payment[]|error {
    mongodb:Collection col = check payments();
    map<json> filter = {};
    if status is string { filter["status"] = status; }
    stream<Payment, error?> s = check col->find(filter, projection = {"_id": 0}, targetType = Payment);
    return from Payment p in s select p;
}

public function markRefunded(string orderId) returns error? {
    mongodb:Collection col = check payments();
    _ = check col->updateOne(
        {orderId: orderId, status: "COMPLETED"},
        {set: {status: "REFUNDED", updatedAt: nowIso()}}
    );
}
