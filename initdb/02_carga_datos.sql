-- Archivo: 02_carga_datos.sql
-- Propósito: Carga y transformación de datos geográficos para PostGIS y pgRouting.

-- Conexión a la base de datos y usuario correctos
\connect transporte admin

-- ===========================================
-- Configuración y extensiones
-- ===========================================
SET client_encoding TO 'UTF8';
-- Es seguro repetir la creación de extensiones
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- ===========================================
-- Limpieza (borrar si existen)
-- ===========================================
DROP TABLE IF EXISTS public.v_sig_vias CASCADE;
DROP TABLE IF EXISTS public.v_uptu_paradas CASCADE;
DROP TABLE IF EXISTS public.rutas_resultado CASCADE;
DROP TABLE IF EXISTS temp_vias_raw;
DROP TABLE IF EXISTS temp_paradas_raw;

-- ===========================================
-- 1. CREACIÓN Y CARGA DE LA TABLA DE VÍAS (v_sig_vias)
-- ===========================================

-- 1a. Crear la tabla final de PostGIS
CREATE TABLE public.v_sig_vias (
gid INTEGER PRIMARY KEY,
-- Tipo de geometría MultiLineString (SRID 4326)
geometria geometry(MultiLineString, 4326),
source INTEGER,
target INTEGER,
cost NUMERIC,
longitud NUMERIC
);

-- 1b. Creación de la tabla RAW temporal para la carga
CREATE TABLE temp_vias_raw (
col1 VARCHAR, col2 VARCHAR, col3 VARCHAR, col4 VARCHAR,
col5 VARCHAR, col6 VARCHAR, col7 VARCHAR, col8 VARCHAR
);

-- 1c. Carga de datos RAW desde el CSV
COPY temp_vias_raw FROM '/csv_data/v_sig_vias.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8' NULL '';

-- 1d. Insertar los datos convertidos y asignar el SRID
INSERT INTO public.v_sig_vias (gid, geometria, longitud, cost)
SELECT
col6::INTEGER AS gid, -- Columna 6 (GID)
-- CONVERSIÓN HEX-EWKB: Asegurar MultiLineString y SRID 4326
ST_Multi(ST_SetSRID(ST_GeomFromEWKB(DECODE(col2, 'hex')), 4326)) AS geometria,
col8::NUMERIC AS longitud,
col8::NUMERIC AS cost
FROM temp_vias_raw
-- Filtro robusto
WHERE col6 ~ '^[0-9]+$' AND col2 IS NOT NULL
ON CONFLICT (gid) DO NOTHING;

-- 1e. Limpieza de tabla RAW
DROP TABLE temp_vias_raw;

-- 1f. Creación de índices espaciales
CREATE INDEX idx_vias_geom ON public.v_sig_vias USING gist(geometria);

-- ===========================================
-- 1g. GENERACIÓN DE TOPOLOGÍA pgRouting
-- ===========================================
-- Usando la sintaxis más simple para pgr_createTopology (4 argumentos)
SELECT pgr_createTopology('v_sig_vias', 0.00001, 'geometria', 'gid');

-- Rellenar el costo si es nulo o cero
UPDATE public.v_sig_vias
SET cost = ST_Length(geometria)
WHERE cost IS NULL OR cost = 0;

-- ===========================================
-- 2. CREACIÓN Y CARGA DE PARADAS (v_uptu_paradas.csv)
-- ===========================================

-- 2a. Tabla temporal con exceso de columnas (máxima robustez)
CREATE TABLE temp_paradas_raw (
col1 VARCHAR, col2 VARCHAR, col3 VARCHAR, col4 VARCHAR,
col5 VARCHAR, col6 VARCHAR, col7 VARCHAR, col8 VARCHAR,
col9 VARCHAR, col10 VARCHAR, col11 VARCHAR, col12 VARCHAR,
col13 VARCHAR, col14 VARCHAR, col15 VARCHAR, col16 VARCHAR,
col17 VARCHAR, col18 VARCHAR, col19 VARCHAR, col20 VARCHAR
);

-- 2b. Carga de datos RAW desde el CSV
COPY temp_paradas_raw FROM '/csv_data/v_uptu_paradas.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8' NULL '';

-- 2c. Crear la tabla final de PostGIS para paradas
CREATE TABLE public.v_uptu_paradas (
cod_ubic_p INTEGER PRIMARY KEY,
geometria geometry(Point, 4326)
);

-- 2d. Insertar y convertir de forma robusta.
INSERT INTO public.v_uptu_paradas (cod_ubic_p, geometria)
SELECT
col1::INTEGER AS cod_ubic_p, -- Columna 1 (ID de la parada)
-- CONVERSIÓN HEX-EWKB: Asignar el SRID 4326 inmediatamente
ST_SetSRID(ST_GeomFromEWKB(DECODE(col2, 'hex')), 4326)
FROM temp_paradas_raw
-- Filtro robusto
WHERE col1 ~ '^[0-9]+$' AND col2 IS NOT NULL
ON CONFLICT (cod_ubic_p) DO NOTHING;

-- 2e. Limpieza de tabla RAW
DROP TABLE temp_paradas_raw;

-- 2f. Creación de índices espaciales
CREATE INDEX idx_paradas_geom ON public.v_uptu_paradas USING gist(geometria);

-- ===========================================
-- 3. TABLA DE RESULTADOS DE RUTA
-- ===========================================

-- Tabla para almacenar rutas calculadas
CREATE TABLE IF NOT EXISTS public.rutas_resultado (
id SERIAL PRIMARY KEY,
start_stop_cod INTEGER,
end_stop_cod INTEGER,
route_geom geometry(LineString, 4326),
created_at TIMESTAMP DEFAULT now()
);

-- ===========================================
-- 4. PERMISOS CRÍTICOS
-- ===========================================
GRANT ALL ON public.v_sig_vias TO admin;
GRANT ALL ON public.v_uptu_paradas TO admin;
GRANT ALL ON public.rutas_resultado TO admin;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO admin;
