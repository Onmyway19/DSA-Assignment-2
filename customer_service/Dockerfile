FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/customer_service.jar ./customer_service.jar
EXPOSE 8084
ENTRYPOINT ["java", "-jar", "customer_service.jar"]