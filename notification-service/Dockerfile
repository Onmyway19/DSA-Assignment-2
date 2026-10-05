FROM ballerina/ballerina:2201.13.5 AS builder
WORKDIR /home/ballerina
COPY --chown=ballerina:ballerina . .
RUN bal build

FROM eclipse-temurin:21-jre
WORKDIR /app
COPY --from=builder /home/ballerina/target/bin/notification_service.jar .

CMD ["java", "-jar", "notification_service.jar", "--bal.config.hasunbound=false"]