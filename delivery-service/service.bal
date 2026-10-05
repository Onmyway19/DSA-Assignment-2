import ballerina/http;

type DeliveryNotFound record {| *http:NotFound; record {|string message;|} body; |};
type DeliveryConflict record {| *http:Conflict; record {|string message;|} body; |};

service /deliveries on new http:Listener(8083) {

    // GET /deliveries/{orderId}
    resource function get [string orderId]() returns Delivery|DeliveryNotFound|error {
        Delivery? d = check findDelivery(orderId);
        if d is () {
            return <DeliveryNotFound>{body: {message: "No delivery for this order"}};
        }
        return d;
    }

    // GET /deliveries?driverId=d1&status=ASSIGNED
    resource function get .(string? driverId, string? status) returns Delivery[]|error {
        return findDeliveries(driverId, status);
    }

    // POST /deliveries/{orderId}/pickup   (driver collected the food)
    resource function post [string orderId]/pickup()
            returns Delivery|DeliveryNotFound|DeliveryConflict|error {
        Delivery? found = check findDelivery(orderId);
        if found is () {
            return <DeliveryNotFound>{body: {message: "No delivery for this order"}};
        }
        Delivery d = found;
        if d.status == PICKED_UP || d.status == DELIVERED {
            return d;                                   // idempotent
        }
        if d.status != ASSIGNED {
            return <DeliveryConflict>{body: {message: "Cannot pick up a delivery in state " + d.status}};
        }
        string ts = nowIso();
        check updateDelivery(orderId, {status: "PICKED_UP", pickedUpAt: ts, updatedAt: ts});
        check publish(TOPIC_DELIVERY_PICKED_UP, "DeliveryPickedUp", orderId, {driverId: d.driverId});
        d.status = PICKED_UP;
        d.pickedUpAt = ts;
        d.updatedAt = ts;
        return d;
    }

    // POST /deliveries/{orderId}/complete   (customer received the food)
    resource function post [string orderId]/complete()
            returns Delivery|DeliveryNotFound|DeliveryConflict|error {
        Delivery? found = check findDelivery(orderId);
        if found is () {
            return <DeliveryNotFound>{body: {message: "No delivery for this order"}};
        }
        Delivery d = found;
        if d.status == DELIVERED {
            return d;                                   // idempotent
        }
        if d.status != PICKED_UP {
            return <DeliveryConflict>{body: {message: "Cannot complete a delivery in state " + d.status}};
        }
        string ts = nowIso();
        check updateDelivery(orderId, {status: "DELIVERED", deliveredAt: ts, updatedAt: ts});
        check publish(TOPIC_DELIVERY_COMPLETED, "DeliveryCompleted", orderId,
            {driverId: d.driverId, deliveredAt: ts});
        d.status = DELIVERED;
        d.deliveredAt = ts;
        d.updatedAt = ts;
        return d;
    }
}

service /health on new http:Listener(8093) {
    resource function get .() returns string => "UP";
}
