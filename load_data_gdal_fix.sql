-- ===========================================
-- LIMPIEZA TOTAL PARA REINICIAR
-- ===========================================
DROP TABLE IF EXISTS public."v_sig_vias.shp" CASCADE;
DROP TABLE IF EXISTS public.v_uptu_paradas CASCADE;
DROP TABLE IF EXISTS public.rutas_resultado CASCADE;
DROP TABLE IF EXISTS public.temp_paradas_gdal CASCADE;
DROP TABLE IF EXISTS public.temp_vias_gdal CASCADE;

-- ===========================================
-- 1. CREACION DE TABLAS FINALES CON ESTRUCTURA CORRECTA
-- ===========================================

-- 1a. Tabla final de Vias
CREATE TABLE public."v_sig_vias.shp" (
    "GID" INTEGER PRIMARY KEY,
    geom geometry(MultiLineString, 4326),
    source INTEGER,
    target INTEGER,
    cost NUMERIC,
    longitud NUMERIC
);
CREATE INDEX idx_vias_geom ON public."v_sig_vias.shp" USING gist(geom);
CREATE INDEX idx_vias_source ON public."v_sig_vias.shp" (source);
CREATE INDEX idx_vias_target ON public."v_sig_vias.shp" (target);


-- 1b. Tabla final de Paradas
CREATE TABLE public.v_uptu_paradas (
    "COD_UBIC_P" INTEGER PRIMARY KEY,
    geometria geometry(Point, 4326)
);
CREATE INDEX idx_paradas_geom ON public.v_uptu_paradas USING gist(geometria);

-- 1c. Tabla de resultados
CREATE TABLE IF NOT EXISTS public.rutas_resultado (
    id SERIAL PRIMARY KEY,
    start_stop_cod INTEGER,
    end_stop_cod INTEGER,
    route_geom geometry(LineString, 4326),
    created_at TIMESTAMP DEFAULT now()
);

-- Nota: Las migraciones de datos se realizarán a continuación usando GDAL y luego
-- se copiarán a estas tablas finales.

