# Food Delivery Microservices

An event-driven food delivery system built with Ballerina, Apache Kafka, MongoDB, and Nginx.

## Services & Ports

| Service | Port | Health Port |
|---|---|---|
| **UI (Nginx)** | `80` | — |
| **order-service** | `8081` | `8091` |
| **payment-service** | `8082` | `8096` |
| **delivery-service** | `8083` | `8093` |
| **customer_service** | `8084` | — |
| **admin-service** | `8085` | `8095` |
| **restaurant_service** | `8086` | — |
| **notification-service** | — | `8092` |
| **Kafka** | `9092` | — |

*MongoDB Ports:* Order (`27017`), Payment (`27018`), Delivery (`27019`).

---

## Quick Start

### Prerequisites
* Docker Desktop (running)
* Ballerina `2201.13.5`

### 1. Build & Run
**Windows (PowerShell):**
```powershell
powershell -ExecutionPolicy Bypass -File scripts\build-all.ps1
docker compose up --build -d
docker compose ps