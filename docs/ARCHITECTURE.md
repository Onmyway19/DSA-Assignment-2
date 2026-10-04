# Architecture (Order Service & Kafka)

## 1. System overview
```mermaid
flowchart LR
  C[Customer / Client] -->|REST| ORD[Order Service :8081]
  ORD <--> OM[(MongoDB orders_db)]
  ORD -- orders.created / orders.status-changed / orders.cancelled --> K{{Kafka}}
  K -- orders.created --> PAY[Payment Service]
  K -- orders.status-changed --> NOT[Notification Service]
  K -- orders.status-changed --> DEL[Delivery Service]
  K -- orders.status-changed --> ADM[Admin Service]
  PAY -- payments.completed / payments.failed --> K
  REST[Restaurant Service] -- restaurant.order.status --> K
  DEL -- delivery.picked-up / delivery.completed --> K
  K -- payments.*, restaurant.order.status, delivery.* --> ORD
```

## 2. Order state machine
```mermaid
stateDiagram-v2
  [*] --> CREATED
  CREATED --> CONFIRMED: payments.completed
  CREATED --> CANCELLED: payments.failed / customer cancel
  CONFIRMED --> PREPARING: restaurant PREPARING
  CONFIRMED --> CANCELLED
  PREPARING --> READY: restaurant READY
  PREPARING --> CANCELLED
  READY --> OUT_FOR_DELIVERY: delivery.picked-up
  OUT_FOR_DELIVERY --> DELIVERED: delivery.completed
  DELIVERED --> [*]
  CANCELLED --> [*]
```
Cancellation is not allowed once the order is READY (food already prepared).

## 3. Happy-path sequence
```mermaid
sequenceDiagram
  participant Cu as Customer
  participant O as Order Service
  participant K as Kafka
  participant P as Payment
  participant R as Restaurant
  participant D as Delivery
  Cu->>O: POST /orders
  O->>K: orders.created
  K->>P: orders.created
  P->>K: payments.completed
  K->>O: payments.completed
  O->>O: CREATED -> CONFIRMED
  O->>K: orders.status-changed
  K->>R: CONFIRMED
  R->>K: restaurant.order.status PREPARING, then READY
  K->>O: update status
  D->>K: delivery.picked-up
  K->>O: OUT_FOR_DELIVERY
  D->>K: delivery.completed
  K->>O: DELIVERED
```

## 4. How Order Service stays correct
```mermaid
flowchart TD
  A[REST request or Kafka event] --> B[applyTransition]
  B --> C{Order exists?}
  C -- no --> X1[404]
  C -- yes --> D{Already in target state?}
  D -- yes --> X2[return as-is: idempotent]
  D -- no --> E{Transition allowed?}
  E -- no --> X3[409 Conflict]
  E -- yes --> F[Update Mongo WHERE id AND version = N]
  F --> G{Updated 1 doc?}
  G -- no --> B
  G -- yes --> H[Publish orders.status-changed key=orderId]
```
