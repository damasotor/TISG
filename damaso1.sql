-- ===========================================
-- Limpieza (borrar si existen)
-- ===========================================
DROP TABLE IF EXISTS public."v_sig_vias.shp" CASCADE;
DROP TABLE IF EXISTS public.v_uptu_paradas CASCADE;
DROP TABLE IF EXISTS public.rutas_resultado CASCADE; -- Se borrará si ya existía de la ejecución anterior

-- ===========================================
-- 1. CREACIÓN DE LA TABLA DE VÍAS
-- ===========================================

-- Esta tabla usa el nombre que espera tu funcion damaso3.sql (¡con comillas!)
CREATE TABLE public."v_sig_vias.shp" (
    gid serial PRIMARY KEY,
    geom geometry(LineString, 4326), -- Asumimos LineString y SRID 4326
    source INTEGER,
    target INTEGER,
    cost NUMERIC,
    longitud numeric
    -- Agrega otras columnas si las necesitas para los datos (ej: nombre de calle, etc.)
);

-- Copia los datos desde el archivo CSV (Este comando se ejecuta desde el cliente psql)
-- Nota: La primera columna de tu snippet de vias parece ser GID/ID, la segunda es la geometria.
\COPY public."v_sig_vias.shp" (gid, geom, source, target, cost, longitud) FROM 'v_sig_vias.csv' WITH (FORMAT csv, DELIMITER ',', HEADER true, NULL '', ENCODING 'UTF8');

-- Creación de índices necesarios para pgRouting
CREATE INDEX idx_vias_geom ON public."v_sig_vias.shp" USING gist(geom);
CREATE INDEX idx_vias_source ON public."v_sig_vias.shp" (source);
CREATE INDEX idx_vias_target ON public."v_sig_vias.shp" (target);


-- ===========================================
-- 2. CREACIÓN DE LA TABLA DE PARADAS
-- ===========================================

CREATE TABLE public.v_uptu_paradas (
    "COD_UBIC_P" INTEGER PRIMARY KEY, -- Usamos el código de parada como PK
    geometria geometry(Point, 4326), -- Asumimos Point y SRID 4326
    -- Agrega otras columnas si las necesitas
    "cod_calle" INTEGER,
    "nom_calle" VARCHAR(255)
);

-- Copia los datos desde el archivo CSV
-- Nota: La primera columna de tu snippet de paradas parece ser COD_UBIC_P, la segunda es la geometria.
\COPY public.v_uptu_paradas ("COD_UBIC_P", geometria, "cod_calle", "nom_calle") FROM 'v_uptu_paradas.csv' WITH (FORMAT csv, DELIMITER ',', HEADER true, NULL '', ENCODING 'UTF8');

-- Creación de índices espaciales
CREATE INDEX idx_paradas_geom ON public.v_uptu_paradas USING gist(geometria);

-- Finalmente, crea la tabla de resultados que usa tu script damaso3.sql
CREATE TABLE IF NOT EXISTS public.rutas_resultado (
    id SERIAL PRIMARY KEY,
    start_stop_cod INTEGER,
    end_stop_cod INTEGER,
    route_geom geometry(LineString, 4326),
    created_at TIMESTAMP DEFAULT now()
);

