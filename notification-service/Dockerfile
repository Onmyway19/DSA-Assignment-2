FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/notification_service.jar ./notification_service.jar
COPY Config.toml ./Config.toml
EXPOSE 8092
ENTRYPOINT ["java", "-jar", "notification_service.jar"]
