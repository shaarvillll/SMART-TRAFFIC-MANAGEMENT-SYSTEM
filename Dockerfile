# ==========================================
# Stage 1: Maven Builder
# ==========================================
FROM maven:3.9.9-eclipse-temurin-17 AS builder
WORKDIR /workspace

# Copy POM files first for dependency/layer caching
COPY traffic_simulation/pom.xml ./traffic_simulation/pom.xml
COPY traffic_simulation/traffic-core/pom.xml ./traffic_simulation/traffic-core/pom.xml
COPY traffic_simulation/traffic-api/pom.xml ./traffic_simulation/traffic-api/pom.xml
COPY traffic_simulation/traffic-desktop/pom.xml ./traffic_simulation/traffic-desktop/pom.xml

# Copy backend source modules
COPY traffic_simulation/traffic-core/src ./traffic_simulation/traffic-core/src
COPY traffic_simulation/traffic-api/src ./traffic_simulation/traffic-api/src

# Package only traffic-core and traffic-api into the shaded Fat JAR
WORKDIR /workspace/traffic_simulation
RUN mvn clean package -pl traffic-core,traffic-api -am -DskipTests -q

# ==========================================
# Stage 2: Lightweight Production JRE Runtime
# ==========================================
FROM eclipse-temurin:17-jre
WORKDIR /app

# Copy the generated executable Fat JAR
COPY --from=builder /workspace/traffic_simulation/traffic-api/target/traffic-api-1.0.0-SNAPSHOT.jar app.jar

# Render default port (injected dynamically at runtime by Render via PORT env var)
ENV PORT=10000
EXPOSE 10000

# Health check using the /api/status endpoint (used by Render, Railway, Docker Compose)
HEALTHCHECK --interval=30s --timeout=5s --start-period=15s --retries=3 \
  CMD wget -q -O- http://localhost:${PORT}/api/status || exit 1

# Memory-conscious JVM options suited for Render Free Tier (512MB RAM limit)
ENTRYPOINT ["java", "-XX:+UseContainerSupport", "-XX:MaxRAMPercentage=75.0", "-Xms64m", "-Xmx384m", "-jar", "app.jar"]
