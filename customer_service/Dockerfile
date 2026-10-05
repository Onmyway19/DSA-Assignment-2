FROM ballerina/ballerina:2201.13.5 AS builder
WORKDIR /home/ballerina
COPY --chown=ballerina:ballerina . .
RUN bal build

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /home/ballerina/target/bin/customer_service.jar .
COPY Config.toml .

CMD ["java", "-jar", "customer_service.jar"]