import ballerina/http;

type PaymentNotFound record {| *http:NotFound; record {|string message;|} body; |};

service /payments on new http:Listener(8082) {

    // GET /payments/{orderId}
    resource function get [string orderId]() returns Payment|PaymentNotFound|error {
        Payment? p = check findPaymentByOrder(orderId);
        if p is () {
            return <PaymentNotFound>{body: {message: "No payment for this order"}};
        }
        return p;
    }

    // GET /payments?status=COMPLETED|FAILED|REFUNDED
    resource function get .(string? status) returns Payment[]|error {
        return findPayments(status);
    }
}

service /health on new http:Listener(8092) {
    resource function get .() returns string => "UP";
}
