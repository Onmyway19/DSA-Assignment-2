import ballerina/http;
import ballerina/log;
import ballerina/uuid;

type OrderNotFound record {| *http:NotFound; record {|string message;|} body; |};
type Conflict record {| *http:Conflict; record {|string message;|} body; |};
type BadRequest record {| *http:BadRequest; record {|string message;|} body; |};


public function applyTransition(string orderId, OrderStatus target, string actor, string? reason)
        returns Order|error {
    foreach int attempt in 1 ... 3 {            
        Order? existing = check findOrder(orderId);
        if existing is () {
            return error("NOT_FOUND");
        }
        Order o = existing;
        if o.status == target {
            return o;                            
        }
        if !canTransition(o.status, target) {
            return error("ILLEGAL_TRANSITION: " + o.status + " -> " + target);
        }
        int expected = o.version;
        o.status = target;
        o.version = expected + 1;
        o.updatedAt = nowIso();
        o.history.push({status: target, changedAt: o.updatedAt, changedBy: actor, reason});
        if check saveTransition(o, expected) {
            json payload = {
                orderId: o.id, customerId: o.customerId, restaurantId: o.restaurantId,
                newStatus: target, changedBy: actor, reason, totalAmount: o.totalAmount
            };
            check publish(TOPIC_ORDERS_STATUS, "OrderStatusChanged", o.id, payload);
            if target == CANCELLED {
                check publish(TOPIC_ORDERS_CANCELLED, "OrderCancelled", o.id, payload);
            }
            return o;
        }
        log:printWarn("Version conflict, retrying", orderId = orderId, attempt = attempt);
    }
    return error("CONFLICT: concurrent modification");
}

function toHttpError(error e) returns OrderNotFound|Conflict|error {
    string m = e.message();
    if m == "NOT_FOUND" {
        return <OrderNotFound>{body: {message: "Order not found"}};
    }
    if m.startsWith("ILLEGAL_TRANSITION") || m.startsWith("CONFLICT") {
        return <Conflict>{body: {message: m}};
    }
    return e;
}

service /orders on new http:Listener(8081) {

    resource function post .(NewOrder req) returns http:Created|BadRequest|error {
        if req.items.length() == 0 {
            return <BadRequest>{body: {message: "Order must contain at least one item"}};
        }
        float total = 0.0;
        foreach OrderItem i in req.items {
            if i.quantity <= 0 || i.unitPrice < 0.0 {
                return <BadRequest>{body: {message: "Invalid item quantity or price"}};
            }
            total += i.quantity * i.unitPrice;
        }
        string ts = nowIso();
        Order o = {
            id: uuid:createType4AsString(),
            customerId: req.customerId, restaurantId: req.restaurantId,
            items: req.items, deliveryAddress: req.deliveryAddress,
            totalAmount: total, status: CREATED,
            history: [{status: CREATED, changedAt: ts, changedBy: "CUSTOMER"}],
            version: 1, createdAt: ts, updatedAt: ts
        };
        check insertOrder(o);
        check publish(TOPIC_ORDERS_CREATED, "OrderCreated", o.id, o.toJson());
        return <http:Created>{headers: {"Location": "/orders/" + o.id}, body: o};
    }

    resource function get [string id]() returns Order|OrderNotFound|error {
        Order? o = check findOrder(id);
        if o is () {
            return <OrderNotFound>{body: {message: "Order not found"}};
        }
        return o;
    }

    resource function get .(string? customerId, string? restaurantId, string? status)
            returns Order[]|error {
        return findOrders(customerId, restaurantId, status);
    }

    resource function patch [string id]/status(StatusUpdate req)
            returns Order|OrderNotFound|Conflict|BadRequest|error {
        if !actorAllowed(req.actor, req.status) {
            return <BadRequest>{body: {message: req.actor + " may not set " + req.status}};
        }
        Order|error r = applyTransition(id, req.status, req.actor, req.reason);
        if r is error {
            return toHttpError(r);
        }
        return r;
    }

    resource function post [string id]/cancel(CancelRequest req)
            returns Order|OrderNotFound|Conflict|error {
        Order|error r = applyTransition(id, CANCELLED, req.actor, req.reason);
        if r is error {
            return toHttpError(r);
        }
        return r;
    }
}

service /health on new http:Listener(8091) {
    resource function get .() returns string => "UP";
}
