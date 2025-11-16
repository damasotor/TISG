#!/bin/bash

# Nombre del archivo de salida
ARCHIVO_SALIDA="contenido_total.txt"

# Eliminar el archivo de salida anterior si existe, para empezar de cero
> "$ARCHIVO_SALIDA"

# --- 1. Procesar el archivo pom.xml ---
ARCHIVO="pom.xml"
if [ -f "$ARCHIVO" ]; then
    echo "##################################################" >> "$ARCHIVO_SALIDA"
    echo "### Archivo: $ARCHIVO" >> "$ARCHIVO_SALIDA"
    echo "##################################################" >> "$ARCHIVO_SALIDA"
    cat "$ARCHIVO" >> "$ARCHIVO_SALIDA"
    echo -e "\n\n" >> "$ARCHIVO_SALIDA" # Añade un par de saltos de línea para separación
else
    echo "Advertencia: El archivo pom.xml no fue encontrado." >> "$ARCHIVO_SALIDA"
fi


# --- 2. Procesar todos los archivos dentro de la carpeta src/ (incluyendo subdirectorios) ---

# Activa la opción globstar para recorrer directorios de forma recursiva (como **)
shopt -s globstar

echo "##################################################" >> "$ARCHIVO_SALIDA"
echo "### Contenido de la carpeta src/" >> "$ARCHIVO_SALIDA"
echo "##################################################" >> "$ARCHIVO_SALIDA"

# Bucle para recorrer archivos en src/ (/**/*.*/)
for ARCHIVO in src/**/*; do
    # Verifica si es un archivo regular y no un directorio
    if [ -f "$ARCHIVO" ]; then
        # Añadir rótulo
        echo "==================================================" >> "$ARCHIVO_SALIDA"
        echo "=== Archivo: $ARCHIVO" >> "$ARCHIVO_SALIDA"
        echo "==================================================" >> "$ARCHIVO_SALIDA"
        
        # Añadir contenido del archivo
        cat "$ARCHIVO" >> "$ARCHIVO_SALIDA"
        echo -e "\n\n" >> "$ARCHIVO_SALIDA" # Añade un par de saltos de línea para separación
    fi
done

# Desactiva globstar
shopt -u globstar

echo "Proceso completado. El contenido combinado se encuentra en: $ARCHIVO_SALIDA"
