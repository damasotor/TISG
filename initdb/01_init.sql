-- 01_init.sql  ------------------------------------------

-- 0) Extensión PostGIS
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;

-- 1) Limpieza
-- DROP TABLE IF EXISTS paradas CASCADE;
-- DROP TABLE IF EXISTS lineas CASCADE;

-- 2) Tablas
-- Paradas en EPSG:4326 (lat/lon). incluye lat/lon + geom.
CREATE TABLE paradas (
  id      SERIAL PRIMARY KEY,
  nombre  VARCHAR(100) NOT NULL,
  lat     DOUBLE PRECISION,
  lon     DOUBLE PRECISION,
  geom    geometry(Point, 4326)
);

-- Líneas en EPSG:32721 (UTM 21S, en metros)
CREATE TABLE lineas (
  id       SERIAL PRIMARY KEY,
  codigo   VARCHAR(50)  NOT NULL,
  origen   VARCHAR(100) NOT NULL,
  destino  VARCHAR(100) NOT NULL,
  empresa  VARCHAR(100) NOT NULL,
  geom     geometry(LineString, 32721) NOT NULL
);

-- 3) Indices espaciales GIST
CREATE INDEX IF NOT EXISTS idx_paradas_geom ON paradas USING GIST (geom);
CREATE INDEX IF NOT EXISTS idx_lineas_geom  ON lineas  USING GIST (geom);

--Inserts de ejemplo
--INSERT INTO paradas (nombre, lat, lon, geom) VALUES
--  ('Tres Cruces', -34.903, -56.172, ST_SetSRID(ST_MakePoint(-56.172, -34.903), 4326)),

--INSERT INTO lineas (codigo, origen, destino, empresa, geom)
--VALUES
--  ('104-este', 'Aduana', 'Paso Carrasco', 'CUTCSA',
--   ST_GeomFromText('LINESTRING(576000 6138500, 576500 6138800, 577000 6139000)', 32721)),

