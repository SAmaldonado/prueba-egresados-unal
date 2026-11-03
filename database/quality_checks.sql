-- =============================================================================
-- ARCHIVO: database/quality_checks.sql
-- DESCRIPCIÓN: Vistas analíticas seguras y motor de reglas de control de calidad
--              que distingue entre:
--              1. Errores bloqueantes (impedidos en inserción por CHECK/FK/UNIQUE)
--              2. Exclusiones preventivas de cuarentena (Caso 7)
--              3. Advertencias que requieren revisión humana (Casos 4 y 8)
--              4. Información incompleta legítima conservada con bandera (Caso 3)
--              5. Situaciones válidas controladas que NO son errores (Casos 2, 5 y 6)
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- =============================================================================
-- SECCIÓN A: VISTAS OPERATIVAS QUE PROTEGEN INDICADORES CONTRA CONTAMINACIÓN
-- =============================================================================

-- Vista 1: Población confirmada apta para indicadores institucionales
-- Excluye automáticamente perfiles en cuarentena (Caso 7) y registros con autorización revocada.
CREATE OR REPLACE VIEW nucleo_analitico.vw_egresados_confirmados_indicadores AS
SELECT
    e.id_egresado,
    e.cohorte_primera_titulacion,
    e.estado_verificacion_id,
    u_res.ciudad_municipio AS ciudad_residencia,
    u_res.nombre_pais AS pais_residencia,
    a.nivel_confianza,
    a.fecha_captura,
    (DATE '2026-11-02' - a.fecha_captura::DATE) AS dias_desde_ultima_captura
FROM nucleo_analitico.egresados e
JOIN catalogos.cat_estado_verificacion ev
    ON e.estado_verificacion_id = ev.estado_id
JOIN nucleo_analitico.auditoria_trazabilidad a
    ON e.id_egresado = a.id_egresado
LEFT JOIN catalogos.cat_ubicacion u_res
    ON e.ubicacion_residencia_id = u_res.ubicacion_id
WHERE ev.apto_indicadores_oficiales = TRUE;

-- Vista 2: Cálculo seguro de duración laboral y movilidad internacional
-- Evita que fechas anuales aproximadas (Caso 3) distorsionen promedios de duración en meses.
CREATE OR REPLACE VIEW nucleo_analitico.vw_experiencias_analitica AS
SELECT
    ex.id_experiencia,
    ex.id_egresado,
    ex.cargo_original,
    ex.cargo_nivel_id,
    ex.area_desempeno_id,
    ca.es_nucleo_ingenieria,
    ex.sector_economico_id,
    ex.tipo_vinculacion_rol,
    ex.modalidad_trabajo,
    u_res.codigo_pais_iso AS pais_residencia_egresado,
    u_emp.codigo_pais_iso AS pais_puesto_trabajo,
    u_sede.codigo_pais_iso AS pais_sede_empresa,
    CASE
        WHEN u_res.codigo_pais_iso = 'CO' AND u_sede.codigo_pais_iso <> 'CO' AND ex.modalidad_trabajo = 'REMOTO'
            THEN 'EXPORTACION_SERVICIOS_REMOTO'
        WHEN u_res.codigo_pais_iso <> 'CO'
            THEN 'EMIGRACION_FISICA_EXTERIOR'
        ELSE 'MERCADO_NACIONAL_LOCAL'
    END AS clasificacion_movilidad,
    ex.fecha_inicio,
    ex.fecha_fin,
    ex.precision_fecha,
    ex.es_actual,
    -- Solo calcula meses exactos si precision_fecha = 'EXACTA_MENSUAL'
    CASE
        WHEN ex.precision_fecha = 'EXACTA_MENSUAL' AND ex.fecha_inicio IS NOT NULL THEN
            (EXTRACT(YEAR FROM age(COALESCE(ex.fecha_fin, DATE '2026-11-02'), ex.fecha_inicio))::INT * 12) +
            EXTRACT(MONTH FROM age(COALESCE(ex.fecha_fin, DATE '2026-11-02'), ex.fecha_inicio))::INT
        ELSE NULL
    END AS meses_duracion_verificados
FROM nucleo_analitico.experiencia_laboral ex
JOIN nucleo_analitico.egresados e
    ON ex.id_egresado = e.id_egresado
LEFT JOIN catalogos.cat_area_desempeno ca
    ON ex.area_desempeno_id = ca.area_id
LEFT JOIN catalogos.cat_empresa emp
    ON ex.empresa_id = emp.empresa_id
LEFT JOIN catalogos.cat_ubicacion u_res
    ON e.ubicacion_residencia_id = u_res.ubicacion_id
LEFT JOIN catalogos.cat_ubicacion u_emp
    ON ex.ubicacion_empleo_id = u_emp.ubicacion_id
LEFT JOIN catalogos.cat_ubicacion u_sede
    ON emp.ubicacion_sede_id = u_sede.ubicacion_id;

-- =============================================================================
-- SECCIÓN B: VISTA CONSOLIDADA DE AUDITORÍA DE CALIDAD DE DATOS
-- =============================================================================

CREATE OR REPLACE VIEW nucleo_analitico.vw_reporte_calidad_datos AS

-- REGLA QC-01: Perfiles candidatos en cuarentena por homonimia o datos insuficientes (Detecta Caso 7)
SELECT
    'QC-01_CUARENTENA_IDENTIDAD'::VARCHAR(40) AS codigo_regla,
    'EXCLUSION_PREVENTIVA'::VARCHAR(35) AS categoria_severidad,
    'nucleo_analitico.perfiles_candidatos'::VARCHAR(45) AS tabla_origen,
    pc.candidato_id::VARCHAR(40) AS id_registro,
    pc.observacion_resolucion AS detalle_hallazgo,
    'Mantener fuera de nucleo_analitico.egresados hasta verificar segunda señal (tesis/correo/COPNIA).'::TEXT AS accion_recomendada
FROM nucleo_analitico.perfiles_candidatos pc
WHERE pc.estado_candidato IN ('CUARENTENA_HOMONIMIA', 'CUARENTENA_DATOS_INSUFICIENTES')

UNION ALL

-- REGLA QC-02: Experiencias con fechas de precisión anual o sin fecha (Detecta Caso 3)
SELECT
    'QC-02_FECHA_PRECISION_LIMITADA',
    'INCOMPLETITUD_CONSERVADA',
    'nucleo_analitico.experiencia_laboral',
    ex.id_experiencia::VARCHAR(40),
    format('Egresado %s | Cargo "%s" tiene precision_fecha = %s (inicio: %s).',
           ex.id_egresado, ex.cargo_original, ex.precision_fecha, COALESCE(ex.fecha_inicio::TEXT, 'NULL')),
    'Conservar registro para conteos sectoriales; excluir de cálculos de duración exacta en meses.'
FROM nucleo_analitico.experiencia_laboral ex
WHERE ex.precision_fecha IN ('ANUAL', 'SIN_FECHA')

UNION ALL

-- REGLA QC-03: Experiencias con cargo o área pendiente de homologación (Detecta Caso 4)
SELECT
    'QC-03_HOMOLOGACION_PENDIENTE',
    'ADVERTENCIA_REVISION_HUMANA',
    'nucleo_analitico.experiencia_laboral',
    ex.id_experiencia::VARCHAR(40),
    format('Egresado %s | Cargo original "%s" en estado %s (nivel=%s, area=%s).',
           ex.id_egresado, ex.cargo_original, ex.estado_homologacion,
           COALESCE(ex.cargo_nivel_id, 'NULL'), COALESCE(ex.area_desempeno_id, 'NULL')),
    'Asignar cargo_nivel_id y area_desempeno_id mediante revisión de funciones por comité curricular.'
FROM nucleo_analitico.experiencia_laboral ex
WHERE ex.estado_homologacion = 'PENDIENTE_HOMOLOGACION'
   OR ex.cargo_nivel_id IS NULL
   OR ex.area_desempeno_id IS NULL

UNION ALL

-- REGLA QC-04: Registros desactualizados o con permanencia atípica en rol de práctica (Detecta Caso 8)
SELECT
    'QC-04_OBSOLESCENCIA_CRONOLOGICA',
    'ADVERTENCIA_REVISION_HUMANA',
    'nucleo_analitico.auditoria_trazabilidad',
    a.id_egresado::VARCHAR(40),
    format('Última captura hace %s días (%s). Estado verificación: %s.',
           (DATE '2026-11-02' - a.fecha_captura::DATE), a.fecha_captura::DATE, e.estado_verificacion_id),
    'Priorizar en el siguiente lote de actualización semestral y excluir de indicadores de coyuntura actual.'
FROM nucleo_analitico.auditoria_trazabilidad a
JOIN nucleo_analitico.egresados e ON a.id_egresado = e.id_egresado
WHERE a.fecha_captura < (TIMESTAMPTZ '2026-11-02 00:00:00-05' - INTERVAL '18 months')
   OR EXISTS (
       SELECT 1
       FROM nucleo_analitico.experiencia_laboral ex
       WHERE ex.id_egresado = a.id_egresado
         AND ex.es_actual = TRUE
         AND ex.cargo_nivel_id = 'PRACTICANTE'
         AND ex.fecha_inicio < (DATE '2026-11-02' - INTERVAL '24 months')
   )

UNION ALL

-- REGLA QC-05: Detección de posibles empleos simultáneos anómalos (>1 ROL_PRINCIPAL actual)
-- NO marca como error el Caso 5 (1 ROL_PRINCIPAL + 1 DOCENCIA_CATEDRA).
SELECT
    'QC-05_COLISION_ROLES_PRINCIPALES',
    'ADVERTENCIA_REVISION_HUMANA',
    'nucleo_analitico.experiencia_laboral',
    ex.id_egresado::VARCHAR(40),
    format('El egresado registra %s cargos con tipo_vinculacion_rol = ROL_PRINCIPAL marcados como actuales simultáneamente.',
           COUNT(*)),
    'Verificar si olvidó cerrar la fecha_fin de un empleo anterior.'
FROM nucleo_analitico.experiencia_laboral ex
WHERE ex.es_actual = TRUE
  AND ex.tipo_vinculacion_rol = 'ROL_PRINCIPAL'
GROUP BY ex.id_egresado
HAVING COUNT(*) > 1

UNION ALL

-- REGLA QC-06: Verificación positiva de pluriempleo legítimo (Valida Caso 5 sin falso positivo)
SELECT
    'QC-06_PLURIEMPLEO_LEGITIMO_VALIDADO',
    'SITUACION_VALIDA_CONTROLADA',
    'nucleo_analitico.experiencia_laboral',
    ex.id_egresado::VARCHAR(40),
    format('Egresado con %s empleos actuales compatibles (%s).',
           COUNT(*), string_agg(ex.tipo_vinculacion_rol || ': ' || ex.cargo_original, ' + ' ORDER BY ex.id_experiencia)),
    'Ninguna corrección requerida; conservar ambas experiencias activas.'
FROM nucleo_analitico.experiencia_laboral ex
WHERE ex.es_actual = TRUE
GROUP BY ex.id_egresado
HAVING COUNT(*) > 1
   AND SUM(CASE WHEN ex.tipo_vinculacion_rol = 'ROL_PRINCIPAL' THEN 1 ELSE 0 END) <= 1;

COMMIT;

-- =============================================================================
-- SECCIÓN C: EJECUCIÓN DEL REPORTE DE CONTROL DE CALIDAD EN CONSOLA
-- =============================================================================

SELECT
    codigo_regla,
    categoria_severidad,
    tabla_origen,
    id_registro,
    detalle_hallazgo
FROM nucleo_analitico.vw_reporte_calidad_datos
ORDER BY codigo_regla, id_registro;