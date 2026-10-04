
$ErrorActionPreference = "Stop"
$Api = "http://localhost:8081/orders"
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
function Expect($id, $want) {
    $got = (Invoke-RestMethod "$Api/$id").status
    if ($got -eq $want) { Write-Host "PASS: $want" -ForegroundColor Green }
    else { Write-Host "FAIL: expected $want, got $got" -ForegroundColor Red; exit 1 }
}
function NewOrder($cust) {
    $body = @{ customerId=$cust; restaurantId="r1"; deliveryAddress="12 Independence Ave"
               items=@(@{ menuItemId="m1"; name="Burger"; quantity=2; unitPrice=45.0 }) } | ConvertTo-Json -Depth 5
    (Invoke-RestMethod -Method Post $Api -ContentType "application/json" -Body $body).id
}

$id = NewOrder "c1"; Write-Host "Order $id"; Expect $id "CREATED"
Emit "payments.completed" $id "PaymentCompleted" @{ paymentId="p1" };           Expect $id "CONFIRMED"
Emit "restaurant.order.status" $id "RestaurantStatus" @{ status="PREPARING" };  Expect $id "PREPARING"
Emit "restaurant.order.status" $id "RestaurantStatus" @{ status="READY" };      Expect $id "READY"
Emit "delivery.picked-up" $id "DeliveryPickedUp" @{ driverId="d1" };            Expect $id "OUT_FOR_DELIVERY"
Emit "delivery.completed" $id "DeliveryCompleted" @{ driverId="d1" };           Expect $id "DELIVERED"

Write-Host "--- cancelling a delivered order must return 409"
try { Invoke-RestMethod -Method Post "$Api/$id/cancel" -ContentType "application/json" -Body '{"actor":"CUSTOMER"}'; Write-Host "FAIL: no error" -ForegroundColor Red }
catch { if ($_.Exception.Response.StatusCode.value__ -eq 409) { Write-Host "PASS: 409" -ForegroundColor Green } else { Write-Host "FAIL: $($_.Exception.Message)" -ForegroundColor Red } }

Write-Host "--- payment failure cancels the order"
$id2 = NewOrder "c2"
Emit "payments.failed" $id2 "PaymentFailed" @{ reason="INSUFFICIENT_FUNDS" };   Expect $id2 "CANCELLED"
Write-Host "ALL TESTS PASSED" -ForegroundColor Green
