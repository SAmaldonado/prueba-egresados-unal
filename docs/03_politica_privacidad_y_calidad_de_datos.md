# Política de Protección de Datos Personales, Gobernanza de Privacidad y Motor de Calidad de Datos

**Entidad:** Facultad de Ingeniería — Universidad Nacional de Colombia  
**Repositorio:** `seguimiento-egresados-linkedin`  
**Scripts SQL Vinculados:** `database/schema.sql`, `database/catalogos.sql`, `database/load_mock_data.sql`, `database/quality_checks.sql`

---

## 1. Marco Jurídico, Contractual y Jurisprudencial Aplicable

El diseño del sistema parte de una premisa jurídica y arquitectónica innegociable: **que un perfil profesional sea visible en internet no convierte su información en un "dato público" de libre tratamiento ni autoriza su extracción masiva automatizada**.

### 1.1. Normatividad colombiana de Habeas Data (Ley Estatutaria 1581 de 2012)

1. **Clasificación legal del dato profesional y académico (Art. 3, Ley 1581 de 2012 y Decreto 1074 de 2015):**
   * Mientras que el estado de graduado o la vigencia de una matrícula profesional cumplen funciones públicas, la trayectoria laboral detallada (empresas, fechas exactas de vinculación, cargos específicos y movilidad geográfica) constituye **información semiprivada**, cuyo conocimiento interesa al titular y a un sector determinado de personas o instituciones.
   * La **Superintendencia de Industria y Comercio (SIC)**, mediante el **Concepto 16-172268** y la **Guía para el tratamiento de datos personales en el contexto universitario**, establece que la información publicada por un ciudadano en redes sociales está sujeta al **Principio de Finalidad** (Art. 4, literal b). Una universidad no puede recolectar ni almacenar perfiles nominales de redes sociales para finalidades distintas a las autorizadas por el egresado sin contar con legitimación legal o aplicar disociación estadística irreversible.
2. **Bases de legitimación en la arquitectura propuesta:**
   * **Canal Nominal Autorizado (`AUTORIZADO_TITULAR`):** Para los egresados que actualizan sus datos mediante campañas de autogestión o formularios de graduación (Momento Cero / OLE), el tratamiento se ampara en la autorización previa, expresa e informada del titular (Art. 9, Ley 1581 de 2012).
   * **Canal Estadístico Disociado (`TRATAMIENTO_ESTADISTICO_ANONIMIZADO`):** Para las verificaciones puntuales destinadas exclusivamente a estadísticas institucionales e indicadores curriculares, el tratamiento se acoge a la excepción de finalidad histórica, estadística o científica (Art. 6, literal e, y Art. 10 de la Ley 1581 de 2012, reglamentados por el Decreto 1074 de 2015), garantizando la separación técnica entre la bóveda de identidad y el núcleo analítico seudonimizado, así como la publicación exclusiva de resultados agregados con reserva estadística ($k \ge 5$).

### 1.2. Restricciones contractuales y técnicas de LinkedIn

| Fuente Contractual / Técnica | Disposición Específica | Impacto en el Diseño Arquitectónico |
| :--- | :--- | :--- |
| **Acuerdo de Usuario de LinkedIn (Sección 8.2, numerales 2, 3, 4 y 13)** | Prohíbe desarrollar, respaldar o utilizar software, dispositivos, scripts, robots o cualquier otro medio o proceso (*incluidos crawlers, plugins de navegador y complementos*) para hacer *scraping* de los Servicios o copiar perfiles y otros datos sin consentimiento. | Se descarta de plano cualquier arquitectura basada en *scrapers* (Selenium, Playwright, Puppeteer) o extensiones de navegador de terceros (PhantomBuster, Apollo). |
| **Términos de Uso de las APIs de LinkedIn (*Restricted Use Cases & Data Storage*)** | Prohíben el uso de las APIs de Marketing o Perfil para enriquecimiento masivo de bases de datos internas (*Data Enrichment*) y obligan a purgar la caché de datos de perfiles de terceros en un plazo de $24$ a $48$ horas. | Se descarta depender de la API de Perfiles para poblar permanentemente la base histórica de la Facultad. |
| **Jurisprudencia: *hiQ Labs, Inc. v. LinkedIn Corp.* (9th Cir. 2022) y *Meta v. Bright Data* (2024)** | Aunque la extracción de páginas públicas sin sesión no constituye delito informático federal bajo la CFAA en EE. UU., los tribunales confirmaron que el *scraping* constituye **incumplimiento contractual civil (Breach of Contract)** cuando existe sesión autenticada, como ocurre en LinkedIn para visualizar historiales completos. | Protege jurídicamente a la Universidad frente a reclamaciones contractuales y evita el bloqueo algorítmico (*TLS Fingerprinting* / *BrowserGate*) de las cuentas institucionales. |

---

## 2. Arquitectura de Privacidad por Diseño (*Privacy by Design*)

### 2.1. Separación en tres niveles de sensibilidad y partición de esquemas en PostgreSQL

El modelo físico implementado en `database/schema.sql` divide la base de datos en tres esquemas aislados (`boveda_identidad`, `nucleo_analitico` y `catalogos`) gobernados por roles de acceso diferenciados (RBAC):

| Nivel de Sensibilidad | Esquema y Objetos en PostgreSQL | Contenido Permitido | Rol Autorizado (RBAC) | Regla para Repositorio Público (GitHub) |
| :--- | :--- | :--- | :--- | :--- |
| **Nivel 1: Restringido (Bóveda de Identidad)** | `boveda_identidad.identidad_restringida` | `id_egresado` (UUID v4), `codigo_acta_hmac` (HMAC-SHA256), `perfil_origen_ref`, `estado_autorizacion`, `fecha_registro_boveda`. | `rol_custodio_identidad` (Coordinación de Egresados / Oficial de Protección de Datos). | **PROHIBIDO subir datos reales.** En demostración solo se admiten registros con `es_dato_sintetico = TRUE` y `urn:sintetico:perfil:*`. |
| **Nivel 2: Operativo Interno (Seudonimizado)** | `nucleo_analitico.egresados`, `formacion_academica`, `experiencia_laboral`, `auditoria_trazabilidad`, `perfiles_candidatos` | Trayectorias académicas y laborales asociadas únicamente al `id_egresado` (`UUID`) sin nombres propios, sin cédulas y sin correos electrónicos. | `rol_analista_curricular` (Equipo técnico de analítica y calidad curricular bajo compromiso de confidencialidad). | **Solo datos 100 % sintéticos** (`mock_data/*.csv`) claramente etiquetados como ficticios. |
| **Nivel 3: Institucional / Público (Anonimizado y Agregado)** | Vistas analíticas con agrupación y filtro $k \ge 5$ (`vw_egresados_confirmados_indicadores`) | Tasas de empleabilidad, distribución por división CIIU, áreas CUOC, movilidad geográfica y tiempos medianos de progresión. | `rol_lector_indicadores` (Dirección Académica, Comités de Programa, Pares de Acreditación). | **Permitido:** Código SQL de vistas, catálogos oficiales y resultados agregados. |

### 2.2. Estrategia criptográfica: Por qué usamos `HMAC-SHA256` sobre el acta y no un hash simple de la cédula

Un error frecuente de seguridad consiste en almacenar el hash `SHA-256` directo del número de cédula de ciudadanía creyendo que con ello el dato queda anonimizado. Dado que los números de cédula en Colombia pertenecen a un espacio numérico reducido y predecible (aproximadamente $10^8$ combinaciones válidas), un atacante con acceso a la tabla podría revertir todos los hashes en pocos segundos mediante una tabla arcoíris (*rainbow table*) o fuerza bruta.

Para eliminar este vector de ataque:
1. No se utiliza el número de documento de identidad como insumo en la base de seguimiento.
2. Se emplea una construcción **HMAC-SHA256** (`codigo_acta_hmac`, `CHAR(64)`) calculada sobre el identificador interno del acta de grado combinada con una **llave criptográfica secreta institucional** almacenada fuera de la base de datos (en variables de entorno protegidas del servidor).
3. El constraint `CHECK (codigo_acta_hmac ~ '^[a-f0-9]{64}$')` y la restricción `UNIQUE` garantizan en PostgreSQL que ningún graduado pueda duplicarse sin almacenar jamás su documento nacional de identidad.

### 2.3. Prevención de reidentificación indirecta (Efecto Mosaico) mediante $k$-anonimato ($k \ge 5$)

Incluso sin nombres ni números de documento, combinar variables como `programa_id = 'Ingeniería Agrícola'`, `anio_grado = 2023`, `ubicacion_empleo_id = 'Munich, Alemania'` y `cargo_nivel_id = 'SENIOR'` permite singularizar e identificar a una persona específica dentro de una cohorte pequeña.

* **Regla de control de revelación estadística:** Todo reporte, exportación o tablero conectado al esquema `nucleo_analitico` aplica un umbral mínimo de agregación de **$k = 5$ individuos distintos** por celda analítica:

    SELECT
        p.nombre_programa,
        s.nombre_sector,
        COUNT(DISTINCT e.id_egresado) AS total_egresados
    FROM nucleo_analitico.vw_egresados_confirmados_indicadores e
    JOIN nucleo_analitico.formacion_academica f ON e.id_egresado = f.id_egresado
    JOIN catalogos.cat_programa p ON f.programa_id = p.programa_id
    JOIN nucleo_analitico.experiencia_laboral ex ON e.id_egresado = ex.id_egresado AND ex.es_actual = TRUE
    JOIN catalogos.cat_sector_economico s ON ex.sector_economico_id = s.sector_id
    GROUP BY p.nombre_programa, s.nombre_sector
    HAVING COUNT(DISTINCT e.id_egresado) >= 5;

* Las categorías cuyo conteo sea $1 \le n < 5$ se consolidan automáticamente bajo la etiqueta `"Otros / Reserva Estadística (n < 5)"`.

### 2.4. Protocolo de conservación, obsolescencia y derecho de supresión (Habeas Data)

Cuando un egresado ejerce su derecho constitucional de revocatoria de autorización o supresión de datos personales (Art. 8, Ley 1581 de 2012), el sistema ejecuta un protocolo transaccional auditable:
1. En `boveda_identidad.identidad_restringida`, el campo `estado_autorizacion` cambia a `'REVOCADO_BLOQUEADO'` y se establece `perfil_origen_ref = NULL`.
2. Se conserva únicamente `codigo_acta_hmac` asociado al estado `'REVOCADO_BLOQUEADO'` como **lista de exclusión criptográfica (*opt-out list*)**, garantizando que en futuros barridos semestrales ningún analista vuelva a buscar o contactar a dicho egresado por error.
3. En `nucleo_analitico.egresados`, el `estado_verificacion_id` pasa a `'SUSPENDIDO_REVOCADO'`, cuyo atributo `apto_indicadores_oficiales = FALSE` en `catalogos.cat_estado_verificacion` lo excluye de forma inmediata y automática de todas las vistas analíticas (`vw_egresados_confirmados_indicadores`).

---

## 3. Gobernanza de Calidad de Datos y Motor de Reglas Deterministas

La calidad de los datos no se delega únicamente a la buena voluntad del analista; se impone mediante **dos barreras complementarias**: restricciones declarativas duras en el DDL (`database/schema.sql`) y vistas de auditoría continua (`database/quality_checks.sql`).

### 3.1. Barrera 1: Restricciones declarativas en el motor SQL (*Schema-on-Write*)

| Nombre del Constraint (`schema.sql`) | Tabla Aplicada | Condición Lógica Impuesta | Error que Impide en la Base de Datos |
| :--- | :--- | :--- | :--- |
| `chk_coherencia_demo_privacidad` | `identidad_restringida` | `(es_dato_sintetico = TRUE AND estado_autorizacion = 'DATO_SINTETICO_DEMO') OR (es_dato_sintetico = FALSE AND estado_autorizacion <> 'DATO_SINTETICO_DEMO')` | Impide mezclar registros sintéticos de prueba con registros reales de producción. |
| `chk_aislamiento_cuarentena` | `perfiles_candidatos` | `(estado_candidato = 'VINCULADO_CONFIRMADO' AND id_egresado_confirmado IS NOT NULL) OR (estado_candidato <> 'VINCULADO_CONFIRMADO' AND id_egresado_confirmado IS NULL)` | **Bloqueo crítico de identidad:** Impide físicamente que un perfil en cuarentena por homonimia o datos insuficientes se vincule a un egresado confirmado (Caso 7). |
| `chk_homonimia_exige_alerta` | `perfiles_candidatos` | `NOT (senales_coincidentes = 'S1+S2+S3_SIN_S4_HOMONIMO' AND estado_candidato = 'VINCULADO_CONFIRMADO')` | Impide que un analista marque como confirmado un perfil con colisión de homonimia sin señal S4 de desempate. |
| `uq_egresado_programa_anio` | `formacion_academica` | `UNIQUE (id_egresado, programa_id, anio_grado)` | Impide duplicar el mismo título académico para un mismo egresado y año. |
| `chk_fechas_coherentes` | `experiencia_laboral` | `fecha_fin IS NULL OR (fecha_inicio IS NOT NULL AND fecha_fin >= fecha_inicio)` | Impide registrar experiencias donde la fecha de retiro sea anterior a la fecha de ingreso. |
| `chk_empleo_actual_abierto` | `experiencia_laboral` | `(es_actual = TRUE AND fecha_fin IS NULL) OR (es_actual = FALSE)` | Impide que un empleo marcado como vigente (`es_actual = TRUE`) tenga simultáneamente fecha de finalización. |
| `chk_precision_fecha_consistente` | `experiencia_laboral` | Coherencia entre `precision_fecha` (`EXACTA_MENSUAL`, `ANUAL`, `SIN_FECHA`) y la presencia o formato de `fecha_inicio` (`YYYY-01-01` para anual). | Impide tratar fechas imputadas a nivel de año como si tuvieran precisión mensual exacta (Caso 3). |
| `chk_homologacion_consistente` | `experiencia_laboral` | Si `estado_homologacion = 'HOMOLOGADO'`, exige `cargo_nivel_id IS NOT NULL` y `area_desempeno_id IS NOT NULL`; si está pendiente, exige `NULL` en ambos. | Elimina el uso de códigos basura (`0`, `99`, `'N/A'`) y obliga a gestionar explícitamente los cargos ambiguos (Caso 4). |
| `uq_experiencia_no_duplicada` | `experiencia_laboral` | `UNIQUE (id_egresado, empresa_texto_original, cargo_original, fecha_inicio)` | Impide cargar dos veces el mismo empleo, pero permite registrar ascensos reales dentro de la misma empresa con distinto cargo o fecha (Caso 1). |

### 3.2. Barrera 2: Motor de auditoría de calidad (`database/quality_checks.sql`)

La vista `nucleo_analitico.vw_reporte_calidad_datos` evalúa continuamente seis reglas deterministas (`QC-01` a `QC-06`) sobre la base de datos:

| Código de Regla | Nombre de la Regla | Condición Detectada | Severidad Asignada | Caso Sintético que la Activa |
| :--- | :--- | :--- | :--- | :--- |
| **`QC-01`** | `QC-01_CUARENTENA_IDENTIDAD` | Perfiles retenidos en `perfiles_candidatos` con `estado_candidato <> 'VINCULADO_CONFIRMADO'` por colisión de homónimos o falta de señales. | `EXCLUSION_PREVENTIVA` | **Caso 7 (`CAND-SINT-0007`):** Homonimia en Ingeniería Eléctrica con 2 graduados en acta y sin año en perfil. |
| **`QC-02`** | `QC-02_FECHA_PRECISION_LIMITADA` | Experiencias con `precision_fecha IN ('ANUAL', 'SIN_FECHA')` donde la duración exacta en meses se anula preventivamente. | `INCOMPLETITUD_CONSERVADA` | **Caso 3 (`...0003`):** Empleo en construcción con solo año `2021` (`2021-01-01`). |
| **`QC-03`** | `QC-03_HOMOLOGACION_PENDIENTE` | Experiencias con `estado_homologacion <> 'HOMOLOGADO'` cuyos clasificadores estándar permanecen en `NULL` esperando revisión humana. | `ADVERTENCIA_REVISION_HUMANA` | **Caso 4 (`...0004`):** Cargo `'Ninja de Ecosistemas & Growth Hacker'`. |
| **`QC-04`** | `QC-04_OBSOLESCENCIA_CRONOLOGICA` | Egresados cuya última `fecha_captura` supera los $540$ días ($18$ meses) o con estado `'OBSERVACION_OBSOLETO'`. | `ADVERTENCIA_REVISION_HUMANA` | **Caso 8 (`...0008`):** Captura del `2024-05-10` ($906$ días de antigüedad) aún como practicante desde 2017. |
| **`QC-05`** | `QC-05_MULTIEMPLEO_PRINCIPAL_SOSPECHOSO` | Egresados con $> 1$ experiencia activa (`es_actual = TRUE`) marcada simultáneamente como `tipo_vinculacion_rol = 'ROL_PRINCIPAL'`. | `ALERTA_CONTRADICCION` | Ninguno en la semilla limpia (diferenciado correctamente del pluriempleo académico legítimo). |
| **`QC-06`** | `QC-06_PLURIEMPLEO_LEGITIMO_VALIDADO` | Egresados con múltiples experiencias activas que combinan `ROL_PRINCIPAL` con `DOCENCIA_CATEDRA` o `CONSULTORIA_PARALELA`. | `SITUACION_VALIDA_CONTROLADA` | **Caso 5 (`...0005`):** Ingeniero Senior en industria manufacturera + Docente Catedrático en la UNAL. |

---

## 4. Trazabilidad de Cuatro Dimensiones por Registro

Cada dato consolidado en el sistema responde en todo momento a las cuatro preguntas fundamentales de auditoría institucional mediante la consulta integrada de `perfiles_candidatos` y `auditoria_trazabilidad`:

1. **¿De dónde salió el dato?** Columna `fuente_primaria` (`AUTOGESTION_EGRESADO`, `VERIFICACION_ASISTIDA_LINKEDIN`, `CRUCE_INSTITUCIONAL_OLE`) y referencia `perfil_origen_ref`.
2. **¿Cuándo se consultó o verificó?** Columnas `fecha_captura` (`TIMESTAMPTZ` en `auditoria_trazabilidad`) y `fecha_evaluacion` (en `perfiles_candidatos`).
3. **¿Cómo se verificó su correspondencia e integridad?** Columnas `senales_coincidentes` (`S1+S2+S3+S4`, `S1+S2+S3_SIN_S4`), `verificado_acta_facultad` (`BOOLEAN`), `rol_verificador` y `observacion_auditoria`.
4. **¿Qué nivel de confianza y completitud tiene?** Columnas `nivel_confianza` (`ALTO`, `MEDIO`, `BAJO`), `estado_verificacion_id` y `estado_completitud`.