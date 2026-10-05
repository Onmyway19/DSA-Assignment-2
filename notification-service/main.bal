import ballerina/http;

service /health on new http:Listener(8092) {
    resource function get .() returns string => "UP";
}
