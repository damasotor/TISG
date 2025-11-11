

-- ======================================================
-- LIMPIEZA
-- ======================================================
DROP VIEW IF EXISTS public.vista_rutas_qgis;
DROP TABLE IF EXISTS public.rutas_resultado;

CREATE TABLE public.rutas_resultado (
    id SERIAL PRIMARY KEY,
    start_stop_id INTEGER,
    end_stop_id INTEGER,
    route_geom geometry(MultiLineString, 4326),
    total_distance DOUBLE PRECISION,
    created_at TIMESTAMP DEFAULT NOW()
);

-- ======================================================
-- CÁLCULO DE RUTA MÁS CORTA ENTRE A1 y A3
-- ======================================================
DO $$
DECLARE
  x INTEGER := 3;
  y INTEGER := 14;
BEGIN
  RAISE NOTICE 'x = %, y = %', x, y;


WITH
p_ini AS (
  SELECT 
    v.source AS nodo
  FROM public.paradas p
  JOIN public.v_sig_vias v
    ON ST_DWithin(ST_Transform(p.geom,4326)::geography,
                  ST_Transform(v.geom,4326)::geography, 150)
  WHERE p.id = x
  ORDER BY ST_Distance(
    ST_Transform(p.geom,4326)::geography,
    ST_Transform(v.geom,4326)::geography
  )
  LIMIT 1
),
p_fin AS (
  SELECT 
    v.target AS nodo
  FROM public.paradas p
  JOIN public.v_sig_vias v
    ON ST_DWithin(ST_Transform(p.geom,4326)::geography,
                  ST_Transform(v.geom,4326)::geography, 150)
  WHERE p.id = y
  ORDER BY ST_Distance(
    ST_Transform(p.geom,4326)::geography,
    ST_Transform(v.geom,4326)::geography
  )
  LIMIT 1
),
ruta_calc AS (
  SELECT ST_Transform(v.geom,4326) AS geom
  FROM pgr_dijkstra(
    'SELECT CAST("GID" AS integer) AS id,
            CAST(source AS integer) AS source,
            CAST(target AS integer) AS target,
            ST_Length(ST_Transform(geom,4326)::geography) AS cost
     FROM public.v_sig_vias',
    (SELECT nodo FROM p_ini),
    (SELECT nodo FROM p_fin),
    false
  ) AS r
  JOIN public.v_sig_vias v
    ON v."GID"::integer = r.edge
),
ruta_completa AS (
  SELECT 
    ST_Multi(ST_LineMerge(ST_Union(geom)))::geometry(MultiLineString,4326) AS geom_total,
    ST_Length(ST_LineMerge(ST_Union(geom))::geography) AS distancia_metros
  FROM ruta_calc
)
INSERT INTO public.rutas_resultado (start_stop_id, end_stop_id, route_geom, total_distance)
SELECT x, y, geom_total, distancia_metros
FROM ruta_completa;

END $$;
-- ======================================================
-- CREAR VISTA PARA QGIS (no )
-- ======================================================
CREATE OR REPLACE VIEW public.vista_rutas_qgis AS
SELECT 
    rr.id,
    'ruta' AS tipo,
    ST_SetSRID(rr.route_geom, 4326) AS geometria,
    'red' AS color,
    3 AS grosor,
    'Ruta ' || rr.id::text || ' (' || ROUND(rr.total_distance::NUMERIC, 0) || ' m)' AS etiqueta,
    rr.start_stop_id,
    rr.end_stop_id
FROM public.rutas_resultado rr

UNION ALL

SELECT 
    p.id + 100000,
    'parada_inicio' AS tipo,
    ST_SetSRID(p.geom, 4326),
    'blue',
    1,
    'Inicio ' || p.id::text,
    p.id,
    NULL
FROM public.paradas p
WHERE p.id IN (SELECT DISTINCT start_stop_id FROM public.rutas_resultado)

UNION ALL

SELECT 
    p.id + 200000,
    'parada_destino' AS tipo,
    ST_SetSRID(p.geom, 4326),
    'green',
    1,
    'Destino ' || p.id::text,
    NULL,
    p.id
FROM public.paradas p
WHERE p.id IN (SELECT DISTINCT end_stop_id FROM public.rutas_resultado);

SELECT id, GeometryType(route_geom), total_distance FROM public.rutas_resultado;
