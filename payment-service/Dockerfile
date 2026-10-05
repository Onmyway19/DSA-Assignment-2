FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/payment_service.jar ./payment_service.jar
COPY Config.toml ./Config.toml
EXPOSE 8082 8092
ENTRYPOINT ["java", "-jar", "payment_service.jar"]
