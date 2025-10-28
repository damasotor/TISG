# --------------------------------------------------------------------------------
# Etapa 1: Compilación (Build Stage)
# Usa la imagen de Maven con JDK 21 para compilar el código.
# --------------------------------------------------------------------------------
FROM maven:3.9.9-eclipse-temurin-21 AS build

# Establece el directorio de trabajo dentro del contenedor
WORKDIR /app

# Copia el archivo de configuración del proyecto (pom.xml)
COPY pom.xml .

# Copia el código fuente del proyecto
COPY src ./src

# Compila el proyecto, generando el archivo .war en el directorio target/
# Se usa -DskipTests para omitir las pruebas y acelerar la construcción.
RUN mvn clean package -DskipTests

# --------------------------------------------------------------------------------
# Etapa 2: Ejecución (Runtime Stage)
# Usa una imagen base ligera de Tomcat con JDK 21 para la ejecución.
# --------------------------------------------------------------------------------
FROM tomcat:10.1.46-jdk21

# Copia el archivo .war compilado de la etapa 'build' al directorio de webapps de Tomcat.
# El nombre del archivo se asume como 'transporte.war' basado en la configuración por defecto de Maven.
# Al copiarlo como 'transporte.war', la aplicación estará accesible en /transporte.
COPY --from=build /app/target/transporte.war /usr/local/tomcat/webapps/transporte.war

# Expone el puerto por defecto de Tomcat (8080)
EXPOSE 8080

# El comando de entrada por defecto de la imagen de Tomcat ya inicia el servidor.
# No se necesita un CMD adicional.

