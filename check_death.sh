#!/bin/bash

# --- CONFIGURACIÓN ---
CONTAINER_NAME="postgis_transporte"
DB_USER="admin"
DB_NAME="transporte"
MAX_TRIES=5
WAIT_TIME=5

echo "==================================================="
echo " PASO 1: Reinicio y reconstrucción de contenedores "
echo "==================================================="
# Detener y remover todo el volumen de datos para garantizar una carga fresca
docker-compose down --volumes
docker-compose up -d

echo ""
echo "==================================================="
echo " PASO 2: Monitoreo de logs durante la inicialización "
echo "==================================================="

# Esperar un tiempo prudencial para que la base de datos inicie y muera (si es que muere)
echo "Esperando 30 segundos mientras los scripts 01 y 02 se ejecutan..."
sleep 30

echo ""
echo "==================================================="
echo " PASO 3: Intento de Conexión (Diagnóstico)"
echo "==================================================="

CONNECTION_SUCCESS=false
for i in $(seq 1 $MAX_TRIES); do
    # Intento de conexión con un timeout muy corto (-c 'SELECT 1;')
    docker exec -i -u postgres "$CONTAINER_NAME" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "   [ÉXITO] Conexión establecida en el intento $i."
        CONNECTION_SUCCESS=true
        break
    else
        echo "   [FALLO] Intento $i. Servidor no acepta conexiones."
        sleep 2
    fi
done

echo ""
echo "==================================================="
echo " PASO 4: Logs finales del servidor PostGIS"
echo " (Muestra la causa de la muerte o el final de la carga)"
echo "==================================================="
docker logs "$CONTAINER_NAME"

# Si la conexión falló, el problema es irresoluble sin ver el log
if [ "$CONNECTION_SUCCESS" = false ]; then
    echo ""
    echo "==================================================="
    echo " RESULTADO: ¡CRÍTICO! El servidor nunca respondió."
    echo " POR FAVOR, COMPARTA TODOS LOS LOGS SUPERIORES"
    echo "==================================================="
else
    echo ""
    echo "==================================================="
    echo " RESULTADO: Conexión exitosa. Listo para la fase 03."
    echo "==================================================="
fi
