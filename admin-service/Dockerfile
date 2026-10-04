FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/admin_service.jar ./admin_service.jar
COPY Config.toml ./Config.toml
EXPOSE 8085 8095
ENTRYPOINT ["java", "-jar", "admin_service.jar"]
