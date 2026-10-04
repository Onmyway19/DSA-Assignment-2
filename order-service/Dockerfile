
FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/order_service.jar ./order_service.jar
COPY Config.toml ./Config.toml
EXPOSE 8081 8091
ENTRYPOINT ["java", "-jar", "order_service.jar"]
