# Diccionario de Datos, Arquitectura Relacional y Catálogos de Estandarización

**Motor de Base de Datos:** PostgreSQL 14+ (Codificación `UTF8`, Zona Horaria `America/Bogota`)  
**Scripts Asociados:** `database/schema.sql`, `database/catalogos.sql`, `database/load_mock_data.sql`, `database/quality_checks.sql`.

---

## 1. Justificación de la Arquitectura Tecnológica Elegida

Para resolver la necesidad de almacenamiento estructurado, trazabilidad y control de calidad de la Facultad de Ingeniería, se evaluaron cuatro alternativas técnicas y se seleccionó **PostgreSQL 14+** organizado en tres esquemas lógicos (`catalogos`, `boveda_identidad`, `nucleo_analitico`) con soporte de ingesta desde archivos CSV canónicos   :

| Alternativa Evaluada | Ventajas | Limitaciones Críticas | Decisión |
| :--- | :--- | :--- | :--- |
| **Hojas de cálculo (Excel)** | Uso inmediato por personal no técnico   . | Nula integridad referencial en relaciones $1:N$ (un egresado con múltiples títulos y empleos obliga a duplicar columnas o filas), ausencia de control de acceso por esquema y alta propensión a errores manuales   . | **Descartada** como base de almacenamiento   . |
| **Archivos planos (CSV)** | Portabilidad universal y control de versiones limpio en Git   . | No imponen tipos de datos, llaves foráneas ni restricciones `CHECK` por sí mismos   . | **Adoptada únicamente** como formato canónico para carga de semillas y datos sintéticos (`mock_data/*.csv`)   . |
| **SQLite** | Base de datos en un único archivo local sin servidor   . | No soporta múltiples esquemas nativos con permisos diferenciados (`GRANT/REVOKE` por rol) ni tipos nativos `UUID` con validación estricta. | **Descartada** frente a PostgreSQL para despliegue multiusuario institucional. |
| **PostgreSQL 14+ (Motor Relacional SQL)** | Soporte nativo para `UUID`, separación por esquemas (`boveda_identidad` vs. `nucleo_analitico`), restricciones declarativas complejas (`CHECK`, `UNIQUE`, `FOREIGN KEY`), vistas analíticas y control de acceso basado en roles (RBAC)   . | Requiere motor de base de datos instalado y disciplina de normalización antes de la carga (*Schema-on-write*). | **Arquitectura Seleccionada**   . |

---

## 2. Diccionario de Datos Completo por Esquema y Tabla

### 2.1. Esquema `boveda_identidad` (Acceso Restringido al Custodio de Datos)

#### Tabla: `boveda_identidad.identidad_restringida`

Resguarda la correspondencia $1:1$ entre el identificador analítico del egresado y la referencia criptográfica del acta oficial de grado, sin almacenar nombres reales, números de cédula en texto plano ni URLs públicas directas   .

| Columna | Tipo de Dato | Nulo | Llave / Restricción (`schema.sql`) | Descripción, Obtención y Riesgo de Privacidad |
| :--- | :--- | :--- | :--- | :--- |
| `id_egresado` | `UUID` | `NOT NULL` | `PRIMARY KEY` | Identificador único subrogado (UUID v4) que vincula con el núcleo analítico sin exponer datos personales. Riesgo bajo. |
| `codigo_acta_hmac` | `CHAR(64)` | `NOT NULL` | `UNIQUE`, `CHECK (codigo_acta_hmac ~ '^[a-f0-9]{64}$')` | Código hexadecimal de 64 caracteres generado mediante `HMAC-SHA256` sobre el identificador interno del acta de grado usando una llave secreta institucional. Evita duplicados sin usar la cédula. |
| `perfil_origen_ref` | `VARCHAR(120)` | `NULL` | `UNIQUE`, `CHECK (perfil_origen_ref IS NULL OR perfil_origen_ref ~ '^urn:sintetico:perfil:[a-z0-9-]+$')` | Referencia normalizada al perfil de origen. En el entorno de demostración exige por restricción el prefijo sintético no resoluble `urn:sintetico:perfil:`. |
| `estado_autorizacion` | `VARCHAR(40)` | `NOT NULL` | `CHECK (estado_autorizacion IN ('DATO_SINTETICO_DEMO', 'AUTORIZADO_TITULAR', 'TRATAMIENTO_ESTADISTICO_ANONIMIZADO', 'REVOCADO_BLOQUEADO'))` | Base de legitimación del registro bajo la Ley 1581 de 2012  6,  . La restricción `chk_coherencia_demo_privacidad` obliga a que todo registro de prueba use `'DATO_SINTETICO_DEMO'`. |
| `fecha_registro_boveda` | `TIMESTAMPTZ` | `NOT NULL` | — | Marca temporal exacta (con zona horaria) del alta del registro en la bóveda de identidad. |
| `es_dato_sintetico` | `BOOLEAN` | `NOT NULL` | `DEFAULT TRUE`, `chk_coherencia_demo_privacidad` | Bandera de seguridad que distingue registros ficticios de demostración (`TRUE`) frente a operación institucional (`FALSE`). |

---

### 2.2. Esquema `nucleo_analitico` (Entorno Operativo Seudonimizado)

#### Tabla: `nucleo_analitico.perfiles_candidatos`

Gestiona la evaluación de correspondencia de perfiles localizados (Señales S1 a S4) y aísla en cuarentena los casos de homonimia o datos insuficientes antes de que puedan contaminar la tabla de egresados confirmados  5,  .

| Columna | Tipo de Dato | Nulo | Llave / Restricción (`schema.sql`) | Descripción y Regla de Negocio |
| :--- | :--- | :--- | :--- | :--- |
| `candidato_id` | `VARCHAR(30)` | `NOT NULL` | `PRIMARY KEY` | Identificador interno del candidato evaluado (ej. `CAND-SINT-0007`). |
| `perfil_origen_ref` | `VARCHAR(120)` | `NOT NULL` | `UNIQUE`, `CHECK (~ '^urn:sintetico:perfil:[a-z0-9-]+$')` | Referencia única del perfil evaluado para evitar reevaluar el mismo candidato en barridos sucesivos. |
| `programa_inferido_id` | `INT` | `NULL` | `FOREIGN KEY -> catalogos.cat_programa(programa_id)` | Programa curricular inferido a partir de la sección de educación del perfil. |
| `anio_grado_inferido` | `SMALLINT` | `NULL` | `CHECK (BETWEEN 1960 AND 2030)` | Año de graduación inferido en el perfil (`NULL` cuando el perfil no reporta fechas educativas, como en el Caso 7). |
| `senales_coincidentes` | `VARCHAR(50)` | `NOT NULL` | `CHECK (IN ('S1+S2+S3+S4', 'S1+S2+S3_SIN_S4', 'S1+S2+S3_SIN_S4_HOMONIMO', 'S1+S2_PARCIAL'))` | Resultado de evaluar la matriz de señales (Nombre + Universidad + Programa + Cohorte)   . |
| `conteo_homonimos_acta` | `SMALLINT` | `NOT NULL` | `CHECK (conteo_homonimos_acta >= 0)` | Cantidad de graduados en las actas oficiales que comparten el nombre y programa del candidato. |
| `estado_candidato` | `VARCHAR(35)` | `NOT NULL` | `CHECK (IN ('VINCULADO_CONFIRMADO', 'CUARENTENA_HOMONIMIA', 'CUARENTENA_DATOS_INSUFICIENTES', 'DESCARTADO_NO_EGRESADO'))` | Dictamen del proceso de identificación. `chk_homonimia_exige_alerta` impide confirmar un homónimo sin desempate. |
| `id_egresado_confirmado` | `UUID` | `NULL` | `UNIQUE`, `FOREIGN KEY -> nucleo_analitico.egresados(id_egresado)`, `chk_aislamiento_cuarentena` | Llave foránea hacia el egresado confirmado. Por restricción `chk_aislamiento_cuarentena`, **es obligatoriamente `NULL`** si `estado_candidato <> 'VINCULADO_CONFIRMADO'`. |
| `fecha_evaluacion` | `TIMESTAMPTZ` | `NOT NULL` | — | Fecha y hora en que se ejecutó la verificación de identidad. |
| `observacion_resolucion` | `TEXT` | `NOT NULL` | — | Justificación técnica del dictamen de vinculación o retención en cuarentena. |

#### Tabla: `nucleo_analitico.egresados`

Entidad maestra seudonimizada que representa exclusivamente a los graduados cuya identidad ha sido confirmada  5,  .

| Columna | Tipo de Dato | Nulo | Llave / Restricción (`schema.sql`) | Descripción y Regla de Negocio |
| :--- | :--- | :--- | :--- | :--- |
| `id_egresado` | `UUID` | `NOT NULL` | `PRIMARY KEY`, `FOREIGN KEY -> boveda_identidad.identidad_restringida(id_egresado)` | Identificador único seudonimizado del egresado confirmado  4,  . |
| `ubicacion_residencia_id` | `INT` | `NULL` | `FOREIGN KEY -> catalogos.cat_ubicacion(ubicacion_id)` | Ciudad/país de residencia actual declarada por el egresado (`NULL` si no figura)  4,  . |
| `estado_verificacion_id` | `VARCHAR(25)` | `NOT NULL` | `FOREIGN KEY -> catalogos.cat_estado_verificacion(estado_id)` | Estado operativo del registro (`VERIFICADO_ALTA`, `VERIFICADO_MEDIA`, `OBSERVACION_OBSOLETO`, `SUSPENDIDO_REVOCADO`). |
| `cohorte_primera_titulacion` | `SMALLINT` | `NOT NULL` | `CHECK (cohorte_primera_titulacion BETWEEN 1960 AND 2030)` | Año del primer título obtenido en la Facultad para segmentación rápida de cohortes. |
| `es_registro_sintetico` | `BOOLEAN` | `NOT NULL` | `DEFAULT TRUE` | Indica si el registro corresponde al conjunto sintético de prueba. |

#### Tabla: `nucleo_analitico.formacion_academica`

Almacena los títulos académicos de pregrado y posgrado del egresado en relación $1:N$  4,  .

| Columna | Tipo de Dato | Nulo | Llave / Restricción (`schema.sql`) | Descripción y Regla de Negocio |
| :--- | :--- | :--- | :--- | :--- |
| `id_formacion` | `INT` | `NOT NULL` | `PRIMARY KEY` | Identificador único del registro académico  4,  . |
| `id_egresado` | `UUID` | `NOT NULL` | `FOREIGN KEY -> nucleo_analitico.egresados(id_egresado)`, `uq_egresado_programa_anio` | Egresado titular de la formación  4,  . |
| `programa_id` | `INT` | `NOT NULL` | `FOREIGN KEY -> catalogos.cat_programa(programa_id)`, `uq_egresado_programa_anio` | Programa curricular estandarizado según código SNIES  4,  . |
| `nivel_academico_id` | `VARCHAR(20)` | `NOT NULL` | `FOREIGN KEY -> catalogos.cat_nivel_academico(nivel_id)` | Nivel del título (`PREGRADO`, `ESPECIALIZACION`, `MAESTRIA`, `DOCTORADO`)  4,  . |
| `anio_grado` | `SMALLINT` | `NOT NULL` | `CHECK (BETWEEN 1960 AND 2030)`, `uq_egresado_programa_anio` | Año de graduación verificado  4,  . |
| `verificado_acta_facultad` | `BOOLEAN` | `NOT NULL` | — | `TRUE` cuando el título fue contrastado contra acta oficial de la Facultad  4,  . |

#### Tabla: `nucleo_analitico.experiencia_laboral`

Registra la trayectoria de empleos y roles desempeñados por cada egresado en relación $1:N$, conservando tanto el dato original como su homologación estandarizada  4,  .

| Columna | Tipo de Dato | Nulo | Llave / Restricción (`schema.sql`) | Descripción y Regla de Negocio |
| :--- | :--- | :--- | :--- | :--- |
| `id_experiencia` | `INT` | `NOT NULL` | `PRIMARY KEY` | Identificador único del registro de experiencia laboral  4,  . |
| `id_egresado` | `UUID` | `NOT NULL` | `FOREIGN KEY -> nucleo_analitico.egresados(id_egresado)`, `uq_experiencia_no_duplicada` | Egresado al que pertenece la experiencia  4,  . |
| `empresa_id` | `INT` | `NULL` | `FOREIGN KEY -> catalogos.cat_empresa(empresa_id)` | Referencia al catálogo de empresas normalizadas (`NULL` si aún no está en el maestro 80/20)   . |
| `empresa_texto_original` | `VARCHAR(150)` | `NOT NULL` | `CHECK (char_length(btrim(empresa_texto_original)) >= 2)`, `uq_experiencia_no_duplicada` | Nombre de la organización tal como fue registrado en la fuente para auditoría y cruce de alias. |
| `sector_economico_id` | `VARCHAR(10)` | `NULL` | `FOREIGN KEY -> catalogos.cat_sector_economico(sector_id)` | División CIIU Rev. 4 A.C. asociada al empleo (`NULL` únicamente si es no verificable)  4,  . |
| `cargo_original` | `VARCHAR(150)` | `NOT NULL` | `CHECK (char_length(btrim(cargo_original)) >= 2)`, `uq_experiencia_no_duplicada` | Título exacto del puesto declarado en el perfil (nunca se sobrescribe)  4,  . |
| `cargo_nivel_id` | `VARCHAR(25)` | `NULL` | `FOREIGN KEY -> catalogos.cat_cargo_nivel(cargo_nivel_id)`, `chk_homologacion_consistente` | Nivel jerárquico homologado (`PRACTICANTE` a `DIRECTIVO` / `DOCENTE_INVESTIGADOR`). Es `NULL` si está pendiente de homologación (Caso 4)   . |
| `area_desempeno_id` | `VARCHAR(25)` | `NULL` | `FOREIGN KEY -> catalogos.cat_area_desempeno(area_id)`, `chk_homologacion_consistente` | Dominio funcional homologado según CUOC (`NULL` si está pendiente de homologación)  4,  . |
| `estado_homologacion` | `VARCHAR(30)` | `NOT NULL` | `CHECK (IN ('HOMOLOGADO', 'PENDIENTE_HOMOLOGACION', 'NO_VERIFICABLE', 'NO_DECLARADO'))`, `chk_homologacion_consistente` | Controla explícitamente el ciclo de vida de estandarización del cargo sin usar códigos basura (`0` o `99`). |
| `tipo_vinculacion_rol` | `VARCHAR(30)` | `NOT NULL` | `CHECK (IN ('ROL_PRINCIPAL', 'DOCENCIA_CATEDRA', 'CONSULTORIA_PARALELA', 'PRACTICA_ACADEMICA'))` | Permite distinguir pluriempleo válido (ej. industria + cátedra en Caso 5) frente a errores de cierre de fecha. |
| `modalidad_trabajo` | `VARCHAR(20)` | `NOT NULL` | `CHECK (IN ('PRESENCIAL', 'REMOTO', 'HIBRIDO', 'NO_DECLARADO'))` | Modalidad de ejecución del cargo (clave para identificar exportación remota de servicios en Caso 2)   . |
| `ubicacion_empleo_id` | `INT` | `NULL` | `FOREIGN KEY -> catalogos.cat_ubicacion(ubicacion_id)` | Ciudad/país al que está adscrito el puesto de trabajo  4,  . |
| `fecha_inicio` | `DATE` | `NULL` | `chk_fechas_coherentes`, `chk_precision_fecha_consistente`, `uq_experiencia_no_duplicada` | Fecha de inicio normalizada al primer día del mes (`YYYY-MM-01`) o `YYYY-01-01` si es anual  4,  . |
| `fecha_fin` | `DATE` | `NULL` | `chk_fechas_coherentes`, `chk_empleo_actual_abierto`, `chk_precision_fecha_consistente` | Fecha de finalización (`NULL` obligatoriamente cuando `es_actual = TRUE`)  4,  . |
| `precision_fecha` | `VARCHAR(20)` | `NOT NULL` | `CHECK (IN ('EXACTA_MENSUAL', 'ANUAL', 'SIN_FECHA'))`, `chk_precision_fecha_consistente` | Registra la granularidad real de la fecha para proteger los cálculos de duración (Caso 3)   . |
| `es_actual` | `BOOLEAN` | `NOT NULL` | `chk_empleo_actual_abierto` | `TRUE` si corresponde a una vinculación laboral activa al momento de la captura  4,  . |

#### Tabla: `nucleo_analitico.auditoria_trazabilidad`

Conserva la procedencia, vigencia, confianza y completitud de cada verificación realizada sobre un egresado  4,  .

| Columna | Tipo de Dato | Nulo | Llave / Restricción (`schema.sql`) | Descripción y Regla de Negocio |
| :--- | :--- | :--- | :--- | :--- |
| `id_auditoria` | `INT` | `NOT NULL` | `PRIMARY KEY` | Identificador único del evento de auditoría  4,  . |
| `id_egresado` | `UUID` | `NOT NULL` | `FOREIGN KEY -> nucleo_analitico.egresados(id_egresado)` | Egresado auditado  4,  . |
| `fuente_primaria` | `VARCHAR(40)` | `NOT NULL` | `CHECK (IN ('AUTOGESTION_EGRESADO', 'VERIFICACION_ASISTIDA_LINKEDIN', 'CRUCE_INSTITUCIONAL_OLE'))` | Canal legítimo del cual provino la actualización   . |
| `fecha_captura` | `TIMESTAMPTZ` | `NOT NULL` | — | Fecha y hora exacta de la verificación (permite detectar obsolescencia en Caso 8)  4,  . |
| `nivel_confianza` | `VARCHAR(15)` | `NOT NULL` | `CHECK (IN ('ALTO', 'MEDIO', 'BAJO'))` | Calificación de certeza de correspondencia del registro  4,  . |
| `estado_completitud` | `VARCHAR(35)` | `NOT NULL` | `CHECK (IN ('COMPLETO', 'PARCIAL_FECHAS_APROXIMADAS', 'PARCIAL_HOMOLOGACION_PENDIENTE', 'INCOMPLETO_REVISAR'))` | Estado de calidad documental del perfil consolidado  4,  . |
| `rol_verificador` | `VARCHAR(40)` | `NOT NULL` | — | Identificador funcional del analista o proceso que validó el dato (sin exponer nombres personales)   . |
| `observacion_auditoria` | `TEXT` | `NOT NULL` | — | Nota técnica de trazabilidad sobre el registro. |

---

### 2.3. Esquema `catalogos` (Tablas Maestras de Referencia y Estandarización)

| Tabla de Catálogo | Llave Primaria | Columnas y Restricciones Principales (`schema.sql`) | Estándar Oficial / Convención Aplicada |
| :--- | :--- | :--- | :--- |
| `catalogos.cat_ubicacion` | `ubicacion_id` (`INT`) | `codigo_pais_iso` (`CHAR(2)`), `nombre_pais` (`VARCHAR(80)`), `codigo_divipola` (`VARCHAR(10) UNIQUE`), `departamento_estado` (`VARCHAR(80)`), `ciudad_municipio` (`VARCHAR(80)`). Restricción `chk_divipola_colombia`. | **Oficial verificado:** Códigos de municipio DANE DIVIPOLA para Colombia (`11001` Bogotá, `05001` Medellín, `76001` Cali) e ISO 3166-1 alpha-2 para países (`CO`, `US`, `DE`)  4,  . |
| `catalogos.cat_nivel_academico` | `nivel_id` (`VARCHAR(20)`) | `nombre_nivel` (`VARCHAR(60) UNIQUE`), `orden_jerarquico` (`SMALLINT UNIQUE CHECK 1..10`). | **Oficial:** Niveles de educación superior del MEN (`PREGRADO`, `ESPECIALIZACION`, `MAESTRIA`, `DOCTORADO`)  4,  . |
| `catalogos.cat_programa` | `programa_id` (`INT`) | `codigo_snies` (`VARCHAR(15) UNIQUE`), `nombre_programa` (`VARCHAR(120)`), `nivel_academico_id` (`FK`), `departamento_escuela` (`VARCHAR(100)`), `activo` (`BOOLEAN`). | **Oficial verificado:** Códigos SNIES reales de los programas de Ingeniería de la UNAL Sede Bogotá (SNIES `12`, `13`, `15`, `16`, `17`, `18`, `19`, `20` y `16927`)   . |
| `catalogos.cat_sector_economico` | `sector_id` (`VARCHAR(10)`) | `seccion_ciiu` (`CHAR(1) CHECK A..U`), `division_ciiu` (`CHAR(2) CHECK 00..99`), `nombre_sector` (`VARCHAR(150)`), `UNIQUE (seccion_ciiu, division_ciiu)`. | **Oficial verificado:** Nomenclatura DANE CIIU Rev. 4 A.C. (`A01`, `C28`, `F42`, `G47`, `J62`, `K64`, `P85`)  4,  . |
| `catalogos.cat_empresa` | `empresa_id` (`INT`) | `nombre_canonico` (`VARCHAR(150) UNIQUE`), `sector_economico_id` (`FK`), `ubicacion_sede_id` (`FK`), `tamano_empresa` (`VARCHAR(50) CHECK IN ('MICRO_PEQUENA', 'MEDIANA', 'GRAN_EMPRESA', 'INSTITUCION_PUBLICA_ACADEMICA')`), `es_entidad_sintetica` (`BOOLEAN`). | **Ilustrativo sintético:** 8 organizaciones empleadoras con sufijo explícito `[SINTETICA]` para impedir cualquier asociación con individuos reales en el repositorio público. |
| `catalogos.cat_empresa_alias` | `alias_id` (`INT`) | `empresa_id` (`FK ON DELETE CASCADE`), `alias_normalizado` (`VARCHAR(150) UNIQUE`). | **Operativo:** Mapea variantes de escritura (ej. `ANDES DATA LABS` y `ANDES DATALABS SAS`) hacia el `empresa_id` canónico `10`   . |
| `catalogos.cat_cargo_nivel` | `cargo_nivel_id` (`VARCHAR(25)`) | `nombre_nivel` (`VARCHAR(60) UNIQUE`), `orden_seniority` (`SMALLINT CHECK 1..10`). | **Taxonomía analítica:** Escala de progresión (`PRACTICANTE`, `JUNIOR`, `MID`, `SENIOR`, `LIDER_GERENTE`, `DIRECTIVO`, `DOCENTE_INVESTIGADOR`)  4,  . |
| `catalogos.cat_area_desempeno` | `area_id` (`VARCHAR(25)`) | `codigo_cuoc_ref` (`VARCHAR(10)`), `nombre_area` (`VARCHAR(100) UNIQUE`), `es_nucleo_ingenieria` (`BOOLEAN`). | **Oficial verificado:** Grupos primarios de referencia CUOC DANE / CIUO-08 (`2512`, `2511`, `2523`, `2142`, `2144`, `2141`, `2310`, `2431`)  4,  . |
| `catalogos.cat_estado_verificacion` | `estado_id` (`VARCHAR(25)`) | `descripcion_estado` (`VARCHAR(150)`), `apto_indicadores_oficiales` (`BOOLEAN`). | **Gobernanza interna:** Controla qué registros entran a las vistas oficiales de indicadores (`VERIFICADO_ALTA`, `VERIFICADO_MEDIA`, `OBSERVACION_OBSOLETO`, `SUSPENDIDO_REVOCADO`). |

---

## 3. Matriz de Demostración de los 8 Escenarios Sintéticos y Reglas de Calidad

| Escenario de Prueba | Identificador en `mock_data/*.csv` | Tablas Involucradas | Regla de Calidad o Vista que lo Comprueba (`quality_checks.sql`) |
| :--- | :--- | :--- | :--- |
| **Caso 1. Trayectoria profesional completa** | `550e8400-e29b-41d4-a716-446655440001` | `identidad_restringida`, `egresados`, `formacion_academica` (`101`, `102`), `experiencia_laboral` (`1001`, `1002`, `1003`), `auditoria_trazabilidad` (`5001`)   . | En `vw_experiencias_analitica` calcula duraciones exactas (`5` y `28` meses en roles previos) y consolida 2 títulos y 3 empleos sin duplicación en `GROUP BY`  2,  . |
| **Caso 2. Movilidad internacional remota** | `550e8400-e29b-41d4-a716-446655440002` | `egresados` (residencia `11001` Bogotá), `experiencia_laboral` (`1004`, modalidad `REMOTO`, puesto `84001` Austin), `cat_empresa` (`20`, sede `84001`)   . | La vista `vw_experiencias_analitica` lo clasifica automáticamente como `EXPORTACION_SERVICIOS_REMOTO`  2,  . |
| **Caso 3. Fechas incompletas (precisión anual)** | `550e8400-e29b-41d4-a716-446655440003` | `experiencia_laboral` (`1005`, `fecha_inicio = '2021-01-01'`, `precision_fecha = 'ANUAL'`)   . | Detectado por `QC-02_FECHA_PRECISION_LIMITADA` (`INCOMPLETITUD_CONSERVADA`) y excluido de `meses_duracion_verificados` (`NULL`). |
| **Caso 4. Cargo ambiguo pendiente de homologar** | `550e8400-e29b-41d4-a716-446655440004` | `experiencia_laboral` (`1006`, `cargo_original = 'Ninja de Ecosistemas & Growth Hacker'`, clasificadores `NULL`, `PENDIENTE_HOMOLOGACION`)   . | Detectado por `QC-03_HOMOLOGACION_PENDIENTE` (`ADVERTENCIA_REVISION_HUMANA`) para asignación por comité. |
| **Caso 5. Múltiples empleos actuales legítimos** | `550e8400-e29b-41d4-a716-446655440005` | `experiencia_laboral` (`1007` `ROL_PRINCIPAL` en manufactura + `1008` `DOCENCIA_CATEDRA` en educación, ambos `es_actual = TRUE`)   . | Validado positivamente por `QC-06_PLURIEMPLEO_LEGITIMO_VALIDADO` (`SITUACION_VALIDA_CONTROLADA`) sin disparar falso positivo en `QC-05`   . |
| **Caso 6. Transición hacia un sector no afín** | `550e8400-e29b-41d4-a716-446655440006` | `formacion_academica` (`107`, Ing. Química), `experiencia_laboral` (`1009`, área `COMERCIAL_VENTAS` con `es_nucleo_ingenieria = FALSE` en sector `G47`)   . | En la consulta de indicadores reporta `afin_ingenieria_actual = FALSE`, permitiendo medir movilidad intersectorial  2,  . |
| **Caso 7. Homonimia sin resolver (Cuarentena)** | `CAND-SINT-0007` | Exclusivamente en `perfiles_candidatos` (`CUARENTENA_HOMONIMIA`, `conteo_homonimos_acta = 2`, `id_egresado_confirmado = NULL`)  5,  . | Detectado por `QC-01_CUARENTENA_IDENTIDAD` (`EXCLUSION_PREVENTIVA`) y ausente de `egresados` y `vw_egresados_confirmados_indicadores`. |
| **Caso 8. Información desactualizada** | `550e8400-e29b-41d4-a716-446655440008` | `auditoria_trazabilidad` (`5008`, `fecha_captura = '2024-05-10'`), `experiencia_laboral` (`1010`, practicante desde 2017)   . | Detectado por `QC-04_OBSOLESCENCIA_CRONOLOGICA` (`ADVERTENCIA_REVISION_HUMANA`, 906 días desde última captura al 2 de noviembre de 2026) . |
