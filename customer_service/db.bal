import ballerinax/mongodb;
public isolated function getMongoClient() returns mongodb:Client|error {
    
    mongodb:Client mongoClient = check new ({
        connection: "mongodb://localhost:27017"
    });
    return mongoClient;
}
