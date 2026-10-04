# Defence preparation — Role 1 (Tech Lead + Order Service)

## 60-second pitch
"The Order Service owns the order lifecycle. It exposes a REST API, stores orders in its own MongoDB database, and drives a seven-state machine. Other services never touch the order database — they communicate through Kafka events. I designed the topic names, partitions and event envelope that all seven services follow, and reviewed/merged the team's pull requests."

## Likely questions and answers

**Why Kafka instead of direct REST calls between services?**
Asynchronous and decoupled: if Payment is down, orders still get created and events wait in Kafka. Events are replayable and scale with consumer groups during peak meal times.

**Why is the message key the orderId?**
Kafka guarantees ordering only within a partition. Same key → same partition, so events for one order are always processed in order (e.g. PREPARING never overtakes CONFIRMED), while different orders spread across partitions for parallelism.

**Why 6 partitions on some topics and 3 on others?**
Partitions cap consumer parallelism. High-volume topics (created, status-changed, payments.completed, restaurant status) get 6 so up to 6 instances can share the load at peak. Low-volume ones (cancelled, delivery.*) get 3. Replication factor is 1 only because dev has one broker; production would use 3.

**What if the same event is delivered twice?**
Kafka gives at-least-once delivery. `applyTransition` is idempotent: if the order is already in the target state it returns without change and without publishing again.

**What if two events update the same order at once?**
Optimistic locking: each order has a `version`. The update filter is `id AND version = N`; if another writer got there first, modified count is 0 and we re-read and retry (up to 3 times).

**What about illegal or out-of-order events (e.g. DELIVERED while CREATED)?**
The state machine rejects them (409 over REST; logged and skipped for Kafka so one bad message can't block the partition).

**Why manual offset commit?**
`autoCommit=false` and we commit after processing the batch, so a crash mid-batch re-delivers rather than loses messages. Duplicates are safe because of idempotency.

**Why does each service have its own database?**
Service autonomy and clear boundaries; no shared schema coupling. Order data is only reachable through the Order API or events.

**How do you handle failure of Kafka publishing?**
Producer uses `acks=all`, retries and idempotence. See limitations below for what is not covered.

## Honest limitations (say these before they ask — it scores well)
1. **No transactional outbox.** The Mongo write and the Kafka publish are two steps; a crash between them could lose an event. Fix: outbox collection + relay publisher, or Debezium CDC.
2. **Dead-letter topic is created (`orders.dlq`) but not yet used** by the consumer; failed events are only logged.
3. **Money stored as `float`** for driver compatibility; production should use integer cents or decimal.
4. **No authentication.** The `actor` field in the API is trusted; production would take the actor from a JWT.
5. **Single broker, replication factor 1** (dev only).

## Demo script (3 minutes)
1. `docker compose up` → show containers in Docker Desktop.
2. Show `kafka/TOPICS.md` and the topic list.
3. Postman: create order → show CREATED.
4. Run `scripts/smoke-test.ps1` → watch it move through every state.
5. Show an illegal transition returning 409.
6. Show `GET /orders/{id}` with the full status history.
7. Show architecture diagrams in `docs/ARCHITECTURE.md`.

## Be ready to show in code
- `state_machine.bal` (transition table), `applyTransition()` in `service.bal`, `saveTransition()` in `repository.bal` (version check), `consumers.bal` (event → transition mapping).
