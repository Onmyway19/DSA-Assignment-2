import ballerina/http;
import ballerinax/mongodb;


configurable string dbUrl = "mongodb://localhost:27017";

function getDatabase() returns mongodb:Database|error {
    mongodb:Client mongoClient = check new ({
        connection: dbUrl
    });
    return mongoClient->getDatabase("food_delivery");
}

service /customers on new http:Listener(8081) {

    resource function post .(@http:Payload Customer payload) returns http:Created|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection customersCol = check db->getCollection("customers");

            check customersCol->insertOne(payload);
            return <http:Created>{body: payload};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Failed to create customer: " + e.message()}};
        }
    }

    resource function get [string id]() returns Customer|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection customersCol = check db->getCollection("customers");

            record {}|() result = check customersCol->findOne({id: id});
            if result is record {} {
                Customer customer = check result.cloneWithType(Customer);
                return customer;
            }
            return <http:NotFound>{body: {message: "Customer profile not found"}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Database query error: " + e.message()}};
        }
    }
}
