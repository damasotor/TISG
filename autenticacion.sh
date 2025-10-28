#!/bin/bash

# Nombre del contenedor y base de datos
CONTAINER_NAME="postgis_transporte"
DB_USER="admin"
DB_NAME="transporte"
# Se asume la contraseña definida en docker-compose.yml
DB_PASSWORD="admin" 
SQL_FILE="02_carga_datos.sql"

echo "==================================================="
echo "Iniciando proceso de carga segura para $SQL_FILE"
echo "==================================================="
echo "Contenedor objetivo: $CONTAINER_NAME"
echo "Usuario/DB: $DB_USER/$DB_NAME"
echo ""

# 1. Mover archivos para que solo 01_init.sql se ejecute al reiniciar
echo "1. Moviendo 02_carga_datos.sql y scripts 03_* fuera de initdb..."
cd ..
if [ -f initdb/02_carga_datos.sql ]; then mv initdb/02_carga_datos.sql . ; fi
if [ -f initdb/03_topologia_y_ruteo.sql ]; then mv initdb/03_topologia_y_ruteo.sql . ; fi
if [ -f initdb/03_funciones_de_Ruteo.sql ]; then mv initdb/03_funciones_de_Ruteo.sql . ; fi

# 2. Reiniciar contenedores
echo "2. Reiniciando contenedores (solo se ejecutará 01_init.sql)..."
# Usamos --remove-orphans para evitar el error anterior
docker-compose down --volumes --remove-orphans
docker-compose up -d
cd initdb

MAX_TRIES=15
WAIT_TIME=5

# --- Bucle de Espera y Conexión ---
echo "==================================================="
echo "3. Esperando a que el servidor PostGIS esté listo (Max $MAX_TRIES reintentos)"
echo "==================================================="

CONNECTION_SUCCESS=false
for i in $(seq 1 $MAX_TRIES); do
    # CORRECCIÓN CRÍTICA: Se añade PGPASSWORD. 
    # Esto permite a psql autenticarse correctamente contra el servidor.
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

# --- Verificación y Carga ---
if [ "$CONNECTION_SUCCESS" = true ]; then
    echo ""
    echo "4. Conexión exitosa. Ejecutando el script $SQL_FILE..."

    # Ejecutar el script SQL con PGPASSWORD
    docker exec -i -u postgres "$CONTAINER_NAME" env PGPASSWORD="$DB_PASSWORD" psql -U "$DB_USER" -d "$DB_NAME" < "../$SQL_FILE"

    if [ $? -eq 0 ]; then
        echo ""
        echo "==================================================="
        echo "ÉXITO: El script $SQL_FILE se aplicó correctamente."
        echo "==================================================="
        # 5. Mover archivos de vuelta para que docker-compose up/down no los borre.
        echo "5. Moviendo 02_carga_datos.sql y scripts 03_* de vuelta a initdb..."
        cd ..
        if [ -f 02_carga_datos.sql ]; then mv 02_carga_datos.sql initdb/ ; fi
        if [ -f 03_topologia_y_ruteo.sql ]; then mv 03_topologia_y_ruteo.sql initdb/ ; fi
        if [ -f 03_funciones_de_Ruteo.sql ]; then mv 03_funciones_de_Ruteo.sql initdb/ ; fi
        cd initdb
        exit 0 # Salida exitosa
    else
        echo ""
        echo "==================================================="
        echo "ERROR: Fallo al aplicar el script $SQL_FILE."
        echo "Revise los mensajes de error de psql arriba."
        echo "==================================================="
        exit 2 # Salida para indicar error de psql
    fi
else
    echo ""
    echo "==================================================="
    echo "ERROR CRÍTICO: El servidor PostGIS no respondió."
    echo "Esto significa que 01_init.sql falló o el servidor no pudo arrancar. Revise los logs."
    echo "Ejecute: docker logs postgis_transporte"
    echo "==================================================="
    exit 1 # Salida para indicar fallo de conexión
fi

