# Payment Service & Delivery Service

## Payment Service (port 8082, db `payments_db`)
- Consumes `orders.created` (group `payment-service`) -> saves a Payment -> emits `payments.completed` or `payments.failed` (key = orderId).
- Consumes `orders.cancelled` -> marks a COMPLETED payment `REFUNDED`.
- Simulated gateway: approved if `0 < totalAmount <= maxPaymentAmount` (Config.toml, default 1000), else `INSUFFICIENT_FUNDS`.
- REST: `GET /payments/{orderId}`, `GET /payments?status=`.

## Delivery Service (port 8083, db `delivery_db`)
- Consumes `orders.status-changed`; when `newStatus == READY` assigns the least-busy driver from `drivers` (Config.toml) and emits `delivery.assigned`.
- Driver actions via REST emit `delivery.picked-up` / `delivery.completed`, which the Order Service turns into OUT_FOR_DELIVERY / DELIVERED.
- Consumes `orders.cancelled` -> cancels an unstarted delivery.
- REST: `GET /deliveries/{orderId}`, `GET /deliveries?driverId=&status=`, `POST /deliveries/{orderId}/pickup`, `POST /deliveries/{orderId}/complete`.

## Defence notes
- **Idempotency:** one payment and one delivery per orderId. Payment re-publishes its stored outcome on a duplicate `orders.created` (never charges twice; heals a crash between save and publish). Delivery ignores duplicate READY events. Pickup/complete are idempotent.
- **Delivery order guarantee:** key = orderId, so assigned -> picked-up -> completed stay ordered.
- **Own database each:** no shared schema with Order Service.
- **Limitations (say them first):** no transactional outbox; refund only changes DB state (no refund topic in the contract); simulated gateway; driver auth not implemented; assignment race between two READY events at once could pick the same driver (fine for demo).
