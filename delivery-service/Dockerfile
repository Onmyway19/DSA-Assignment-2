FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/delivery_service.jar ./delivery_service.jar
COPY Config.toml ./Config.toml
EXPOSE 8083 8093
ENTRYPOINT ["java", "-jar", "delivery_service.jar"]
