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
# Render/Railway mengisi PORT. Paket gratis cuma 0.1 CPU dan 512 MB, jadi:
# - TieredStopAtLevel=1: JIT ringan, start jauh lebih cepat di CPU kecil
# - SerialGC + MaxRAMPercentage: hemat memori
# - Xss512k + CICompilerCount: kurangi beban thread
ENV JAVA_OPTS="-XX:MaxRAMPercentage=75 -XX:+UseSerialGC -XX:TieredStopAtLevel=1 -XX:CICompilerCount=1 -Xss512k -Dspring.jmx.enabled=false"
EXPOSE 8080
ENTRYPOINT ["sh", "-c", "java $JAVA_OPTS -jar app.jar"]
