# Food Delivery Microservices

This repository contains a Ballerina-based food delivery platform using Kafka
for asynchronous service events and MongoDB for service-owned data.

## Notification and admin services

Build each Ballerina service before starting its container:

```sh
cd notification-service && bal build
cd ../admin-service && bal build
cd ..
docker compose up --build
```

The notification consumer subscribes to order, payment, delivery, and
`notifications.requests` topics. It fans each eligible event out over EMAIL,
SMS, and PUSH, and stores an idempotent delivery record in its own MongoDB.
Set `EMAIL_WEBHOOK`, `SMS_WEBHOOK`, and/or `PUSH_WEBHOOK` before `docker compose
up` to forward deliveries to channel adapters. A webhook receives a JSON object
with `deliveryId`, `eventId`, `orderId`, `recipientType`, `recipientId`,
`channel`, and `message`; it must return a 2xx response for successful
delivery. Adapters can use `deliveryId` as an idempotency key. With no
webhook configured, messages are logged and stored as `SIMULATED` (no external
message is sent).

The admin consumer stores the order and delivery events it needs in a separate
MongoDB. Reports are available at:

- `GET http://localhost:8085/admin/reports/restaurants/{restaurantId}`
- `GET http://localhost:8085/admin/reports/delivery-performance`

Both endpoints accept optional `startAt` and `endAt` query parameters as UTC
ISO-8601 timestamps, for example
`?startAt=2026-10-01T00:00:00Z&endAt=2026-10-31T23:59:59Z`.
Provide timestamps in UTC with a trailing `Z`.
Restaurant reports include order counts, revenue, completion/cancellation
counts, and average preparation time. Delivery reports include assigned and
completed counts, average delivery duration, ETA-based on-time rate, and
per-driver performance; the on-time rate only considers deliveries with an
ETA in their assignment event.

Health checks: `http://localhost:8092/health` (notifications) and
`http://localhost:8095/health` (admin).