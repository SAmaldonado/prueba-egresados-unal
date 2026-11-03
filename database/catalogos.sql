-- =============================================================================
-- ARCHIVO: database/catalogos.sql
-- DESCRIPCIÓN: Carga de subconjunto demostrativo de catálogos normalizados.
--              Documenta explícitamente códigos oficiales verificados (SNIES,
--              DANE DIVIPOLA, ISO 3166-1, CIIU Rev. 4 A.C., CUOC) y entidades
--              empleadoras sintéticas para la demostración.
-- =============================================================================

\set ON_ERROR_STOP on

BEGIN;

-- 1. Catálogo de Ubicaciones Geográficas
-- Códigos oficiales verificados: DANE DIVIPOLA (5 dígitos para municipios de Colombia) e ISO 3166-1 alpha-2.
INSERT INTO catalogos.cat_ubicacion (ubicacion_id, codigo_pais_iso, nombre_pais, codigo_divipola, departamento_estado, ciudad_municipio) VALUES
    (11001, 'CO', 'Colombia', '11001', 'Bogotá, D.C.', 'Bogotá, D.C.'),
    (5001,  'CO', 'Colombia', '05001', 'Antioquia', 'Medellín'),
    (76001, 'CO', 'Colombia', '76001', 'Valle del Cauca', 'Cali'),
    (84001, 'US', 'Estados Unidos', NULL, 'Texas', 'Austin'),
    (27601, 'DE', 'Alemania', NULL, 'Berlín', 'Berlín')
ON CONFLICT (ubicacion_id) DO NOTHING;

-- 2. Catálogo de Niveles Académicos (Nomenclatura Ministerio de Educación Nacional)
INSERT INTO catalogos.cat_nivel_academico (nivel_id, nombre_nivel, orden_jerarquico) VALUES
    ('PREGRADO', 'Pregrado Universitario', 1),
    ('ESPECIALIZACION', 'Especialización Universitaria', 2),
    ('MAESTRIA', 'Maestría', 3),
    ('DOCTORADO', 'Doctorado', 4)
ON CONFLICT (nivel_id) DO NOTHING;

-- 3. Catálogo de Programas Curriculares (Facultad de Ingeniería - UNAL Sede Bogotá)
-- Códigos SNIES oficiales verificados ante el Ministerio de Educación Nacional para la UNAL Bogotá.
INSERT INTO catalogos.cat_programa (programa_id, codigo_snies, nombre_programa, nivel_academico_id, departamento_escuela, activo) VALUES
    (2541, '12',    'Ingeniería Agrícola', 'PREGRADO', 'Departamento de Ingeniería Civil y Agrícola', TRUE),
    (2542, '13',    'Ingeniería Civil', 'PREGRADO', 'Departamento de Ingeniería Civil y Agrícola', TRUE),
    (2544, '15',    'Ingeniería Eléctrica', 'PREGRADO', 'Departamento de Ingeniería Eléctrica y Electrónica', TRUE),
    (2545, '16',    'Ingeniería Electrónica', 'PREGRADO', 'Departamento de Ingeniería Eléctrica y Electrónica', TRUE),
    (2546, '17',    'Ingeniería Industrial', 'PREGRADO', 'Departamento de Ingeniería de Sistemas e Industrial', TRUE),
    (2547, '18',    'Ingeniería Mecánica', 'PREGRADO', 'Departamento de Ingeniería Mecánica y Mecatrónica', TRUE),
    (2548, '19',    'Ingeniería Química', 'PREGRADO', 'Departamento de Ingeniería Química y Ambiental', TRUE),
    (2879, '20',    'Ingeniería de Sistemas y Computación', 'PREGRADO', 'Departamento de Ingeniería de Sistemas e Industrial', TRUE),
    (2880, '16927', 'Maestría en Ingeniería - Sistemas y Computación', 'MAESTRIA', 'Departamento de Ingeniería de Sistemas e Industrial', TRUE)
ON CONFLICT (programa_id) DO NOTHING;

-- 4. Catálogo de Sectores Económicos (Nomenclatura oficial DANE CIIU Rev. 4 A.C.)
INSERT INTO catalogos.cat_sector_economico (sector_id, seccion_ciiu, division_ciiu, nombre_sector) VALUES
    ('A01', 'A', '01', 'Agricultura, ganadería, caza y actividades de servicios conexas'),
    ('C28', 'C', '28', 'Fabricación de maquinaria y equipo n.c.p.'),
    ('F42', 'F', '42', 'Obras de ingeniería civil'),
    ('G47', 'G', '47', 'Comercio al por menor (incluso el comercio al por menor de combustibles)'),
    ('J62', 'J', '62', 'Desarrollo de sistemas informáticos (planificación, análisis, diseño, programación, pruebas)'),
    ('K64', 'K', '64', 'Actividades de servicios financieros, excepto las de seguros y de pensiones'),
    ('P85', 'P', '85', 'Educación (Educación superior y formación académica)')
ON CONFLICT (sector_id) DO NOTHING;

-- 5. Catálogo de Empresas Empleadoras (100% Sintéticas para proteger privacidad y evitar asociación individual)
INSERT INTO catalogos.cat_empresa (empresa_id, nombre_canonico, sector_economico_id, ubicacion_sede_id, tamano_empresa, es_entidad_sintetica) VALUES
    (10, 'ANDES DATA LABS S.A.S. [SINTETICA]', 'J62', 11001, 'GRAN_EMPRESA', TRUE),
    (20, 'NORTHSTAR CLOUD SYSTEMS INC. [SINTETICA]', 'J62', 84001, 'GRAN_EMPRESA', TRUE),
    (30, 'CONSORCIO VIAL CORDILLERA S.A. [SINTETICA]', 'F42', 5001, 'GRAN_EMPRESA', TRUE),
    (40, 'NEOPAGO FINTECH COLOMBIA S.A.S. [SINTETICA]', 'K64', 11001, 'MEDIANA', TRUE),
    (50, 'METALMECANICA DEL ORIENTE S.A. [SINTETICA]', 'C28', 11001, 'GRAN_EMPRESA', TRUE),
    (60, 'INSTITUTO POLITECNICO METROPOLITANO [SINTETICA]', 'P85', 11001, 'INSTITUCION_PUBLICA_ACADEMICA', TRUE),
    (70, 'SUPERMERCADOS SURTIDORA DEL VALLE S.A.S. [SINTETICA]', 'G47', 76001, 'GRAN_EMPRESA', TRUE),
    (80, 'AGROTECNIA SABANA LTDA. [SINTETICA]', 'A01', 11001, 'MICRO_PEQUENA', TRUE)
ON CONFLICT (empresa_id) DO NOTHING;

-- 6. Catálogo de Alias de Empresas (Demuestra resolución de variantes de escritura en LinkedIn)
INSERT INTO catalogos.cat_empresa_alias (alias_id, empresa_id, alias_normalizado) VALUES
    (1, 10, 'ANDES DATA LABS'),
    (2, 10, 'ANDES DATALABS SAS'),
    (3, 20, 'NORTHSTAR CLOUD SYSTEMS'),
    (4, 30, 'CONSORCIO VIAL CORDILLERA'),
    (5, 40, 'NEOPAGO FINTECH'),
    (6, 50, 'METALMECANICA DEL ORIENTE')
ON CONFLICT (alias_id) DO NOTHING;

-- 7. Catálogo de Niveles Jerárquicos de Cargo (Taxonomía interna de evolución profesional)
INSERT INTO catalogos.cat_cargo_nivel (cargo_nivel_id, nombre_nivel, orden_seniority) VALUES
    ('PRACTICANTE', 'Practicante / Pasante Universitario', 1),
    ('JUNIOR', 'Ingeniero / Analista Junior (0-2 años)', 2),
    ('MID', 'Ingeniero / Especialista Intermedio (2-5 años)', 3),
    ('SENIOR', 'Ingeniero Senior / Arquitecto Técnico (>5 años)', 4),
    ('LIDER_GERENTE', 'Líder Técnico / Coordinador / Gerente de Área', 5),
    ('DIRECTIVO', 'Director / VP / C-Level', 6),
    ('DOCENTE_INVESTIGADOR', 'Docente Universitario / Investigador Académico', 7)
ON CONFLICT (cargo_nivel_id) DO NOTHING;

-- 8. Catálogo de Áreas de Desempeño Funcional (Referencia grupos primarios CUOC DANE / CIUO-08)
INSERT INTO catalogos.cat_area_desempeno (area_id, codigo_cuoc_ref, nombre_area, es_nucleo_ingenieria) VALUES
    ('DESARROLLO_SW', '2512', 'Desarrollo e Ingeniería de Software', TRUE),
    ('DATOS_IA', '2511', 'Arquitectura de Datos, Analítica e Inteligencia Artificial', TRUE),
    ('INFRA_CLOUD', '2523', 'Infraestructura Tecnológica, Redes y Computación en la Nube', TRUE),
    ('OBRAS_INTERVENTORIA', '2142', 'Diseño Estructural, Construcción e Interventoría de Obras Civiles', TRUE),
    ('OPERACIONES_MANT', '2144', 'Operaciones Industriales, Manufactura y Mantenimiento Mecánico', TRUE),
    ('RECURSOS_HIDRICOS', '2141', 'Ingeniería Agrícola, Riego y Gestión de Recursos Hídricos', TRUE),
    ('DOCENCIA_I_D', '2310', 'Docencia en Educación Superior e Investigación Aplicada', TRUE),
    ('COMERCIAL_VENTAS', '2431', 'Gestión Comercial, Ventas B2B/Retail y Mercadeo', FALSE)
ON CONFLICT (area_id) DO NOTHING;

-- 9. Catálogo de Estados de Verificación del Egresado
INSERT INTO catalogos.cat_estado_verificacion (estado_id, descripcion_estado, apto_indicadores_oficiales) VALUES
    ('VERIFICADO_ALTA', 'Identidad confirmada con señales S1+S2+S3+S4 y acta de grado.', TRUE),
    ('VERIFICADO_MEDIA', 'Identidad confirmada con S1+S2+S3 sin colisión de homonimia.', TRUE),
    ('OBSERVACION_OBSOLETO', 'Identidad confirmada pero con captura vencida (>18 meses sin actualizar).', TRUE),
    ('SUSPENDIDO_REVOCADO', 'Titular revocó autorización; excluido de procesamiento analítico.', FALSE)
ON CONFLICT (estado_id) DO NOTHING;

COMMIT;