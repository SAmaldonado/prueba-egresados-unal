-- =============================================================================
-- ARCHIVO: database/load_mock_data.sql
-- DESCRIPCIÓN: Carga transaccional de los archivos CSV canónicos desde el
--              directorio raíz del proyecto utilizando el metacomando \copy
--              del cliente oficial psql.
-- REQUISITO: Ejecutar desde la carpeta raíz `seguimiento-egresados-linkedin/`
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Limpieza controlada en orden inverso de dependencias por si se re-ejecuta la prueba
TRUNCATE TABLE
    nucleo_analitico.auditoria_trazabilidad,
    nucleo_analitico.experiencia_laboral,
    nucleo_analitico.formacion_academica,
    nucleo_analitico.perfiles_candidatos,
    nucleo_analitico.egresados,
    boveda_identidad.identidad_restringida
RESTART IDENTITY;

-- 1. Carga de Bóveda de Identidad Restringida (Casos 1, 2, 3, 4, 5, 6 y 8)
\copy boveda_identidad.identidad_restringida (id_egresado, codigo_acta_hmac, perfil_origen_ref, estado_autorizacion, fecha_registro_boveda, es_dato_sintetico) FROM 'mock_data/identidad_restringida_ficticia.csv' WITH (FORMAT csv, HEADER true, NULL '', ENCODING 'UTF8');

-- 2. Carga de Egresados Confirmados
\copy nucleo_analitico.egresados (id_egresado, ubicacion_residencia_id, estado_verificacion_id, cohorte_primera_titulacion, es_registro_sintetico) FROM 'mock_data/egresados.csv' WITH (FORMAT csv, HEADER true, NULL '', ENCODING 'UTF8');

-- 3. Carga de Perfiles Candidatos (Incluye Caso 7 retenido en CUARENTENA_HOMONIMIA sin id_egresado_confirmado)
\copy nucleo_analitico.perfiles_candidatos (candidato_id, perfil_origen_ref, programa_inferido_id, anio_grado_inferido, senales_coincidentes, conteo_homonimos_acta, estado_candidato, id_egresado_confirmado, fecha_evaluacion, observacion_resolucion) FROM 'mock_data/perfiles_candidatos.csv' WITH (FORMAT csv, HEADER true, NULL '', ENCODING 'UTF8');

-- 4. Carga de Formación Académica (Relación 1:N con Egresados Confirmados)
\copy nucleo_analitico.formacion_academica (id_formacion, id_egresado, programa_id, nivel_academico_id, anio_grado, verificado_acta_facultad) FROM 'mock_data/formacion_academica.csv' WITH (FORMAT csv, HEADER true, NULL '', ENCODING 'UTF8');

-- 5. Carga de Experiencia Laboral (Relación 1:N con Egresados Confirmados)
\copy nucleo_analitico.experiencia_laboral (id_experiencia, id_egresado, empresa_id, empresa_texto_original, sector_economico_id, cargo_original, cargo_nivel_id, area_desempeno_id, estado_homologacion, tipo_vinculacion_rol, modalidad_trabajo, ubicacion_empleo_id, fecha_inicio, fecha_fin, precision_fecha, es_actual) FROM 'mock_data/experiencia_laboral.csv' WITH (FORMAT csv, HEADER true, NULL '', ENCODING 'UTF8');

-- 6. Carga de Auditoría y Trazabilidad
\copy nucleo_analitico.auditoria_trazabilidad (id_auditoria, id_egresado, fuente_primaria, fecha_captura, nivel_confianza, estado_completitud, rol_verificador, observacion_auditoria) FROM 'mock_data/auditoria_trazabilidad.csv' WITH (FORMAT csv, HEADER true, NULL '', ENCODING 'UTF8');

COMMIT;