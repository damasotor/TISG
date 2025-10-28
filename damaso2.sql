-- ===========================================
-- VERIFICACIÓN DE EXISTENCIA DE TABLAS CLAVE
-- ===========================================

-- 1. Verificar tabla de paradas (v_uptu_paradas)
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'v_uptu_paradas')
        THEN '✅ La tabla public.v_uptu_paradas existe.'
        ELSE '❌ La tabla public.v_uptu_paradas NO existe.'
    END AS estado_paradas;

-- 2. Verificar tabla de vías (v_sig_vias.shp)
SELECT
    CASE
        WHEN EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'v_sig_vias.shp')
        THEN '✅ La tabla public."v_sig_vias.shp" existe.'
        ELSE '❌ La tabla public."v_sig_vias.shp" NO existe.'
    END AS estado_vias;

-- ===========================================
-- CONTEO DE REGISTROS (solo si la tabla existe)
-- ===========================================

-- 3. Contar registros en v_uptu_paradas
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'v_uptu_paradas') THEN
        RAISE NOTICE 'Total de registros en v_uptu_paradas: %', (SELECT COUNT(*) FROM public.v_uptu_paradas);
    ELSE
        RAISE NOTICE 'No se puede contar: public.v_uptu_paradas no existe.';
    END IF;
END $$;

-- 4. Contar registros en v_sig_vias.shp
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'v_sig_vias.shp') THEN
        RAISE NOTICE 'Total de registros en v_sig_vias.shp: %', (SELECT COUNT(*) FROM public."v_sig_vias.shp");
    ELSE
        RAISE NOTICE 'No se puede contar: public."v_sig_vias.shp" no existe.';
    END IF;
END $$;

