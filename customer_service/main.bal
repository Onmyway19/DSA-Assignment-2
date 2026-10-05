import ballerina/http;
import ballerina/time;
import ballerina/uuid;
import ballerinax/mongodb;


configurable string dbUrl = "mongodb://localhost:27017";
configurable int servicePort = 8084;

final mongodb:Client mongoClient = check new ({
    connection: dbUrl
});

function customers() returns mongodb:Collection|error {
    mongodb:Database db = check mongoClient->getDatabase("food_delivery");
    return db->getCollection("customers");
}

service /customers on new http:Listener(servicePort) {

    resource function post .(@http:Payload CustomerCreatePayload payload) returns http:Created|http:InternalServerError {
        do {
            mongodb:Collection customersCol = check customers();

            
            Customer customer = {
                id: uuid:createType4AsString(),
                createdAt: time:utcToString(time:utcNow()),
                ...payload
            };
            check customersCol->insertOne(customer);
            return <http:Created>{body: customer};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Failed to create customer: " + e.message()}};
        }
    }

    resource function get [string id]() returns Customer|http:NotFound|http:InternalServerError {
        do {
            mongodb:Collection customersCol = check customers();

            record {}|() result = check customersCol->findOne({id: id});
            if result is record {} {
             
                _ = result.removeIfHasKey("_id");
                Customer customer = check result.cloneWithType(Customer);
                return customer;
            }
            return <http:NotFound>{body: {message: "Customer profile not found"}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Database query error: " + e.message()}};
        }
    }
}
