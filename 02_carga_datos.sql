-- Archivo: 02_carga_datos.sql
-- Propósito: Carga y transformación de datos geográficos para PostGIS y pgRouting.

-- IMPORTANTE: ESTE SCRIPT SE EJECUTA AUTOMÁTICAMENTE EN LA INICIALIZACIÓN DE DOCKER.

-- ===========================================
-- Configuración y extensiones
-- ===========================================
SET client_encoding TO 'UTF8';
-- Asegurar que las extensiones existan (si no fueron creadas en 01_init.sql)
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
    col5 VARCHAR, col6 VARCHAR, col7 VARCHAR, col8 VARCHAR,
    col9 VARCHAR, col10 VARCHAR, col11 VARCHAR, col12 VARCHAR
);

-- 1c. Carga de datos
-- Asegúrese de que el archivo 'v_sig_vias.csv' esté en /csv_data
COPY temp_vias_raw FROM '/csv_data/v_sig_vias.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8' NULL '';

-- 1d. Insertar y convertir de forma robusta.
INSERT INTO public.v_sig_vias (gid, geometria, source, target, cost, longitud)
SELECT
    col1::INTEGER AS gid,                  -- Columna 1: ID
    ST_SetSRID(ST_GeomFromEWKB(DECODE(col2, 'hex')), 4326), -- Columna 2: Geometría EWKB
    col4::INTEGER AS source,               -- Columna 4: Source (para pgRouting)
    col5::INTEGER AS target,               -- Columna 5: Target (para pgRouting)
    col6::NUMERIC AS cost,                 -- Columna 6: Costo de ruta
    col7::NUMERIC AS longitud              -- Columna 7: Longitud
FROM temp_vias_raw
-- Filtro robusto para asegurar que los campos de ruta y costo sean válidos
WHERE col1 ~ '^[0-9]+$' AND col2 IS NOT NULL AND col4 ~ '^[0-9]+$' AND col5 ~ '^[0-9]+$'
ON CONFLICT (gid) DO NOTHING;

-- 1e. Limpieza de tabla RAW
DROP TABLE temp_vias_raw;

-- 1f. Creación de índices espaciales y de pgRouting
CREATE INDEX idx_vias_geom ON public.v_sig_vias USING gist(geometria);
CREATE INDEX idx_vias_source ON public.v_sig_vias (source);
CREATE INDEX idx_vias_target ON public.v_sig_vias (target);


-- ===========================================
-- 2. CREACIÓN Y CARGA DE LA TABLA DE PARADAS (v_uptu_paradas)
-- ===========================================

-- 2a. Creación de la tabla RAW temporal
CREATE TABLE temp_paradas_raw (
    col1 VARCHAR, col2 VARCHAR, col3 VARCHAR, col4 VARCHAR,
    col5 VARCHAR, col6 VARCHAR, col7 VARCHAR, col8 VARCHAR,
    col9 VARCHAR, col10 VARCHAR, col11 VARCHAR, col12 VARCHAR,
    col13 VARCHAR, col14 VARCHAR, col15 VARCHAR, col16 VARCHAR,
    col17 VARCHAR, col18 VARCHAR, col19 VARCHAR, col20 VARCHAR
);

-- 2b. Carga de datos
COPY temp_paradas_raw FROM '/csv_data/v_uptu_paradas.csv' DELIMITER ',' CSV HEADER ENCODING 'UTF8' NULL '';

-- 2c. Crear la tabla final de PostGIS para paradas
CREATE TABLE public.v_uptu_paradas (
    cod_ubic_p INTEGER PRIMARY KEY,
    geometria geometry(Point, 4326)
);

-- 2d. Insertar y convertir de forma robusta.
INSERT INTO public.v_uptu_paradas (cod_ubic_p, geometria)
SELECT
    col1::INTEGER AS cod_ubic_p, 
    ST_SetSRID(ST_GeomFromEWKB(DECODE(col2, 'hex')), 4326)
FROM temp_paradas_raw
WHERE col1 ~ '^[0-9]+$' AND col2 IS NOT NULL
ON CONFLICT (cod_ubic_p) DO NOTHING;

-- 2e. Limpieza de tabla RAW
DROP TABLE temp_paradas_raw;

-- 2f. Creación de índices espaciales
CREATE INDEX idx_paradas_geom ON public.v_uptu_paradas USING gist(geometria);

-- ===========================================
-- 3. TABLA DE RESULTADOS DE RUTA (opcional)
-- ===========================================
CREATE TABLE IF NOT EXISTS public.rutas_resultado (
    id SERIAL PRIMARY KEY,
    start_stop_cod INTEGER,
    end_stop_cod INTEGER,
    route_geom geometry(LineString, 4326)
);

