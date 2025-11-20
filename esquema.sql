--
-- PostgreSQL database dump
--

\restrict QUHPpTxLnKaJgxNxnABb3PhDbtJHURd2AWpSTTMroCcRYvaie4eTHEw7T8ckNyJ

-- Dumped from database version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)
-- Dumped by pg_dump version 16.10 (Ubuntu 16.10-0ubuntu0.24.04.1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: postgis; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;


--
-- Name: EXTENSION postgis; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION postgis IS 'PostGIS geometry and geography spatial types and functions';


--
-- Name: pgrouting; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgrouting WITH SCHEMA public;


--
-- Name: EXTENSION pgrouting; Type: COMMENT; Schema: -; Owner: 
--

COMMENT ON EXTENSION pgrouting IS 'pgRouting Extension';


--
-- Name: calcular_ruta(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calcular_ruta(inicio integer, fin integer) RETURNS public.geometry
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_geom_total geometry;
    v_start_node integer;
    v_end_node integer;
BEGIN
    -- Si inicio = fin devolvemos NULL (o podrías devolver punto vacío)
    IF inicio = fin THEN
        RETURN NULL;
    END IF;

    -- 1) Encontrar el vértice PGR más cercano a la parada inicio
    SELECT id INTO v_start_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = inicio)
    LIMIT 1;

    -- 2) Encontrar el vértice PGR más cercano a la parada fin
    SELECT id INTO v_end_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = fin)
    LIMIT 1;

    -- Si no se encontraron nodos, devolvemos NULL
    IF v_start_node IS NULL OR v_end_node IS NULL THEN
        RETURN NULL;
    END IF;

    -- 3) Ejecutar pgr_dijkstra con la tabla de edges. Usar gid_int como id si es entero consistente.
    --    Nota: Filtramos r.edge > 0 (pgr_dijkstra deja -1 en filas de inicio/final)
    --    y luego agregamos las geometrías en orden r.seq para coleccionarlas correctamente.
    WITH dijkstra_result AS (
        SELECT r.seq, r.edge
        FROM pgr_dijkstra(
            'SELECT gid_int AS id, source::integer AS source, target::integer AS target,
                    ST_Length(geom::geography) AS cost
             FROM public.v_sig_vias',
            v_start_node,
            v_end_node,
            false
        ) AS r
        WHERE r.edge > 0
        ORDER BY r.seq
    ),
    ruta_edges AS (
        SELECT v.geom
        FROM dijkstra_result dr
        JOIN public.v_sig_vias v
          ON v.gid_int = dr.edge
        -- ORDER BY dr.seq is already applied in dijkstra_result
    )
    -- 4) Coleccionar en orden y convertir a MultiLineString
    SELECT ST_Multi(ST_LineMerge(ST_Collect(geom))) INTO v_geom_total
    FROM ruta_edges;

    -- Si no hay geometría (ruta vacía) devolvemos NULL
    IF v_geom_total IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN v_geom_total;
END;
$$;


ALTER FUNCTION public.calcular_ruta(inicio integer, fin integer) OWNER TO postgres;

--
-- Name: calcular_ruta_con_via(integer, double precision, double precision, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.calcular_ruta_con_via(id_inicio integer, via_lon double precision, via_lat double precision, id_fin integer) RETURNS public.geometry
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_start_node integer;
    v_via_node   integer;
    v_end_node   integer;
    v_geom_total geometry;
BEGIN
    -- 1) Nodos en la red más cercanos a inicio, via y fin
    SELECT id INTO v_start_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = id_inicio)
    LIMIT 1;

    SELECT id INTO v_via_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> ST_SetSRID(ST_MakePoint(via_lon, via_lat), 4326)
    LIMIT 1;

    SELECT id INTO v_end_node
    FROM public.v_sig_vias_vertices_pgr
    ORDER BY the_geom <-> (SELECT geom FROM public.paradas WHERE id = id_fin)
    LIMIT 1;

    IF v_start_node IS NULL OR v_via_node IS NULL OR v_end_node IS NULL THEN
        RETURN NULL;
    END IF;

    WITH
    -- tramo inicio → via
    dijkstra_1 AS (
        SELECT r.seq, r.edge
        FROM pgr_dijkstra(
            'SELECT gid_int AS id,
                    source::integer AS source,
                    target::integer AS target,
                    ST_Length(geom::geography) AS cost
             FROM public.v_sig_vias',
            v_start_node,
            v_via_node,
            false
        ) AS r
        WHERE r.edge > 0
        ORDER BY r.seq
    ),
    ruta1 AS (
        SELECT v.geom
        FROM dijkstra_1 dr
        JOIN public.v_sig_vias v
          ON v.gid_int = dr.edge
    ),

    -- tramo via → fin
    dijkstra_2 AS (
        SELECT r.seq, r.edge
        FROM pgr_dijkstra(
            'SELECT gid_int AS id,
                    source::integer AS source,
                    target::integer AS target,
                    ST_Length(geom::geography) AS cost
             FROM public.v_sig_vias',
            v_via_node,
            v_end_node,
            false
        ) AS r
        WHERE r.edge > 0
        ORDER BY r.seq
    ),
    ruta2 AS (
        SELECT v.geom
        FROM dijkstra_2 dr
        JOIN public.v_sig_vias v
          ON v.gid_int = dr.edge
    )

    -- unir ambos tramos en orden
    SELECT ST_Multi(ST_LineMerge(ST_Collect(geom)))
    INTO v_geom_total
    FROM (
        SELECT geom FROM ruta1
        UNION ALL
        SELECT geom FROM ruta2
    ) AS sub;

    IF v_geom_total IS NULL THEN
        RETURN NULL;
    END IF;

    RETURN v_geom_total;
END;
$$;


ALTER FUNCTION public.calcular_ruta_con_via(id_inicio integer, via_lon double precision, via_lat double precision, id_fin integer) OWNER TO postgres;

--
-- Name: registrar_ruta(integer, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_ruta(id_inicio integer, id_fin integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_geom geometry;
    v_distancia double precision;
BEGIN
    -- Manejar caso inicio = fin
    IF id_inicio = id_fin THEN
        RETURN json_build_object(
            'success', true,
            'geom', ST_AsGeoJSON(ST_Multi(ST_GeomFromText('MULTILINESTRING EMPTY', 4326))),
            'distancia_m', 0
        );
    END IF;

    BEGIN
        -- Calcular ruta
        v_geom := calcular_ruta(id_inicio, id_fin);

        IF v_geom IS NULL THEN
            RETURN json_build_object(
                'success', false,
                'message', 'No se pudo generar la ruta: ruta vacía'
            );
        END IF;

        -- Calcular distancia
        v_distancia := ST_Length(v_geom::geography);

        -- Guardar en tabla
        INSERT INTO rutas_resultado(start_stop_id, end_stop_id, route_geom, total_distance)
        VALUES (id_inicio, id_fin, v_geom, v_distancia);

        -- Devolver GeoJSON con cast seguro
        RETURN json_build_object(
            'success', true,
            'geom', ST_AsGeoJSON(v_geom::geometry),
            'distancia_m', v_distancia
        );
    EXCEPTION
        WHEN OTHERS THEN
            RETURN json_build_object(
                'success', false,
                'message', 'Error de base de datos: ' || SQLERRM
            );
    END;
END;
$$;


ALTER FUNCTION public.registrar_ruta(id_inicio integer, id_fin integer) OWNER TO postgres;

--
-- Name: registrar_ruta_con_via(integer, double precision, double precision, integer); Type: FUNCTION; Schema: public; Owner: postgres
--

CREATE FUNCTION public.registrar_ruta_con_via(id_inicio integer, via_lon double precision, via_lat double precision, id_fin integer) RETURNS json
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_geom geometry;
    v_distancia double precision;
BEGIN
    v_geom := calcular_ruta_con_via(id_inicio, via_lon, via_lat, id_fin);

    IF v_geom IS NULL THEN
        RETURN json_build_object(
            'success', false,
            'message', 'No se pudo generar la ruta con via'
        );
    END IF;

    v_distancia := ST_Length(v_geom::geography);

    RETURN json_build_object(
        'success', true,
        'geom', ST_AsGeoJSON(v_geom),
        'distancia_m', v_distancia
    );
END;
$$;


ALTER FUNCTION public.registrar_ruta_con_via(id_inicio integer, via_lon double precision, via_lat double precision, id_fin integer) OWNER TO postgres;

--
-- Name: trace_route_approximate(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: admin
--

CREATE FUNCTION public.trace_route_approximate(start_stop_id integer, end_stop_id integer, max_segments integer DEFAULT 50) RETURNS TABLE(segment_order integer, gid integer, nombre_calle text, segment_geom public.geometry, distance_meters double precision)
    LANGUAGE plpgsql
    AS $$
DECLARE
    start_point geometry;
    end_point geometry;
    current_point geometry;
    remaining_segments INTEGER;
    closest_gid INTEGER;
    found_geom geometry;
    current_nombre_calle TEXT;
    total_route_geometry geometry;
    segment_count INTEGER := 0;
    geom_collection geometry[] := '{}';
    visited_gids INTEGER[] := '{}';
    final_distance DOUBLE PRECISION;
BEGIN
    -- Obtener las paradas en EPSG:4326
    SELECT ST_SetSRID(ST_MakePoint(lon, lat), 4326)
    INTO start_point
    FROM public.paradas
    WHERE id = start_stop_id;

    SELECT ST_SetSRID(ST_MakePoint(lon, lat), 4326)
    INTO end_point
    FROM public.paradas
    WHERE id = end_stop_id;

    IF start_point IS NULL OR end_point IS NULL THEN
        RAISE EXCEPTION 'Paradas no válidas (IDs: % → %)', start_stop_id, end_stop_id;
    END IF;

    current_point := start_point;
    remaining_segments := max_segments;
    segment_order := 0;

    WHILE remaining_segments > 0 AND ST_Distance(current_point::geography, end_point::geography) > 50 LOOP
        -- Encontrar la vía más cercana dentro de 300 metros
        SELECT v."GID",
               ST_Transform(v.geom, 4326),
               v."NOM_CALLE"
        INTO closest_gid, found_geom, current_nombre_calle
        FROM public.v_sig_vias v
        WHERE NOT v."GID" = ANY(visited_gids)
          AND ST_DWithin(
                ST_Transform(v.geom, 4326)::geography,
                current_point::geography,
                300
              )
        ORDER BY ST_Distance(
                ST_Transform(v.geom, 4326)::geography,
                current_point::geography
              )
        LIMIT 1;

        IF closest_gid IS NULL THEN
            RAISE NOTICE 'No se encontraron más segmentos de calle cercanos. Ruta incompleta.';
            EXIT;
        END IF;

        visited_gids := array_append(visited_gids, closest_gid);

        current_point := ST_ClosestPoint(found_geom, end_point);
        segment_order := segment_order + 1;
        remaining_segments := remaining_segments - 1;
        segment_count := segment_count + 1;

        geom_collection := array_append(geom_collection, found_geom);

        gid := closest_gid;
        nombre_calle := current_nombre_calle;
        segment_geom := found_geom;
        distance_meters := ST_Length(found_geom::geography);

        RETURN NEXT;
    END LOOP;

    -- Crear geometría final
    IF array_length(geom_collection, 1) > 0 THEN
        SELECT ST_CollectionExtract(ST_Collect(geom_collection), 2)
        INTO total_route_geometry;

        total_route_geometry := ST_SetSRID(ST_Multi(ST_LineMerge(ST_Union(geom_collection))), 4326);

        final_distance := 0;
        FOR i IN 1..array_length(geom_collection, 1) LOOP
            final_distance := final_distance + ST_Length(geom_collection[i]::geography);
        END LOOP;

        INSERT INTO public.rutas_resultado (
            start_stop_id, 
            end_stop_id, 
            route_geom,
            segment_count,
            total_distance,
            created_at
        ) VALUES (
            start_stop_id,
            end_stop_id,
            total_route_geometry,
            segment_count,
            final_distance,
            NOW()
        );
    END IF;

END;
$$;


ALTER FUNCTION public.trace_route_approximate(start_stop_id integer, end_stop_id integer, max_segments integer) OWNER TO admin;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: lineas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.lineas (
    id bigint NOT NULL,
    codigo character varying(255) NOT NULL,
    origen character varying(255) NOT NULL,
    destino character varying(255) NOT NULL,
    empresa character varying(255) NOT NULL,
    geom public.geometry(LineString,32721) NOT NULL
);


ALTER TABLE public.lineas OWNER TO admin;

--
-- Name: lineas_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.lineas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.lineas_id_seq OWNER TO admin;

--
-- Name: lineas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.lineas_id_seq OWNED BY public.lineas.id;


--
-- Name: lineas_raw; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.lineas_raw (
    id integer,
    geom_hex text,
    nombre text,
    tipo text,
    categoria text,
    codigo text,
    identificador text,
    clase text,
    geom public.geometry(MultiLineString,32721)
);


ALTER TABLE public.lineas_raw OWNER TO admin;

--
-- Name: paradas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.paradas (
    id bigint NOT NULL,
    nombre character varying(255),
    lat double precision,
    lon double precision,
    geom public.geometry(Point,4326)
);


ALTER TABLE public.paradas OWNER TO admin;

--
-- Name: paradas_raw; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.paradas_raw (
    id text,
    geom text,
    campo1 text,
    campo2 text,
    campo3 text,
    campo4 text,
    calle text,
    esquina text,
    cod1 text,
    cod2 text,
    x text,
    y text,
    geom_geom public.geometry(Point,4326)
);


ALTER TABLE public.paradas_raw OWNER TO admin;

--
-- Name: paradas_final; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.paradas_final AS
 SELECT id,
    calle,
    esquina,
    geom_geom AS geom
   FROM public.paradas_raw
  WHERE (geom_geom IS NOT NULL);


ALTER VIEW public.paradas_final OWNER TO admin;

--
-- Name: paradas_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.paradas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.paradas_id_seq OWNER TO admin;

--
-- Name: paradas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.paradas_id_seq OWNED BY public.paradas.id;


--
-- Name: paradas_sep; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.paradas_sep (
    id text,
    geom_hex text,
    lon text,
    lat text,
    nombre text,
    direccion text
);


ALTER TABLE public.paradas_sep OWNER TO admin;

--
-- Name: rutas_optimas; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rutas_optimas (
    id integer NOT NULL,
    start_stop_id integer,
    end_stop_id integer,
    route_geom public.geometry(MultiLineString,4326),
    segment_count integer,
    total_distance double precision,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.rutas_optimas OWNER TO admin;

--
-- Name: rutas_optimas_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.rutas_optimas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rutas_optimas_id_seq OWNER TO admin;

--
-- Name: rutas_optimas_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.rutas_optimas_id_seq OWNED BY public.rutas_optimas.id;


--
-- Name: rutas_resultado; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.rutas_resultado (
    id integer NOT NULL,
    start_stop_id integer,
    end_stop_id integer,
    route_geom public.geometry(MultiLineString,4326),
    total_distance double precision,
    created_at timestamp without time zone DEFAULT now()
);


ALTER TABLE public.rutas_resultado OWNER TO admin;

--
-- Name: rutas_resultado_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.rutas_resultado_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.rutas_resultado_id_seq OWNER TO admin;

--
-- Name: rutas_resultado_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.rutas_resultado_id_seq OWNED BY public.rutas_resultado.id;


--
-- Name: temp_paradas_raw; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.temp_paradas_raw (
    linea_texto text
);


ALTER TABLE public.temp_paradas_raw OWNER TO admin;

--
-- Name: v_sig_vias; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.v_sig_vias (
    id integer NOT NULL,
    geom public.geometry(MultiLineString,4326),
    "NOM_CALLE" character varying(36),
    "COD_DEPTO" integer,
    "COD_LOCALI" bigint,
    "GID" numeric,
    "COD_NOMBRE" bigint,
    "TIPO" character varying(30),
    source integer,
    target integer,
    gid_int integer NOT NULL
);


ALTER TABLE public.v_sig_vias OWNER TO admin;

--
-- Name: v_sig_vias_gid_int_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.v_sig_vias_gid_int_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.v_sig_vias_gid_int_seq OWNER TO admin;

--
-- Name: v_sig_vias_gid_int_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.v_sig_vias_gid_int_seq OWNED BY public.v_sig_vias.gid_int;


--
-- Name: v_sig_vias_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.v_sig_vias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.v_sig_vias_id_seq OWNER TO admin;

--
-- Name: v_sig_vias_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.v_sig_vias_id_seq OWNED BY public.v_sig_vias.id;


--
-- Name: v_sig_vias_vertices_pgr; Type: TABLE; Schema: public; Owner: admin
--

CREATE TABLE public.v_sig_vias_vertices_pgr (
    id bigint NOT NULL,
    cnt integer,
    chk integer,
    ein integer,
    eout integer,
    the_geom public.geometry(Point,4326)
);


ALTER TABLE public.v_sig_vias_vertices_pgr OWNER TO admin;

--
-- Name: v_sig_vias_vertices_pgr_id_seq; Type: SEQUENCE; Schema: public; Owner: admin
--

CREATE SEQUENCE public.v_sig_vias_vertices_pgr_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.v_sig_vias_vertices_pgr_id_seq OWNER TO admin;

--
-- Name: v_sig_vias_vertices_pgr_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: admin
--

ALTER SEQUENCE public.v_sig_vias_vertices_pgr_id_seq OWNED BY public.v_sig_vias_vertices_pgr.id;


--
-- Name: vias_nodos; Type: VIEW; Schema: public; Owner: admin
--

CREATE VIEW public.vias_nodos AS
 SELECT pgr_nodenetwork
   FROM public.pgr_nodenetwork('public.v_sig_vias'::text, (0.0001)::double precision) pgr_nodenetwork(pgr_nodenetwork);


ALTER VIEW public.vias_nodos OWNER TO admin;

--
-- Name: lineas id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.lineas ALTER COLUMN id SET DEFAULT nextval('public.lineas_id_seq'::regclass);


--
-- Name: paradas id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.paradas ALTER COLUMN id SET DEFAULT nextval('public.paradas_id_seq'::regclass);


--
-- Name: rutas_optimas id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rutas_optimas ALTER COLUMN id SET DEFAULT nextval('public.rutas_optimas_id_seq'::regclass);


--
-- Name: rutas_resultado id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rutas_resultado ALTER COLUMN id SET DEFAULT nextval('public.rutas_resultado_id_seq'::regclass);


--
-- Name: v_sig_vias id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.v_sig_vias ALTER COLUMN id SET DEFAULT nextval('public.v_sig_vias_id_seq'::regclass);


--
-- Name: v_sig_vias gid_int; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.v_sig_vias ALTER COLUMN gid_int SET DEFAULT nextval('public.v_sig_vias_gid_int_seq'::regclass);


--
-- Name: v_sig_vias_vertices_pgr id; Type: DEFAULT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.v_sig_vias_vertices_pgr ALTER COLUMN id SET DEFAULT nextval('public.v_sig_vias_vertices_pgr_id_seq'::regclass);


--
-- Name: lineas lineas_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.lineas
    ADD CONSTRAINT lineas_pkey PRIMARY KEY (id);


--
-- Name: paradas paradas_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.paradas
    ADD CONSTRAINT paradas_pkey PRIMARY KEY (id);


--
-- Name: rutas_optimas rutas_optimas_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rutas_optimas
    ADD CONSTRAINT rutas_optimas_pkey PRIMARY KEY (id);


--
-- Name: rutas_resultado rutas_resultado_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.rutas_resultado
    ADD CONSTRAINT rutas_resultado_pkey PRIMARY KEY (id);


--
-- Name: v_sig_vias v_sig_vias_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.v_sig_vias
    ADD CONSTRAINT v_sig_vias_pkey PRIMARY KEY (id);


--
-- Name: v_sig_vias_vertices_pgr v_sig_vias_vertices_pgr_pkey; Type: CONSTRAINT; Schema: public; Owner: admin
--

ALTER TABLE ONLY public.v_sig_vias_vertices_pgr
    ADD CONSTRAINT v_sig_vias_vertices_pgr_pkey PRIMARY KEY (id);


--
-- Name: idx_lineas_geom; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_lineas_geom ON public.lineas USING gist (geom);


--
-- Name: idx_paradas_geom; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX idx_paradas_geom ON public.paradas USING gist (geom);


--
-- Name: v_sig_vias_geom_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX v_sig_vias_geom_idx ON public.v_sig_vias USING gist (geom);


--
-- Name: v_sig_vias_gid_int_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX v_sig_vias_gid_int_idx ON public.v_sig_vias USING btree (gid_int);


--
-- Name: v_sig_vias_source_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX v_sig_vias_source_idx ON public.v_sig_vias USING btree (source);


--
-- Name: v_sig_vias_target_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX v_sig_vias_target_idx ON public.v_sig_vias USING btree (target);


--
-- Name: v_sig_vias_vertices_pgr_the_geom_idx; Type: INDEX; Schema: public; Owner: admin
--

CREATE INDEX v_sig_vias_vertices_pgr_the_geom_idx ON public.v_sig_vias_vertices_pgr USING gist (the_geom);


--
-- PostgreSQL database dump complete
--

\unrestrict QUHPpTxLnKaJgxNxnABb3PhDbtJHURd2AWpSTTMroCcRYvaie4eTHEw7T8ckNyJ

