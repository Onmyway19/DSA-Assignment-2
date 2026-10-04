# Kafka Topic & Event Contract (owned by Tech Lead)

All services MUST follow this contract. Changes go through a PR reviewed by the Tech Lead.

## 1. Conventions
- Topic names: `domain.entity.event` in lowercase, dot-separated.
- **Message key = `orderId`** on every order-related topic, so all events of one order go to the same partition and are consumed in order.
- Value = JSON `EventEnvelope` (below). Producers use `acks=all` and idempotence enabled.
- Consumers use manual commit, are **idempotent** (duplicates are ignored), and use their own `groupId` (the service name).
- Poison messages go to `orders.dlq`.

## 2. Event envelope
```json
{
  "eventId": "uuid",
  "eventType": "OrderCreated",
  "occurredAt": "2026-10-03T10:15:30Z",
  "orderId": "uuid",
  "sourceService": "order-service",
  "schemaVersion": 1,
  "payload": { }
}
```

## 3. Topics

| Topic | Partitions | Producer | Consumers (group) | Retention |
|---|---|---|---|---|
| `orders.created` | 6 | Order | Payment, Restaurant, Notification, Admin | 7d |
| `orders.status-changed` | 6 | Order | Notification, Delivery, Admin, Customer (history) | 7d |
| `orders.cancelled` | 3 | Order | Payment (refund), Restaurant (inventory release), Delivery | 7d |
| `payments.completed` | 6 | Payment | **Order**, Notification | 7d |
| `payments.failed` | 3 | Payment | **Order**, Notification | 7d |
| `restaurant.order.status` | 6 | Restaurant | **Order** | 7d |
| `delivery.assigned` | 3 | Delivery | Notification, Admin | 7d |
| `delivery.picked-up` | 3 | Delivery | **Order**, Notification | 7d |
| `delivery.completed` | 3 | Delivery | **Order**, Notification, Admin | 7d |
| `notifications.requests` | 6 | any | Notification | 1d |
| `orders.dlq` | 1 | any | ops | 30d |

Partition rationale: 6 partitions on high-volume topics allows up to 6 parallel consumer instances during peak meal times; keying by `orderId` guarantees per-order ordering regardless of partition count. Replication factor is 1 in dev (single broker); use 3 in production.

## 4. Payloads

**orders.created** (`OrderCreated`)
```json
{ "id": "uuid", "customerId": "c1", "restaurantId": "r1",
  "items": [{"menuItemId": "m1", "name": "Burger", "quantity": 2, "unitPrice": 45.0}],
  "deliveryAddress": "12 Independence Ave", "totalAmount": 90.0, "status": "CREATED",
  "createdAt": "..." }
```

**orders.status-changed / orders.cancelled**
```json
{ "orderId": "uuid", "customerId": "c1", "restaurantId": "r1",
  "newStatus": "CONFIRMED", "changedBy": "PAYMENT", "reason": null, "totalAmount": 90.0 }
```

**payments.completed** `{ "paymentId": "uuid", "amount": 90.0, "method": "CARD" }`
**payments.failed** `{ "paymentId": "uuid", "reason": "INSUFFICIENT_FUNDS" }`
**restaurant.order.status** `{ "status": "PREPARING" | "READY" | "REJECTED" }`
**delivery.assigned** `{ "driverId": "d1", "etaMinutes": 25 }`
**delivery.picked-up** `{ "driverId": "d1" }`
**delivery.completed** `{ "driverId": "d1", "deliveredAt": "..." }`
**notifications.requests** `{ "recipientType": "CUSTOMER|RESTAURANT|DRIVER", "recipientId": "x", "channel": "EMAIL|SMS|PUSH", "message": "..." }`

## 5. Order state machine
```
CREATED -> CONFIRMED -> PREPARING -> READY -> OUT_FOR_DELIVERY -> DELIVERED
   |           |            |
   +-----------+------------+--> CANCELLED   (not allowed once READY)
```

| Transition | Trigger | Actor |
|---|---|---|
| CREATED → CONFIRMED | `payments.completed` | PAYMENT |
| CREATED → CANCELLED | `payments.failed` / customer cancel | PAYMENT / CUSTOMER |
| CONFIRMED → PREPARING | `restaurant.order.status=PREPARING` | RESTAURANT |
| PREPARING → READY | `restaurant.order.status=READY` | RESTAURANT |
| any pre-READY → CANCELLED | `restaurant.order.status=REJECTED` or cancel API | RESTAURANT / CUSTOMER |
| READY → OUT_FOR_DELIVERY | `delivery.picked-up` | DELIVERY |
| OUT_FOR_DELIVERY → DELIVERED | `delivery.completed` | DELIVERY |

## 6. End-to-end flow
1. Customer `POST /orders` → Order saves (CREATED) → publishes `orders.created`.
2. Payment consumes it → emits `payments.completed` → Order moves to CONFIRMED.
3. Restaurant consumes `orders.status-changed` (CONFIRMED) → emits PREPARING, then READY.
4. Delivery assigns a driver on READY → `delivery.assigned`, then `delivery.picked-up` → OUT_FOR_DELIVERY.
5. `delivery.completed` → DELIVERED. Notification Service reacts to every status change.

## 7. Order Service REST API (port 8081)
| Method | Path | Description |
|---|---|---|
| POST | `/orders` | Create order |
| GET | `/orders/{id}` | Fetch order with status history |
| GET | `/orders?customerId=&restaurantId=&status=` | List/filter |
| PATCH | `/orders/{id}/status` | Manual transition `{status, actor, reason}` |
| POST | `/orders/{id}/cancel` | Cancel `{actor, reason}` |

Design notes: optimistic locking via `version` field (handles concurrent updates), idempotent transitions (duplicate events are no-ops), illegal transitions return 409.

## 8. Tech Lead checklist (PR reviews)
- Uses the envelope and the correct topic name; key = orderId
- Consumer is idempotent, commits manually
- No shared database between services
- Dockerfile + service added to docker-compose, env via Config.toml
- Every member has commits in the repo (marks are 0 otherwise)
