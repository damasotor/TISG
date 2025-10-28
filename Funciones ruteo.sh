#!/bin/bash

# --- CONFIGURACIÓN ---
CONTAINER_NAME="postgis_transporte"
DB_USER="admin"
DB_NAME="transporte"
# Se asume la contraseña definida en docker-compose.yml
DB_PASSWORD="admin" 
SQL_FILE="03_topologia_y_ruteo.sql" # Asumiendo que es el script más completo para ruteo
MAX_TRIES=15
WAIT_TIME=5

echo "===================================================="
echo " INICIO DEL PROCESO DE CARGA DE TOPOLOGÍA Y RUTEO "
echo "===================================================="
echo "Contenedor objetivo: $CONTAINER_NAME"
echo "Usuario/DB: $DB_USER/$DB_NAME"
echo "Script a ejecutar: $SQL_FILE"
echo ""

# Subir un nivel para ejecutar docker-compose
cd ..
echo "1. Reiniciando contenedores..."
# Usamos down/up para asegurar que el servicio esté corriendo en el foreground
docker-compose down 
docker-compose up -d
cd initdb
echo ""

echo "===================================================="
echo " 2. Esperando a que el servidor PostGIS esté listo "
echo "===================================================="

# --- Bucle de Espera y Conexión ---
CONNECTION_SUCCESS=false
for i in $(seq 1 $MAX_TRIES); do
    # CORRECCIÓN CRÍTICA: Se añade PGPASSWORD para la autenticación
    docker exec -i -u postgres "$CONTAINER_NAME" env PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "   [ÉXITO] Conexión establecida en el intento $i."
        CONNECTION_SUCCESS=true
        break
    else
        echo "   [FALLO] Intento $i. Esperando $WAIT_TIME segundos..."
        sleep $WAIT_TIME
    fi
done

# --- Ejecución del Script 03 ---
if [ "$CONNECTION_SUCCESS" = true ]; then
    echo ""
    echo "==================================================="
    echo " 3. Ejecutando Topología y Funciones de Ruteo... "
    echo "==================================================="
    
    # Ejecutar el script SQL con PGPASSWORD
    # Usamos "../$SQL_FILE" si este script se ejecuta desde initdb/
    docker exec -i -u postgres "$CONTAINER_NAME" env PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -d "$DB_NAME" < "$SQL_FILE"

    if [ $? -eq 0 ]; then
        echo ""
        echo "==================================================="
        echo "¡ÉXITO! Topología y Ruteo aplicados correctamente."
        echo "==================================================="
    else
        echo ""
        echo "==================================================="
        echo "ERROR: Fallo al aplicar el script $SQL_FILE."
        echo "Revise los errores de psql arriba."
        echo "==================================================="
    fi
else
    echo ""
    echo "==================================================="
    echo "ERROR CRÍTICO: El servidor PostGIS no respondió. Deteniendo."
    echo "==================================================="
fi

