# Build
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app
COPY pom.xml .
RUN mvn -q -B dependency:go-offline
COPY src ./src
RUN mvn -q -B -DskipTests package

# Run
FROM eclipse-temurin:17-jre
WORKDIR /app
RUN useradd --system --uid 1001 vokas
COPY --from=build /app/target/vokas-backend-*.jar app.jar
USER vokas
# Railway mengisi PORT; batasi memori JVM agar muat di paket kecil
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC"
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
