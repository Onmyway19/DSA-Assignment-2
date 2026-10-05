import ballerina/http;

type BadReportRange record {| *http:BadRequest; record {|string message;|} body; |};
type ReportFailure record {| *http:InternalServerError; record {|string message;|} body; |};

service /admin on new http:Listener(8085) {
    resource function get reports/restaurants/[string restaurantId](string? startAt, string? endAt)
            returns json|BadReportRange|ReportFailure {
        error? rangeError = validateRange(startAt, endAt);
        if rangeError is error {
            return <BadReportRange>{body: {message: rangeError.message()}};
        }
        json|error report = restaurantReport(restaurantId, startAt, endAt);
        if report is error {
            return <ReportFailure>{body: {message: report.message()}};
        }
        return report;
    }

    resource function get reports/delivery\-performance(string? startAt, string? endAt)
            returns json|BadReportRange|ReportFailure {
        error? rangeError = validateRange(startAt, endAt);
        if rangeError is error {
            return <BadReportRange>{body: {message: rangeError.message()}};
        }
        json|error report = deliveryReport(startAt, endAt);
        if report is error {
            return <ReportFailure>{body: {message: report.message()}};
        }
        return report;
    }
}

service /health on new http:Listener(8095) {
    resource function get .() returns string => "UP";
}
