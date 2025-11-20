-- schema.sql
CREATE EXTENSION IF NOT EXISTS postgis;

-- tabla de empresas (opcional)
CREATE TABLE empresas (
  id SERIAL PRIMARY KEY,
  nombre TEXT NOT NULL
);

-- tabla lineas
CREATE TABLE lineas (
  id SERIAL PRIMARY KEY,
  codigo TEXT NOT NULL,
  origen TEXT,
  destino TEXT,
  empresa_id INTEGER REFERENCES empresas(id),
  geom geometry(LineString, 32721) -- UTM21S (ejemplo) o usar 4326 si preferís
);

-- tabla paradas
CREATE TABLE paradas (
  id SERIAL PRIMARY KEY,
  nombre TEXT,
  geom geometry(Point, 4326),
  enabled BOOLEAN DEFAULT TRUE
);

-- asociación parada-linea (horarios simplificados)
CREATE TABLE parada_linea (
  id SERIAL PRIMARY KEY,
  parada_id INTEGER REFERENCES paradas(id),
  linea_id INTEGER REFERENCES lineas(id),
  horarios TEXT -- JSON simple o array de texto: ["08:00","08:30"]
);

-- índices espaciales
CREATE INDEX idx_paradas_geom ON paradas USING GIST(geom);
CREATE INDEX idx_lineas_geom ON lineas USING GIST(geom);

-- Datos de prueba simples
INSERT INTO empresas (nombre) VALUES ('CUCTSA');

INSERT INTO paradas (nombre, geom)
VALUES 
  ('Plaza Independencia', ST_SetSRID(ST_MakePoint(-56.1645, -34.9060),4326)),
  ('Estación Central', ST_SetSRID(ST_MakePoint(-56.1700, -34.9000),4326));

-- ejemplo de línea con geom en 4326 (si usás 32721, convertir)
INSERT INTO lineas (codigo, origen, destino, empresa_id, geom)
VALUES ('104-este','Aduana','Paso Carrasco',1,
  ST_SetSRID(ST_MakeLine(
    ST_Point(-56.1660, -34.9065),
    ST_Point(-56.1650, -34.9040),
    ST_Point(-56.1640, -34.9020)
  ), 4326)
);

-- Asociar paradas
INSERT INTO parada_linea (parada_id, linea_id, horarios)
VALUES (1, 1, '["08:00","08:30","09:00"]'),
       (2, 1, '["08:05","08:35","09:05"]');

