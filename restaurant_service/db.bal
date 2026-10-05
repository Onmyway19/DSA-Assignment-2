import ballerinax/mongodb;

configurable string dbUrl = "mongodb://localhost:27017";

final mongodb:Client mongoClient = check new ({
    connection: dbUrl
});

public isolated function getDatabase() returns mongodb:Database|error {
    return mongoClient->getDatabase("restaurant_db");
}