$root = Split-Path -Parent $PSScriptRoot
$failed = @()
foreach ($svc in "order-service","payment-service","delivery-service","notification-service","admin-service","customer_service","restaurant_service") {
    Write-Host "=== building $svc"
    Push-Location (Join-Path $root $svc)
    $log = cmd /c "bal build 2>&1"
    $log | ForEach-Object { Write-Host $_ }
    if ((($log -join "`n") -match "compilation contains errors") -or ($LASTEXITCODE -ne 0)) { $failed += $svc }
    Pop-Location
}
if ($failed.Count -gt 0) {
    Write-Host "FAILED: $($failed -join ', ')" -ForegroundColor Red
    exit 1
}
Write-Host "All services built. Now run: docker compose up --build" -ForegroundColor Green