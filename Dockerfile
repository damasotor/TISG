# Etapa 1: compilar con Maven
FROM maven:3.9.9-eclipse-temurin-21 AS build
WORKDIR /app
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Etapa 2: desplegar en Tomcat
FROM tomcat:10.1.46-jdk21
# Copiamos el .war compilado
COPY --from=build /app/target/transporte.war /usr/local/tomcat/webapps/transporte.war
EXPOSE 8080
