import ballerina/test;

@test:Config {}
function formatsStatusAlerts() {
    NotificationEvent event = {
        eventId: "event-1",
        eventType: "OrderStatusChanged",
        occurredAt: "2026-10-01T10:00:00Z",
        orderId: "order-1",
        sourceService: "order-service",
        payload: {newStatus: "PREPARING"}
    };
    test:assertEquals(notificationMessage(event, event.payload), "Order order-1: PREPARING.");
}

@test:Config {}
function formatsEventAlertsWithoutStatus() {
    NotificationEvent event = {
        eventId: "event-2",
        eventType: "PaymentFailed",
        occurredAt: "2026-10-01T10:00:00Z",
        orderId: "order-2",
        sourceService: "payment-service",
        payload: {}
    };
    test:assertEquals(notificationMessage(event, event.payload), "Order order-2: PaymentFailed.");
}
