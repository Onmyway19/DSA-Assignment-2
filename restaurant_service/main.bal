import ballerina/http;
import ballerinax/mongodb;
import ballerina/time;

configurable int restaurantPort = 8086;

service /restaurants on new http:Listener(restaurantPort) {

    resource function post .(@http:Payload Restaurant payload) returns http:Created|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            check restaurantsCol->insertOne(payload);
            return <http:Created>{body: payload};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Failed to create restaurant: " + e.message()}};
        }
    }

    resource function get [string id]/menu() returns MenuItem[]|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            map<json> filter = {"_id": id};
            stream<Restaurant, error?> restStream = check restaurantsCol->find(filter);
            record {| Restaurant value; |}? result = check restStream.next();
            check restStream.close();

            if result is record {| Restaurant value; |} {
                return result.value.menu;
            }

            return <http:NotFound>{body: {message: "Restaurant not found"}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Database query error: " + e.message()}};
        }
    }

    resource function put [string id]/inventory(string itemId, int stockQuantity, boolean isAvailable) returns http:Ok|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            map<json> filter = {"_id": id, "menu.itemId": itemId};

            mongodb:Update update = {
                set: {
                    "menu.$.stockQuantity": stockQuantity,
                    "menu.$.isAvailable": isAvailable
                }
            };

            mongodb:UpdateResult updateRes = check restaurantsCol->updateOne(filter, update);

            if updateRes.modifiedCount == 0 {
                return <http:NotFound>{body: {message: "Restaurant or menu item not found"}};
            }

            return <http:Ok>{body: {message: "Inventory updated successfully"}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Failed to update inventory: " + e.message()}};
        }
    }

    resource function get [string id]/hours() returns OperatingHoursPayload|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            map<json> filter = {"_id": id};
            stream<Restaurant, error?> restStream = check restaurantsCol->find(filter);
            record {| Restaurant value; |}? result = check restStream.next();
            check restStream.close();

            if result is record {| Restaurant value; |} {
                Restaurant rest = result.value;
                return {
                    openingTime: rest.openingTime,
                    closingTime: rest.closingTime,
                    isOpen: rest.isOpen
                };
            }

            return <http:NotFound>{body: {message: "Restaurant not found"}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Database query error: " + e.message()}};
        }
    }

    resource function put [string id]/hours(@http:Payload OperatingHoursPayload hours) returns http:Ok|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            map<json> filter = {"_id": id};

            mongodb:Update update = {
                set: {
                    "openingTime": hours.openingTime,
                    "closingTime": hours.closingTime,
                    "isOpen": hours.isOpen
                }
            };

            mongodb:UpdateResult updateRes = check restaurantsCol->updateOne(filter, update);

            if updateRes.modifiedCount == 0 {
                return <http:NotFound>{body: {message: "Restaurant not found"}};
            }

            return <http:Ok>{body: {message: "Operating hours updated successfully"}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Failed to update operating hours: " + e.message()}};
        }
    }

    resource function get [string id]/status() returns json|http:NotFound|http:InternalServerError {
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            map<json> filter = {"_id": id};
            stream<Restaurant, error?> restStream = check restaurantsCol->find(filter);
            record {| Restaurant value; |}? result = check restStream.next();
            check restStream.close();

            if result is record {| Restaurant value; |} {
                Restaurant rest = result.value;

                string currentTime = time:utcToString(time:utcNow()).substring(11, 16);
                boolean currentlyOpen = rest.isOpen;

                if rest.openingTime <= rest.closingTime {
                    currentlyOpen = currentlyOpen &&
                        currentTime >= rest.openingTime &&
                        currentTime < rest.closingTime;
                } else {
                    currentlyOpen = currentlyOpen &&
                        (currentTime >= rest.openingTime ||
                        currentTime < rest.closingTime);
                }

                return {
                    restaurantId: id,
                    currentlyOpen: currentlyOpen,
                    openingTime: rest.openingTime,
                    closingTime: rest.closingTime
                };
            }

            return <http:NotFound>{
                body: {message: "Restaurant not found"}
            };
        } on fail var e {
            return <http:InternalServerError>{
                body: {message: "Failed to check restaurant status: " + e.message()}
            };
        }
    }

    resource function post [string id]/orders/[string orderId]/status(@http:Payload OrderStatusUpdate update)
            returns http:Accepted|http:BadRequest|http:NotFound|http:InternalServerError {
        if ALLOWED_STATUSES.indexOf(update.status) is () {
            return <http:BadRequest>{body: {message: "status must be one of PREPARING, READY, REJECTED"}};
        }
        do {
            mongodb:Database db = check getDatabase();
            mongodb:Collection restaurantsCol = check db->getCollection("restaurants");

            map<json> filter = {"_id": id};
            stream<Restaurant, error?> restStream = check restaurantsCol->find(filter);
            record {| Restaurant value; |}? result = check restStream.next();
            check restStream.close();
            if result is () {
                return <http:NotFound>{body: {message: "Restaurant not found"}};
            }

            check publishOrderStatus(id, orderId, update.status, update?.reason);
            return <http:Accepted>{body: {message: "Order status published", orderId: orderId, status: update.status}};
        } on fail var e {
            return <http:InternalServerError>{body: {message: "Failed to publish order status: " + e.message()}};
        }
    }
}
