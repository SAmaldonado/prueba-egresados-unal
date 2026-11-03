-- =============================================================================
-- ARCHIVO: database/schema.sql
-- PROYECTO: Sistema de Seguimiento a Egresados - Facultad de Ingeniería
-- MOTOR OBJETIVO: PostgreSQL 14 o superior (No compatible directamente con SQLite)
-- DESCRIPCIÓN: Definición de esquemas, tablas de catálogos, bóveda de identidad
--              restringida, núcleo analítico seudonimizado, restricciones de
--              integridad, índices y vistas analíticas base.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- Configuración de zona horaria estándar para Colombia
SET TIME ZONE 'America/Bogota';

-- Creación de esquemas lógicos separados
CREATE SCHEMA IF NOT EXISTS catalogos;
CREATE SCHEMA IF NOT EXISTS boveda_identidad;
CREATE SCHEMA IF NOT EXISTS nucleo_analitico;

COMMENT ON SCHEMA catalogos IS 'Tablas maestras y catálogos de referencia estandarizados (SNIES, CIIU Rev. 4, CUOC, DIVIPOLA/ISO).';
COMMENT ON SCHEMA boveda_identidad IS 'Esquema de acceso restringido que separa las referencias de identificación institucional del núcleo analítico.';
COMMENT ON SCHEMA nucleo_analitico IS 'Esquema operativo seudonimizado para análisis de trayectorias académicas, laborales y auditoría de calidad.';

-- =============================================================================
-- 1. ESQUEMA DE CATÁLOGOS (catalogos.*)
-- =============================================================================

CREATE TABLE IF NOT EXISTS catalogos.cat_ubicacion (
    ubicacion_id INT PRIMARY KEY,
    codigo_pais_iso CHAR(2) NOT NULL CHECK (codigo_pais_iso ~ '^[A-Z]{2}$'),
    nombre_pais VARCHAR(80) NOT NULL,
    codigo_divipola VARCHAR(10) UNIQUE,
    departamento_estado VARCHAR(80) NOT NULL,
    ciudad_municipio VARCHAR(80) NOT NULL,
    CONSTRAINT chk_divipola_colombia CHECK (
        (codigo_pais_iso = 'CO' AND codigo_divipola IS NOT NULL)
        OR (codigo_pais_iso <> 'CO')
    )
);

CREATE TABLE IF NOT EXISTS catalogos.cat_nivel_academico (
    nivel_id VARCHAR(20) PRIMARY KEY,
    nombre_nivel VARCHAR(60) NOT NULL UNIQUE,
    orden_jerarquico SMALLINT NOT NULL UNIQUE CHECK (orden_jerarquico BETWEEN 1 AND 10)
);

CREATE TABLE IF NOT EXISTS catalogos.cat_programa (
    programa_id INT PRIMARY KEY,
    codigo_snies VARCHAR(15) NOT NULL UNIQUE,
    nombre_programa VARCHAR(120) NOT NULL,
    nivel_academico_id VARCHAR(20) NOT NULL REFERENCES catalogos.cat_nivel_academico(nivel_id),
    departamento_escuela VARCHAR(100) NOT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS catalogos.cat_sector_economico (
    sector_id VARCHAR(10) PRIMARY KEY,
    seccion_ciiu CHAR(1) NOT NULL CHECK (seccion_ciiu ~ '^[A-U]$'),
    division_ciiu CHAR(2) NOT NULL CHECK (division_ciiu ~ '^[0-9]{2}$'),
    nombre_sector VARCHAR(150) NOT NULL,
    UNIQUE (seccion_ciiu, division_ciiu)
);

CREATE TABLE IF NOT EXISTS catalogos.cat_empresa (
    empresa_id INT PRIMARY KEY,
    nombre_canonico VARCHAR(150) NOT NULL UNIQUE,
    sector_economico_id VARCHAR(10) NOT NULL REFERENCES catalogos.cat_sector_economico(sector_id),
    ubicacion_sede_id INT NOT NULL REFERENCES catalogos.cat_ubicacion(ubicacion_id),
    tamano_empresa VARCHAR(50) NOT NULL CHECK (
    tamano_empresa IN ('MICRO_PEQUENA', 'MEDIANA', 'GRAN_EMPRESA', 'INSTITUCION_PUBLICA_ACADEMICA')
    ),
    es_entidad_sintetica BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS catalogos.cat_empresa_alias (
    alias_id INT PRIMARY KEY,
    empresa_id INT NOT NULL REFERENCES catalogos.cat_empresa(empresa_id) ON DELETE CASCADE,
    alias_normalizado VARCHAR(150) NOT NULL UNIQUE
);

CREATE TABLE IF NOT EXISTS catalogos.cat_cargo_nivel (
    cargo_nivel_id VARCHAR(25) PRIMARY KEY,
    nombre_nivel VARCHAR(60) NOT NULL UNIQUE,
    orden_seniority SMALLINT NOT NULL CHECK (orden_seniority BETWEEN 1 AND 10)
);

CREATE TABLE IF NOT EXISTS catalogos.cat_area_desempeno (
    area_id VARCHAR(25) PRIMARY KEY,
    codigo_cuoc_ref VARCHAR(10) NOT NULL,
    nombre_area VARCHAR(100) NOT NULL UNIQUE,
    es_nucleo_ingenieria BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS catalogos.cat_estado_verificacion (
    estado_id VARCHAR(25) PRIMARY KEY,
    descripcion_estado VARCHAR(150) NOT NULL,
    apto_indicadores_oficiales BOOLEAN NOT NULL
);

-- =============================================================================
-- 2. ESQUEMA DE IDENTIDAD RESTRINGIDA (boveda_identidad.*)
-- =============================================================================

CREATE TABLE IF NOT EXISTS boveda_identidad.identidad_restringida (
    id_egresado UUID PRIMARY KEY,
    codigo_acta_hmac CHAR(64) NOT NULL UNIQUE CHECK (codigo_acta_hmac ~ '^[a-f0-9]{64}$'),
    perfil_origen_ref VARCHAR(120) UNIQUE CHECK (
        perfil_origen_ref IS NULL OR perfil_origen_ref ~ '^urn:sintetico:perfil:[a-z0-9-]+$'
    ),
    estado_autorizacion VARCHAR(40) NOT NULL CHECK (
        estado_autorizacion IN (
            'DATO_SINTETICO_DEMO',
            'AUTORIZADO_TITULAR',
            'TRATAMIENTO_ESTADISTICO_ANONIMIZADO',
            'REVOCADO_BLOQUEADO'
        )
    ),
    fecha_registro_boveda TIMESTAMPTZ NOT NULL,
    es_dato_sintetico BOOLEAN NOT NULL DEFAULT TRUE,
    CONSTRAINT chk_coherencia_demo_privacidad CHECK (
        (es_dato_sintetico = TRUE AND estado_autorizacion = 'DATO_SINTETICO_DEMO')
        OR (es_dato_sintetico = FALSE AND estado_autorizacion <> 'DATO_SINTETICO_DEMO')
    )
);

COMMENT ON TABLE boveda_identidad.identidad_restringida IS 'Tabla de custodia restringida. En demostración solo admite registros marcados explícitamente como DATO_SINTETICO_DEMO.';

-- =============================================================================
-- 3. ESQUEMA DE NÚCLEO ANALÍTICO (nucleo_analitico.*)
-- =============================================================================

CREATE TABLE IF NOT EXISTS nucleo_analitico.egresados (
    id_egresado UUID PRIMARY KEY REFERENCES boveda_identidad.identidad_restringida(id_egresado) ON DELETE RESTRICT,
    ubicacion_residencia_id INT REFERENCES catalogos.cat_ubicacion(ubicacion_id),
    estado_verificacion_id VARCHAR(25) NOT NULL REFERENCES catalogos.cat_estado_verificacion(estado_id),
    cohorte_primera_titulacion SMALLINT NOT NULL CHECK (cohorte_primera_titulacion BETWEEN 1960 AND 2030),
    es_registro_sintetico BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE TABLE IF NOT EXISTS nucleo_analitico.perfiles_candidatos (
    candidato_id VARCHAR(30) PRIMARY KEY,
    perfil_origen_ref VARCHAR(120) NOT NULL UNIQUE CHECK (
        perfil_origen_ref ~ '^urn:sintetico:perfil:[a-z0-9-]+$'
    ),
    programa_inferido_id INT REFERENCES catalogos.cat_programa(programa_id),
    anio_grado_inferido SMALLINT CHECK (
        anio_grado_inferido IS NULL OR anio_grado_inferido BETWEEN 1960 AND 2030
    ),
    senales_coincidentes VARCHAR(50) NOT NULL CHECK (
        senales_coincidentes IN (
            'S1+S2+S3+S4',
            'S1+S2+S3_SIN_S4',
            'S1+S2+S3_SIN_S4_HOMONIMO',
            'S1+S2_PARCIAL'
        )
    ),
    conteo_homonimos_acta SMALLINT NOT NULL CHECK (conteo_homonimos_acta >= 0),
    estado_candidato VARCHAR(35) NOT NULL CHECK (
        estado_candidato IN (
            'VINCULADO_CONFIRMADO',
            'CUARENTENA_HOMONIMIA',
            'CUARENTENA_DATOS_INSUFICIENTES',
            'DESCARTADO_NO_EGRESADO'
        )
    ),
    id_egresado_confirmado UUID UNIQUE REFERENCES nucleo_analitico.egresados(id_egresado) ON DELETE RESTRICT,
    fecha_evaluacion TIMESTAMPTZ NOT NULL,
    observacion_resolucion TEXT NOT NULL,
    -- Regla crítica: Un candidato en cuarentena o descartado NO puede tener id_egresado_confirmado
    CONSTRAINT chk_aislamiento_cuarentena CHECK (
        (estado_candidato = 'VINCULADO_CONFIRMADO' AND id_egresado_confirmado IS NOT NULL)
        OR (estado_candidato <> 'VINCULADO_CONFIRMADO' AND id_egresado_confirmado IS NULL)
    ),
    -- Si hay colisión de homónimos sin señal de desempate, no puede marcarse como confirmado sin resolver
    CONSTRAINT chk_homonimia_exige_alerta CHECK (
        NOT (senales_coincidentes = 'S1+S2+S3_SIN_S4_HOMONIMO' AND estado_candidato = 'VINCULADO_CONFIRMADO')
    )
);

CREATE TABLE IF NOT EXISTS nucleo_analitico.formacion_academica (
    id_formacion INT PRIMARY KEY,
    id_egresado UUID NOT NULL REFERENCES nucleo_analitico.egresados(id_egresado) ON DELETE RESTRICT,
    programa_id INT NOT NULL REFERENCES catalogos.cat_programa(programa_id),
    nivel_academico_id VARCHAR(20) NOT NULL REFERENCES catalogos.cat_nivel_academico(nivel_id),
    anio_grado SMALLINT NOT NULL CHECK (anio_grado BETWEEN 1960 AND 2030),
    verificado_acta_facultad BOOLEAN NOT NULL,
    CONSTRAINT uq_egresado_programa_anio UNIQUE (id_egresado, programa_id, anio_grado)
);

CREATE TABLE IF NOT EXISTS nucleo_analitico.experiencia_laboral (
    id_experiencia INT PRIMARY KEY,
    id_egresado UUID NOT NULL REFERENCES nucleo_analitico.egresados(id_egresado) ON DELETE RESTRICT,
    empresa_id INT REFERENCES catalogos.cat_empresa(empresa_id),
    empresa_texto_original VARCHAR(150) NOT NULL CHECK (char_length(btrim(empresa_texto_original)) >= 2),
    sector_economico_id VARCHAR(10) REFERENCES catalogos.cat_sector_economico(sector_id),
    cargo_original VARCHAR(150) NOT NULL CHECK (char_length(btrim(cargo_original)) >= 2),
    cargo_nivel_id VARCHAR(25) REFERENCES catalogos.cat_cargo_nivel(cargo_nivel_id),
    area_desempeno_id VARCHAR(25) REFERENCES catalogos.cat_area_desempeno(area_id),
    estado_homologacion VARCHAR(30) NOT NULL CHECK (
        estado_homologacion IN (
            'HOMOLOGADO',
            'PENDIENTE_HOMOLOGACION',
            'NO_VERIFICABLE',
            'NO_DECLARADO'
        )
    ),
    tipo_vinculacion_rol VARCHAR(30) NOT NULL CHECK (
        tipo_vinculacion_rol IN (
            'ROL_PRINCIPAL',
            'DOCENCIA_CATEDRA',
            'CONSULTORIA_PARALELA',
            'PRACTICA_ACADEMICA'
        )
    ),
    modalidad_trabajo VARCHAR(20) NOT NULL CHECK (
        modalidad_trabajo IN ('PRESENCIAL', 'REMOTO', 'HIBRIDO', 'NO_DECLARADO')
    ),
    ubicacion_empleo_id INT REFERENCES catalogos.cat_ubicacion(ubicacion_id),
    fecha_inicio DATE,
    fecha_fin DATE,
    precision_fecha VARCHAR(20) NOT NULL CHECK (
        precision_fecha IN ('EXACTA_MENSUAL', 'ANUAL', 'SIN_FECHA')
    ),
    es_actual BOOLEAN NOT NULL,
    -- Regla 1: Coherencia cronológica entre inicio y fin
    CONSTRAINT chk_fechas_coherentes CHECK (
        fecha_fin IS NULL OR (fecha_inicio IS NOT NULL AND fecha_fin >= fecha_inicio)
    ),
    -- Regla 2: Un empleo vigente no puede tener fecha de finalización cerrada
    CONSTRAINT chk_empleo_actual_abierto CHECK (
        (es_actual = TRUE AND fecha_fin IS NULL) OR (es_actual = FALSE)
    ),
    -- Regla 3: Coherencia entre precisión declarada y formato de fecha almacenada
    CONSTRAINT chk_precision_fecha_consistente CHECK (
        (precision_fecha = 'SIN_FECHA' AND fecha_inicio IS NULL AND fecha_fin IS NULL)
        OR (precision_fecha = 'ANUAL' AND fecha_inicio IS NOT NULL AND EXTRACT(MONTH FROM fecha_inicio) = 1 AND EXTRACT(DAY FROM fecha_inicio) = 1)
        OR (precision_fecha = 'EXACTA_MENSUAL' AND fecha_inicio IS NOT NULL AND EXTRACT(DAY FROM fecha_inicio) = 1)
    ),
    -- Regla 4: Coherencia entre estado_homologacion y nulabilidad de clasificadores
    CONSTRAINT chk_homologacion_consistente CHECK (
        (estado_homologacion = 'HOMOLOGADO' AND cargo_nivel_id IS NOT NULL AND area_desempeno_id IS NOT NULL)
        OR (estado_homologacion <> 'HOMOLOGADO' AND (cargo_nivel_id IS NULL OR area_desempeno_id IS NULL))
    ),
    -- Regla 5: Prevención de duplicados exactos de experiencia laboral
    CONSTRAINT uq_experiencia_no_duplicada UNIQUE (id_egresado, empresa_texto_original, cargo_original, fecha_inicio)
);

CREATE TABLE IF NOT EXISTS nucleo_analitico.auditoria_trazabilidad (
    id_auditoria INT PRIMARY KEY,
    id_egresado UUID NOT NULL REFERENCES nucleo_analitico.egresados(id_egresado) ON DELETE RESTRICT,
    fuente_primaria VARCHAR(40) NOT NULL CHECK (
        fuente_primaria IN (
            'AUTOGESTION_EGRESADO',
            'VERIFICACION_ASISTIDA_LINKEDIN',
            'CRUCE_INSTITUCIONAL_OLE'
        )
    ),
    fecha_captura TIMESTAMPTZ NOT NULL,
    nivel_confianza VARCHAR(15) NOT NULL CHECK (
        nivel_confianza IN ('ALTO', 'MEDIO', 'BAJO')
    ),
    estado_completitud VARCHAR(35) NOT NULL CHECK (
        estado_completitud IN (
            'COMPLETO',
            'PARCIAL_FECHAS_APROXIMADAS',
            'PARCIAL_HOMOLOGACION_PENDIENTE',
            'INCOMPLETO_REVISAR'
        )
    ),
    rol_verificador VARCHAR(40) NOT NULL,
    observacion_auditoria TEXT NOT NULL
);

-- =============================================================================
-- 4. ÍNDICES DE RENDIMIENTO Y BÚSQUEDA ANALÍTICA
-- =============================================================================

CREATE INDEX IF NOT EXISTS idx_formacion_egresado ON nucleo_analitico.formacion_academica(id_egresado);
CREATE INDEX IF NOT EXISTS idx_formacion_programa ON nucleo_analitico.formacion_academica(programa_id);
CREATE INDEX IF NOT EXISTS idx_experiencia_egresado ON nucleo_analitico.experiencia_laboral(id_egresado);
CREATE INDEX IF NOT EXISTS idx_experiencia_actual ON nucleo_analitico.experiencia_laboral(es_actual) WHERE es_actual = TRUE;
CREATE INDEX IF NOT EXISTS idx_experiencia_sector ON nucleo_analitico.experiencia_laboral(sector_economico_id);
CREATE INDEX IF NOT EXISTS idx_auditoria_egresado_fecha ON nucleo_analitico.auditoria_trazabilidad(id_egresado, fecha_captura DESC);
CREATE INDEX IF NOT EXISTS idx_candidatos_estado ON nucleo_analitico.perfiles_candidatos(estado_candidato);

COMMIT;