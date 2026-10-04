
set -e
API=http://localhost:8081/orders
KAFKA="docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh --bootstrap-server kafka:9092 --property parse.key=true --property key.separator=|"

emit() { 
  echo "$2|{\"eventId\":\"$(uuidgen)\",\"eventType\":\"$3\",\"occurredAt\":\"2026-10-03T10:00:00Z\",\"orderId\":\"$2\",\"sourceService\":\"test\",\"schemaVersion\":1,\"payload\":$4}" \
   | $KAFKA --topic "$1" >/dev/null
  sleep 2
}
status() { curl -s $API/$1 | jq -r .status; }
expect() { [ "$(status $1)" == "$2" ] && echo "PASS: $2" || { echo "FAIL: expected $2, got $(status $1)"; exit 1; }; }

ID=$(curl -s -X POST $API -H 'Content-Type: application/json' -d '{
 "customerId":"c1","restaurantId":"r1","deliveryAddress":"12 Independence Ave",
 "items":[{"menuItemId":"m1","name":"Burger","quantity":2,"unitPrice":45.0}]}' | jq -r .id)
echo "Order $ID"; expect $ID CREATED

emit payments.completed $ID PaymentCompleted '{"paymentId":"p1"}';              expect $ID CONFIRMED
emit restaurant.order.status $ID S '{"status":"PREPARING"}';                    expect $ID PREPARING
emit restaurant.order.status $ID S '{"status":"READY"}';                        expect $ID READY
emit delivery.picked-up $ID DeliveryPickedUp '{"driverId":"d1"}';               expect $ID OUT_FOR_DELIVERY
emit delivery.completed $ID DeliveryCompleted '{"driverId":"d1"}';              expect $ID DELIVERED

echo "--- illegal transition must return 409"
CODE=$(curl -s -o /dev/null -w '%{http_code}' -X POST $API/$ID/cancel -H 'Content-Type: application/json' -d '{"actor":"CUSTOMER"}')
[ "$CODE" == "409" ] && echo "PASS: 409" || echo "FAIL: got $CODE"

echo "--- payment failure cancels order"
ID2=$(curl -s -X POST $API -H 'Content-Type: application/json' -d '{"customerId":"c2","restaurantId":"r1","deliveryAddress":"x","items":[{"menuItemId":"m1","name":"Pizza","quantity":1,"unitPrice":60.0}]}' | jq -r .id)
emit payments.failed $ID2 PaymentFailed '{"reason":"INSUFFICIENT_FUNDS"}';      expect $ID2 CANCELLED
echo "ALL TESTS PASSED"
