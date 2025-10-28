#!/bin/sh
# Script para esperar a que el servicio 'postgis' esté disponible en el puerto 5432

HOST="postgis"
PORT="5432"
TIMEOUT=30 # Tiempo máximo de espera
MAX_RETRIES=10
RETRY_INTERVAL=3 # segundos

echo "Esperando a que el servicio de base de datos PostGIS ($HOST:$PORT) se inicie..."

for i in $(seq 1 $MAX_RETRIES); do
    # Usar netcat (nc) para verificar la conexión al puerto.
    if nc -z $HOST $PORT; then
        echo "✅ PostGIS está disponible en $HOST:$PORT."
        break
    fi

    if [ "$i" -eq "$MAX_RETRIES" ]; then
        echo "❌ Error: PostGIS no está disponible después de $MAX_RETRIES intentos."
        exit 1
    fi

    echo "Intento $i/$MAX_RETRIES fallido. Reintentando en $RETRY_INTERVAL segundos..."
    sleep $RETRY_INTERVAL
done

# Ejecutar el comando principal del contenedor (Tomcat)
# Los argumentos pasados al script (catalina.sh run) se ejecutan aquí.
echo "Iniciando Tomcat..."
exec "$@"

