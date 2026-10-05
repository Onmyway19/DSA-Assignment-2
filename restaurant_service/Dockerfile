FROM eclipse-temurin:21-jre
WORKDIR /app
COPY target/bin/restaurant_service.jar ./restaurant_service.jar
EXPOSE 8086
ENTRYPOINT ["java", "-jar", "restaurant_service.jar"]