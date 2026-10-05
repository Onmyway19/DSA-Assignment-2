import ballerina/time;
import ballerinax/mongodb;

type RestaurantCounters record {|
    int totalOrders;
    float totalRevenue;
    int completedOrders;
    int cancelledOrders;
    float preparationMinutes;
    int preparationSamples;
|};

type DriverCounters record {|
    int completedDeliveries;
    int onTimeDeliveries;
    int lateDeliveries;
    float deliveryMinutes;
    int durationSamples;
|};

function readEvents() returns AdminEvent[]|error {
    mongodb:Collection collection = check eventsCollection();
    stream<AdminEvent, error?> result = check collection->find(
        {}, projection = {"_id": 0}, targetType = AdminEvent
    );
    return from AdminEvent event in result select event;
}

function restaurantReport(string restaurantId, string? startAt, string? endAt) returns json|error {
    AdminEvent[] events = check readEvents();
    RestaurantCounters counters = {
        totalOrders: 0,
        totalRevenue: 0.0,
        completedOrders: 0,
        cancelledOrders: 0,
        preparationMinutes: 0.0,
        preparationSamples: 0
    };
    map<string> preparationStart = {};

    foreach AdminEvent event in events {
        map<json> payload = event.payload;
        if event.topic == "orders.created" &&
                isWithinRange(event.occurredAt, startAt, endAt) &&
                payloadString(payload, "restaurantId") == restaurantId {
            counters.totalOrders += 1;
            string amount = payloadString(payload, "totalAmount");
            if amount != "" {
                counters.totalRevenue += check float:fromString(amount);
            }
        } else if event.topic == "orders.status-changed" &&
                payloadString(payload, "restaurantId") == restaurantId {
            string status = payloadString(payload, "newStatus");
            string orderId = event.orderId;
            if status == "PREPARING" {
                preparationStart[orderId] = event.occurredAt;
            } else if status == "DELIVERED" &&
                    isWithinRange(event.occurredAt, startAt, endAt) {
                counters.completedOrders += 1;
            } else if status == "CANCELLED" &&
                    isWithinRange(event.occurredAt, startAt, endAt) {
                counters.cancelledOrders += 1;
            }
        }
    }
    foreach AdminEvent event in events {
        if event.topic != "orders.status-changed" ||
                !isWithinRange(event.occurredAt, startAt, endAt) ||
                payloadString(event.payload, "restaurantId") != restaurantId ||
                payloadString(event.payload, "newStatus") != "READY" ||
                !preparationStart.hasKey(event.orderId) {
            continue;
        }
        float duration = check elapsedMinutes(preparationStart.get(event.orderId), event.occurredAt);
        counters.preparationMinutes += duration;
        counters.preparationSamples += 1;
    }

    float averagePreparationMinutes = 0.0;
    if counters.preparationSamples > 0 {
        averagePreparationMinutes = counters.preparationMinutes / counters.preparationSamples;
    }
    return {
        restaurantId,
        startAt,
        endAt,
        totalOrders: counters.totalOrders,
        totalRevenue: counters.totalRevenue,
        completedOrders: counters.completedOrders,
        cancelledOrders: counters.cancelledOrders,
        averagePreparationMinutes
    };
}

function deliveryReport(string? startAt, string? endAt) returns json|error {
    AdminEvent[] events = check readEvents();
    map<string> assignedAt = {};
    map<string> assignedDriver = {};
    map<int> estimatedMinutes = {};
    map<DriverCounters> driverCounters = {};
    int assignedDeliveries = 0;
    int completedDeliveries = 0;
    int onTimeDeliveries = 0;
    int lateDeliveries = 0;
    int etaClassifiedDeliveries = 0;
    float totalDeliveryMinutes = 0.0;
    int durationSamples = 0;

    foreach AdminEvent event in events {
        if event.topic == "delivery.assigned" {
            map<json> payload = event.payload;
            assignedAt[event.orderId] = event.occurredAt;
            assignedDriver[event.orderId] = payloadString(payload, "driverId");
            string eta = payloadString(payload, "etaMinutes");
            if eta != "" {
                estimatedMinutes[event.orderId] = check int:fromString(eta);
            }
            if isWithinRange(event.occurredAt, startAt, endAt) {
                assignedDeliveries += 1;
            }
        }
    }

    foreach AdminEvent event in events {
        if event.topic == "delivery.completed" &&
                isWithinRange(event.occurredAt, startAt, endAt) {
            map<json> payload = event.payload;
            string driverId = payloadString(payload, "driverId");
            if driverId == "" && assignedDriver.hasKey(event.orderId) {
                driverId = assignedDriver.get(event.orderId);
            }
            if driverId == "" {
                driverId = "UNKNOWN";
            }
            DriverCounters counters = driverCounters.hasKey(driverId) ? driverCounters.get(driverId) : {
                completedDeliveries: 0,
                onTimeDeliveries: 0,
                lateDeliveries: 0,
                deliveryMinutes: 0.0,
                durationSamples: 0
            };
            counters.completedDeliveries += 1;
            completedDeliveries += 1;

            if assignedAt.hasKey(event.orderId) {
                string deliveredAt = payloadString(payload, "deliveredAt");
                if deliveredAt == "" {
                    deliveredAt = event.occurredAt;
                }
                float duration = check elapsedMinutes(assignedAt.get(event.orderId), deliveredAt);
                counters.deliveryMinutes += duration;
                counters.durationSamples += 1;
                totalDeliveryMinutes += duration;
                durationSamples += 1;

                if estimatedMinutes.hasKey(event.orderId) {
                    etaClassifiedDeliveries += 1;
                    if duration <= <float>estimatedMinutes.get(event.orderId) {
                        counters.onTimeDeliveries += 1;
                        onTimeDeliveries += 1;
                    } else {
                        counters.lateDeliveries += 1;
                        lateDeliveries += 1;
                    }
                }
            }
            driverCounters[driverId] = counters;
        }
    }

    float averageDeliveryMinutes = 0.0;
    if durationSamples > 0 {
        averageDeliveryMinutes = totalDeliveryMinutes / durationSamples;
    }
    float onTimeRatePercent = 0.0;
    if etaClassifiedDeliveries > 0 {
        onTimeRatePercent = (onTimeDeliveries * 100.0) / etaClassifiedDeliveries;
    }
    json[] perDriver = [];
    foreach string driverId in driverCounters.keys() {
        DriverCounters counters = driverCounters.get(driverId);
        float averageMinutes = 0.0;
        if counters.durationSamples > 0 {
            averageMinutes = counters.deliveryMinutes / counters.durationSamples;
        }
        perDriver.push({
            driverId,
            completedDeliveries: counters.completedDeliveries,
            onTimeDeliveries: counters.onTimeDeliveries,
            lateDeliveries: counters.lateDeliveries,
            averageDeliveryMinutes: averageMinutes
        });
    }
    return {
        startAt,
        endAt,
        assignedDeliveries,
        completedDeliveries,
        onTimeDeliveries,
        lateDeliveries,
        onTimeRatePercent,
        averageDeliveryMinutes,
        drivers: perDriver
    };
}

function validateRange(string? startAt, string? endAt) returns error? {
    time:Utc? rangeStart = ();
    time:Utc? rangeEnd = ();
    if startAt is string {
        if !startAt.endsWith("Z") {
            return error("startAt must use a UTC timestamp ending in Z");
        }
        rangeStart = check time:utcFromString(startAt);
    }
    if endAt is string {
        if !endAt.endsWith("Z") {
            return error("endAt must use a UTC timestamp ending in Z");
        }
        rangeEnd = check time:utcFromString(endAt);
    }
    if rangeStart is time:Utc && rangeEnd is time:Utc &&
            time:utcDiffSeconds(rangeStart, rangeEnd) > 0d {
        return error("startAt must not be later than endAt");
    }
}
