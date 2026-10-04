import ballerinax/mongodb;
public isolated function getDatabase() returns mongodb:Database|error {
    mongodb:Client mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    return mongoClient->getDatabase("restaurant_db");
}