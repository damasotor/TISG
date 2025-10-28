-- ===========================================
-- Limpieza (borrar si existen)
-- ===========================================
DROP TABLE IF EXISTS public."v_sig_vias.shp" CASCADE;
DROP TABLE IF EXISTS public.v_uptu_paradas CASCADE;
DROP TABLE IF EXISTS public.rutas_resultado CASCADE;

-- ===========================================
-- 1. CARGA Y CONVERSION DE VÍAS ("v_sig_vias.shp")
-- ===========================================

-- 1a. Tabla temporal definida para 8 columnas
CREATE TABLE temp_vias_raw (
    col1 VARCHAR, col2 VARCHAR, col3 VARCHAR, col4 VARCHAR, col5 VARCHAR,
    col6 VARCHAR, col7 VARCHAR, col8 VARCHAR
);

-- Copiar los datos del CSV. Usamos HEADER true para ignorar la primera fila.
\COPY temp_vias_raw FROM '/tmp/v_sig_vias.csv' WITH (FORMAT csv, DELIMITER ',', HEADER true, NULL '', ENCODING 'UTF8');

-- 1b. Crear la tabla final de PostGIS
CREATE TABLE public."v_sig_vias.shp" (
    "GID" INTEGER PRIMARY KEY,
    geom geometry(MultiLineString, 4326),
    source INTEGER,
    target INTEGER,
    cost NUMERIC,
    longitud NUMERIC
);

-- 1c. Insertar y convertir. Filtramos cualquier línea cuyo col1 no sea un número (resolviendo "JUAN PARRA DEL RIEGO").
INSERT INTO public."v_sig_vias.shp" ("GID", geom, source, target, cost, longitud)
SELECT
    col1::INTEGER AS "GID",
    ST_GeomFromEWKB(DECODE(col2, 'hex')),
    NULLIF(col3, '')::INTEGER AS source, -- Usar NULLIF para manejar campos vacíos
    NULLIF(col4, '')::INTEGER AS target, -- Usar NULLIF para manejar campos vacíos
    NULLIF(col5, '')::NUMERIC AS cost,
    NULLIF(col6, '')::NUMERIC AS longitud
FROM temp_vias_raw
WHERE col1 ~ '^\d+$'
ON CONFLICT ("GID") DO NOTHING; -- Ignorar duplicados

-- Limpieza
DROP TABLE temp_vias_raw;

-- Creación de índices necesarios para pgRouting
CREATE INDEX idx_vias_geom ON public."v_sig_vias.shp" USING gist(geom);
CREATE INDEX idx_vias_source ON public."v_sig_vias.shp" (source);
CREATE INDEX idx_vias_target ON public."v_sig_vias.shp" (target);


-- ===========================================
-- 2. CARGA Y CONVERSION DE PARADAS (v_uptu_paradas)
-- ESTRATEGIA: Ultra simplificación para evitar el fallo de la línea 387
--             Solo cargamos el ID (Columna 1) y la geometría (Columna 2).
-- ===========================================

-- 2a. Tabla temporal con SOLO 8 COLUMNAS (Suficientes para capturar col1 y col2 y dar margen)
CREATE TABLE temp_paradas_raw (
    col1 VARCHAR, -- COD_UBIC_P
    col2 VARCHAR, -- Geometría
    col3 VARCHAR,
    col4 VARCHAR,
    col5 VARCHAR,
    col6 VARCHAR,
    col7 VARCHAR,
    col8 VARCHAR
);

-- Copiar los datos del CSV. Usamos el delimitador de coma que es el que consistentemente aparece en el error.
\COPY temp_paradas_raw FROM '/tmp/v_uptu_paradas.csv' WITH (FORMAT csv, DELIMITER ',', HEADER true, NULL '', ENCODING 'UTF8');

-- 2b. Crear la tabla final de PostGIS
CREATE TABLE public.v_uptu_paradas (
    "COD_UBIC_P" INTEGER PRIMARY KEY,
    geometria geometry(Point, 4326)
    -- Quitamos nom_calle y cod_calle para máxima robustez
);

-- 2c. Insertar y convertir. Solo necesitamos col1 y col2.
INSERT INTO public.v_uptu_paradas ("COD_UBIC_P", geometria)
SELECT
    col1::INTEGER AS "COD_UBIC_P",
    ST_GeomFromEWKB(DECODE(col2, 'hex'))
FROM temp_paradas_raw
WHERE
    col1 ~ '^\d+$' -- Asegurar que el ID es un número
    AND col2 IS NOT NULL -- Asegurar que la geometría existe
ON CONFLICT ("COD_UBIC_P") DO NOTHING;

-- Limpieza
DROP TABLE temp_paradas_raw;

-- Creación de índices espaciales
CREATE INDEX IF NOT EXISTS idx_paradas_geom ON public.v_uptu_paradas USING gist(geometria);

-- Tabla de resultados (asegurar existencia)
CREATE TABLE IF NOT EXISTS public.rutas_resultado (
    id SERIAL PRIMARY KEY,
    start_stop_cod INTEGER,
    end_stop_cod INTEGER,
    route_geom geometry(LineString, 4326),
    created_at TIMESTAMP DEFAULT now()
);

