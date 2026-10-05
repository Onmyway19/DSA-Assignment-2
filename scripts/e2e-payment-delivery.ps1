# End-to-end test of Order + Payment + Delivery. Only the Restaurant Service is faked
# (we emit its Kafka events by hand); payment and delivery are the REAL services.
$ErrorActionPreference = "Stop"
$Orders = "http://localhost:8081/orders"
$Pay    = "http://localhost:8082/payments"
$Del    = "http://localhost:8083/deliveries"
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Emit($topic, $orderId, $eventType, $payload) {
    $env = @{
        eventId = [guid]::NewGuid().ToString(); eventType = $eventType
        occurredAt = (Get-Date).ToUniversalTime().ToString("o"); orderId = $orderId
        sourceService = "test"; schemaVersion = 1; payload = $payload
    } | ConvertTo-Json -Compress -Depth 5
    "$orderId|$env" | docker compose exec -T kafka /opt/kafka/bin/kafka-console-producer.sh `
        --bootstrap-server kafka:9092 --topic $topic --property parse.key=true --property "key.separator=|" | Out-Null
    Start-Sleep -Seconds 3
}
function Check($name, $got, $want) {
    if ($got -eq $want) { Write-Host "PASS: $name = $want" -ForegroundColor Green }
    else { Write-Host "FAIL: $name expected $want, got $got" -ForegroundColor Red; exit 1 }
}
function NewOrder($cust, $price) {
    $body = @{ customerId=$cust; restaurantId="r1"; deliveryAddress="12 Independence Ave"
               items=@(@{ menuItemId="m1"; name="Burger"; quantity=2; unitPrice=$price }) } | ConvertTo-Json -Depth 5
    (Invoke-RestMethod -Method Post $Orders -ContentType "application/json" -Body $body).id
}
function Wait() { Start-Sleep -Seconds 4 }

Write-Host "=== HAPPY PATH ===" -ForegroundColor Cyan
$id = NewOrder "c1" 45.0; Write-Host "Order $id"; Wait
Check "payment.status" (Invoke-RestMethod "$Pay/$id").status "COMPLETED"
Check "order.status"   (Invoke-RestMethod "$Orders/$id").status "CONFIRMED"

Emit "restaurant.order.status" $id "RestaurantStatus" @{ status="PREPARING" }
Emit "restaurant.order.status" $id "RestaurantStatus" @{ status="READY" }
Check "order.status"    (Invoke-RestMethod "$Orders/$id").status "READY"
Check "delivery.status" (Invoke-RestMethod "$Del/$id").status "ASSIGNED"

Invoke-RestMethod -Method Post "$Del/$id/pickup" | Out-Null; Wait
Check "order.status" (Invoke-RestMethod "$Orders/$id").status "OUT_FOR_DELIVERY"
Invoke-RestMethod -Method Post "$Del/$id/complete" | Out-Null; Wait
Check "order.status" (Invoke-RestMethod "$Orders/$id").status "DELIVERED"

Write-Host "=== PAYMENT FAILURE (amount > maxPaymentAmount) ===" -ForegroundColor Cyan
$id2 = NewOrder "c2" 900.0; Wait
Check "payment.status" (Invoke-RestMethod "$Pay/$id2").status "FAILED"
Check "order.status"   (Invoke-RestMethod "$Orders/$id2").status "CANCELLED"

Write-Host "=== REFUND (cancel after paying) ===" -ForegroundColor Cyan
$id3 = NewOrder "c3" 45.0; Wait
Invoke-RestMethod -Method Post "$Orders/$id3/cancel" -ContentType "application/json" -Body '{"actor":"CUSTOMER"}' | Out-Null; Wait
Check "payment.status" (Invoke-RestMethod "$Pay/$id3").status "REFUNDED"

Write-Host "=== DELIVERY GUARDS ===" -ForegroundColor Cyan
try { Invoke-RestMethod -Method Post "$Del/$id/pickup" | Out-Null; Write-Host "PASS: pickup is idempotent" -ForegroundColor Green }
catch { Write-Host "FAIL: repeat pickup errored" -ForegroundColor Red }
try { Invoke-RestMethod "$Del/does-not-exist" | Out-Null; Write-Host "FAIL: expected 404" -ForegroundColor Red }
catch { Check "unknown delivery http" $_.Exception.Response.StatusCode.value__ 404 }

Write-Host "ALL TESTS PASSED" -ForegroundColor Green
