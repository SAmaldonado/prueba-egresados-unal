# Diseño de una Metodología y Arquitectura de Datos para la Consolidación de Información Profesional de Egresados a partir de LinkedIn

**Facultad de Ingeniería — Universidad Nacional de Colombia**  
**Documento Técnico Consolidado (Secciones 3.1, 3.2 y 3.3 de la Convocatoria)**  
**Fecha de Entrega:** Noviembre de 2026  

---

## Resumen Ejecutivo

El presente documento define la metodología integral y la arquitectura de base de datos relacional en **PostgreSQL 14+** para identificar, recolectar, depurar, estandarizar, auditar y analizar la trayectoria profesional de los egresados de la Facultad de Ingeniería a partir de información disponible en LinkedIn y fuentes institucionales complementarias.

La solución se fundamenta en cuatro decisiones de ingeniería y gobernanza de información:

1. **Identificación determinista guiada por semilla institucional (Matriz S1-S4):**
2. Se descarta la búsqueda a ciegas en redes sociales; todo proceso parte del registro oficial de graduados de la Facultad (Actas de Grado) y aplica cuatro señales de verificación académica con aislamiento estricto en cuarentena para casos de homonimia no resuelta.
3. **Recolección lícita en dos velocidades (Cumplimiento de Ley 1581 de 2012 y Sección 8.2 de LinkedIn):** Se prohíbe el *web scraping* automatizado y el uso de extensiones no autorizadas. En su lugar, se combina un **Nivel Macro** inmediato y anónimo (*LinkedIn Alumni Tool*) con un **Nivel Micro** longitudinal alimentado por autogestión consentida, cruces internos (Momento Cero / OLE) y verificación humana asistida bajo límites estrictos.
4. **Privacidad por diseño y separación de esquemas:** La base de datos separa físicamente la bóveda restringida de identidad (`boveda_identidad`, protegida con `HMAC-SHA256` sobre el acta de grado y `UUID v4`) del núcleo analítico seudonimizado (`nucleo_analitico`), aplicando reserva estadística de $k$-anonimato ($k \ge 5$) en la capa de publicación de indicadores.
5. **Estandarización oficial y calidad determinista (*Schema-on-Write*):** Las trayectorias en relación $1:N$ se normalizan contra catálogos oficiales verificados (**SNIES**, **DANE CIIU Rev. 4 A.C.**, **CUOC / CIUO-08** y **DIVIPOLA / ISO 3166-1**), preservando siempre el texto original declarado por el egresado y auditando anomalías mediante seis reglas automatizadas (`QC-01` a `QC-06`).

---

## Parte I. Metodología de Identificación, Recolección, Calidad y Análisis (Sección 3.1)

### 1. Estrategia de Identificación de Egresados y Resolución de Identidad

#### 1.1. Semilla institucional y fuentes complementarias

La localización de perfiles parte del universo oficial de graduados de la Facultad de Ingeniería (Actas de Grado y Sistema de Información Académica) y se apoya en tres fuentes complementarias bajo condiciones de legitimidad:

* **Campañas de autogestión y portal de egresados:** El graduado aporta su enlace de perfil y otorga autorización expresa de tratamiento de datos personales.
* **Encuestas institucionales (Momento Cero / OLE):** Cruce de cohorte de grado y datos de contacto institucionales autorizados al graduarse.
* **Directorios públicos de consejos profesionales (COPNIA):** Consulta puntual de vigencia de matrícula profesional exclusivamente como señal secundaria para desempatar homónimos.

#### 1.2. Protocolo de búsqueda y Matriz de Señales (S1 a S4)

La localización utiliza operadores booleanos estructurados sobre motores indexados y el buscador institucional:

> `site:linkedin.com/in/ "Nombre Apellido" ("Universidad Nacional de Colombia" OR "UNAL") ("Facultad de Ingeniería" OR "Ingeniería de Sistemas" OR "Ingeniería Civil")`

Todo perfil localizado ingresa inicialmente a `nucleo_analitico.perfiles_candidatos` y se califica frente a cuatro señales:

* **S1 (Nombre):** Coincidencia de nombres y dos apellidos, o primer nombre, primer apellido e inicial del segundo apellido compatible.
* **S2 (Institución):** Declaración explícita de la Universidad Nacional de Colombia y/o Facultad de Ingeniería en educación.
* **S3 (Programa Curricular):** Correspondencia con el catálogo oficial SNIES de la Facultad (`catalogos.cat_programa`).
* **S4 (Cohorte Temporal):** Año de finalización en LinkedIn dentro de una ventana de $\pm 1$ año respecto al acta oficial de grado.

#### 1.3. Resolución de homónimos y niveles de confianza

| Nivel de Confianza | Señales Verificadas | Estado en `perfiles_candidatos` | Estado en `egresados` | Uso Permitido en Indicadores |
| :--- | :--- | :--- | :--- | :--- |
| **ALTO** | Autogestión autenticada o `S1+S2+S3+S4` sin colisión de homónimos. | `VINCULADO_CONFIRMADO` | `VERIFICADO_ALTA` | Apto para todos los indicadores longitudinales, sectoriales y de inserción. |
| **MEDIO** | `S1+S2+S3` sin año exacto (`S4` ausente o $\pm 2$ años) con `conteo_homonimos_acta = 1`. | `VINCULADO_CONFIRMADO` | `VERIFICADO_MEDIA` | Apto para distribución sectorial, áreas y movilidad; excluido de duración exacta si carece de mes. |
| **BAJO** | Colisión de homonimia (`S1+S2+S3_SIN_S4_HOMONIMO`, `conteo_homonimos_acta >= 2`) o `S1+S2_PARCIAL`. | `CUARENTENA_HOMONIMIA` / `CUARENTENA_DATOS_INSUFICIENTES` | **No ingresa** (`id_egresado_confirmado IS NULL`) | **Excluido totalmente** de las vistas analíticas e indicadores (Caso 7). |
| **DESCARTADO** | Contradicción comprobada con el acta oficial (otra institución o facultad). | `DESCARTADO_NO_EGRESADO` | **No ingresa** | Excluido; se registra la referencia para no reevaluar el perfil en barridos futuros. |

---

### 2. Clasificación Estratégica de Variables (Principio de Minimización)

* **Información indispensable (Obligatoria):** `id_egresado` (`UUID`), `codigo_acta_hmac` (`CHAR(64)`), `estado_autorizacion`, `programa_id`, `nivel_academico_id`, `anio_grado`, `empresa_texto_original`, `cargo_original`, `estado_homologacion`, `precision_fecha`, `es_actual`, `fuente_primaria`, `fecha_captura` y `nivel_confianza`.
* **Información útil (Opcional o condicionada por homologación):** `empresa_id`, `sector_economico_id` (CIIU), `cargo_nivel_id`, `area_desempeno_id` (CUOC), `tipo_vinculacion_rol`, `modalidad_trabajo`, `fecha_inicio`, `fecha_fin` y triple ubicación geográfica (residencia del egresado, puesto de trabajo y sede matriz de la empresa).
* **Información prescindible (Excluida):** Listados abiertos de *skills* sin validar, extracto libre *"Acerca de"*, reacciones o publicaciones en la red y cursos cortos informales.
* **Información inconveniente o prohibida (Bloqueada):** Fotografías del perfil (dato biométrico), fecha de nacimiento o edad exacta, estado civil, dirección o teléfono privado, y afiliaciones políticas, religiosas o sindicales.

---

### 3. Recolección Lícita, Depuración y Homologación en Dos Capas

1. **Recolección en dos velocidades:**
   * **Nivel Macro (*LinkedIn Alumni Tool*):** Cortes semestrales agregados y anónimos por cohorte, empleador, sector y ubicación desde la página oficial de la Universidad, utilizados además para medir y corregir el sesgo de cobertura.
   * **Nivel Micro (Base relacional):** Alimentado por campañas de autogestión (`AUTOGESTION_EGRESADO`), cruces internos autorizados (`CRUCE_INSTITUCIONAL_OLE`) y verificación manual asistida (`VERIFICACION_ASISTIDA_LINKEDIN`, máximo $50$ consultas manuales por jornada sin bots ni plugins).
2. **Homologación de empleadores (Regla de Pareto 80/20):** Se mantiene un catálogo maestro (`catalogos.cat_empresa` y `cat_empresa_alias`) con las ~200 empresas principales empleadoras de ingenieros cruzadas con su CIIU oficial en RUES; para el 20 % restante de cola larga, se conserva `empresa_texto_original` y se asigna directamente el `sector_economico_id` mediante equivalencia entre *LinkedIn Industry Codes* y divisiones CIIU Rev. 4 A.C.
3. **Homologación de cargos sin pérdida del dato original:** El título libre se preserva siempre en `cargo_original`. Cuando un cargo es ambiguo o creativo (Caso 4), `cargo_nivel_id` y `area_desempeno_id` permanecen en `NULL` y `estado_homologacion` toma el valor `'PENDIENTE_HOMOLOGACION'`, enviando el registro a la cola `QC-03` sin inventar códigos ficticios.

---

### 4. Protección de Datos Personales, Calidad y Casos Límite

#### 4.1. Obligaciones legales frente a buenas prácticas técnicas

| Aspecto | Sustento Normativo / Técnico | Clasificación | Implementación en el Sistema |
| :--- | :--- | :--- | :--- |
| **Dato profesional como dato semiprivado** | Ley 1581 de 2012 (Art. 3); Doctrina SIC Concepto 16-172268 y Guía Universitaria. | **Obligación Legal** | Tratamiento sujeto a autorización (`AUTORIZADO_TITULAR`) o disociación estadística (`TRATAMIENTO_ESTADISTICO_ANONIMIZADO`). |
| **Prohibición de extracción automatizada** | Acuerdo de Usuario de LinkedIn (Sección 8.2, numerales 2, 3, 4 y 13); *hiQ Labs v. LinkedIn*. | **Obligación Contractual** | Ausencia total de *scrapers* o extensiones no autorizadas. |
| **Separación de Bóveda PII y `HMAC-SHA256`** | Privacidad por Diseño (*Privacy by Design*). | **Buena Práctica Técnica** | Esquema `boveda_identidad` restringido; uso de `codigo_acta_hmac` con llave secreta institucional en lugar de hashear cédulas. |
| **Reserva estadística ($k$-anonimato, $k \ge 5$)** | Control de revelación estadística contra efecto mosaico. | **Buena Práctica Técnica** | Cláusula `HAVING COUNT(DISTINCT id_egresado) >= 5` en reportes y tableros institucionales. |

#### 4.2. Matriz de control de calidad y casos límite (`quality_checks.sql`)

| Regla SQL | Anomalía o Caso Límite Detectado | Severidad | Acción del Sistema y Escenario Sintético |
| :--- | :--- | :--- | :--- |
| **`QC-01`** | Homonimia sin señal S4 o identidad no comprobable. | `EXCLUSION_PREVENTIVA` | Bloqueado por `chk_aislamiento_cuarentena` en `perfiles_candidatos` (`CAND-SINT-0007`, Caso 7). No contamina `egresados`. |
| **`QC-02`** | Fechas laborales solo con año (`precision_fecha = 'ANUAL'`). | `INCOMPLETITUD_CONSERVADA` | Registra `YYYY-01-01`, pero `vw_experiencias_analitica` calcula `meses_duracion_verificados = NULL` (Caso 3). |
| **`QC-03`** | Cargo ambiguo (`PENDIENTE_HOMOLOGACION`). | `ADVERTENCIA_REVISION_HUMANA` | Conserva `cargo_original`, mantiene clasificadores en `NULL` y enruta a supervisión humana (Caso 4). |
| **`QC-04`** | Registro desactualizado ($> 540$ días o `OBSERVACION_OBSOLETO`). | `ADVERTENCIA_REVISION_HUMANA` | Prioriza al egresado para campaña de actualización y lo excluye de cortes de coyuntura actual (Caso 8). |
| **`QC-05`** | Más de un `ROL_PRINCIPAL` activo simultáneo (`es_actual = TRUE`). | `ALERTA_CONTRADICCION` | Alerta por posible olvido de cierre de fecha de finalización en LinkedIn. |
| **`QC-06`** | Pluriempleo compatible (`ROL_PRINCIPAL` + `DOCENCIA_CATEDRA`). | `SITUACION_VALIDA_CONTROLADA` | Valida y conserva ambos empleos actuales en relación $1:N$ sin alerta de error (Caso 5). |

---

### 5. Indicadores Institucionales y Sostenibilidad Operativa

#### 5.1. Indicadores estratégicos para la Facultad

1. **Tasa de Afinidad Curricular (TAC):** Proporción de egresados cuyo empleo actual pertenece al núcleo de ingeniería (`es_nucleo_ingenieria = TRUE` en `cat_area_desempeno`) frente a transiciones hacia áreas comerciales o administrativas (Caso 6).
2. **Distribución Sectorial de Empleabilidad (DSE):** Participación porcentual de graduados por sección y división CIIU Rev. 4 A.C., ponderada por la **Tasa de Cobertura Verificada (TCV)** de cada cohorte para corregir el sesgo de representación de LinkedIn.
3. **Tiempo de Progresión Jerárquica (TPJ):** Mediana de meses verificados (`meses_duracion_verificados`, filtrando `precision_fecha = 'EXACTA_MENSUAL'`) requeridos para ascender de nivel `JUNIOR` a `SENIOR` o `LIDER_GERENTE` (Caso 1).
4. **Índice de Movilidad Internacional y Exportación Remota (IMIES):** Clasificación automática en tres categorías mediante `vw_experiencias_analitica`: `MERCADO_NACIONAL_LOCAL`, `EXPORTACION_SERVICIOS_REMOTO` (reside en Colombia y trabaja remoto para el exterior, Caso 2) y `EMIGRACION_FISICA_EXTERIOR`.
5. **Tasa de Pluriempleo y Vinculación Docente (TPVD):** Proporción de graduados activos en la industria que ejercen simultáneamente cátedra universitaria (`DOCENCIA_CATEDRA`, Caso 5).

#### 5.2. Ciclo semestral de sostenibilidad (10 semanas) y meta-indicadores del sistema

* **Etapa 1 (Semana 1 - Semilla y Corte Macro):** Carga de nuevas actas de grado (`rol_custodio_identidad`) y corte agregado en *LinkedIn Alumni Tool*.
* **Etapa 2 (Semanas 2 a 4 - Campaña de Autogestión):** Envío de formulario institucional con autorización Ley 1581 a nuevos graduados y registros con vigencia $> 18$ meses.
* **Etapa 3 (Semanas 5 a 8 - Verificación Asistida y Homologación):** Evaluación S1-S4 y normalización CIIU/CUOC por estudiante auxiliar o analista curricular ($12\text{ h/semana}$, tope de $\le 50\text{ perfiles/día}$).
* **Etapa 4 (Semana 9 - Auditoría de Calidad):** Ejecución de `database/quality_checks.sql`, resolución de bandeja `QC-03` y validación muestral del $10\%$.
* **Etapa 5 (Semana 10 - Publicación Agregada):** Actualización de vistas con filtro $k \ge 5$ y cálculo de los cuatro **meta-indicadores de calidad del sistema**: *Tasa de Cobertura Verificada (TCV)*, *Índice de Frescura de Datos (IFD $\ge 80\%$)*, *Tasa de Resolución de Homologación (TRH $\ge 95\%$)* y *Tasa de Precisión Temporal (TPT)*.

---

## Parte II. Arquitectura de Base de Datos, Diccionario y Datos Sintéticos (Sección 3.2)

### 6. Justificación de PostgreSQL 14+ y Resumen de Tablas por Esquema

Se seleccionó **PostgreSQL 14+** sobre hojas de cálculo (Excel), archivos planos aislados o SQLite porque permite imponer integridad referencial estricta en relaciones $1:N$ (múltiples títulos y empleos por egresado), aislar esquemas con permisos granulares (`boveda_identidad` vs. `nucleo_analitico`), validar formatos mediante expresiones regulares en restricciones `CHECK` y ejecutar vistas analíticas auditablemente reproducibles.

| Esquema | Tabla / Vista | Llave Primaria | Propósito Técnico |
| :--- | :--- | :--- | :--- |
| `boveda_identidad` | `identidad_restringida` | `id_egresado` (`UUID`) | Resguarda el vínculo $1:1$ con `codigo_acta_hmac` (`CHAR(64) UNIQUE`) y `estado_autorizacion`. |
| `nucleo_analitico` | `perfiles_candidatos` | `candidato_id` (`VARCHAR(30)`) | Evalúa señales S1-S4 y retiene en cuarentena homónimos o perfiles incompletos (`chk_aislamiento_cuarentena`). |
| `nucleo_analitico` | `egresados` | `id_egresado` (`UUID`) | Tabla maestra seudonimizada de graduados confirmados (`ubicacion_residencia_id`, `estado_verificacion_id`, `cohorte_primera_titulacion`). |
| `nucleo_analitico` | `formacion_academica` | `id_formacion` (`INT`) | Títulos de pregrado y posgrado ($1:N$) vinculados a `cat_programa` (SNIES) y `cat_nivel_academico`. |
| `nucleo_analitico` | `experiencia_laboral` | `id_experiencia` (`INT`) | Historial laboral ($1:N$) con texto original, homologación CIIU/CUOC/Nivel, modalidad y precisión de fechas. |
| `nucleo_analitico` | `auditoria_trazabilidad` | `id_auditoria` (`INT`) | Registro de fuente primaria, timestamp de captura, nivel de confianza, completitud y rol verificador. |
| `catalogos` | `cat_programa`, `cat_nivel_academico`, `cat_ubicacion`, `cat_sector_economico`, `cat_empresa`, `cat_empresa_alias`, `cat_cargo_nivel`, `cat_area_desempeno`, `cat_estado_verificacion` | Llaves primarias tipadas (`INT` / `VARCHAR`) | Tablas maestras de referencia basadas en estándares oficiales SNIES, DANE CIIU Rev. 4 A.C., CUOC y DIVIPOLA / ISO 3166-1. |

*(El detalle columna por columna de tipos de datos, obligatoriedad y expresiones `CHECK` se encuentra en `docs/02_diccionario_y_catalogos.md` y en `database/schema.sql`).*

---

### 7. Demostración Funcional mediante los 8 Escenarios Sintéticos (`mock_data/`)

Todos los datos incluidos en el repositorio son **100 % sintéticos** (`es_dato_sintetico = TRUE`, `estado_autorizacion = 'DATO_SINTETICO_DEMO'`) y comprueban el comportamiento del modelo frente a casos reales y casos borde:

| Caso Sintético | ID en Base de Datos | Programa UNAL (SNIES) | Qué Demuestra en la Arquitectura |
| :--- | :--- | :--- | :--- |
| **Caso 1. Progresión completa ($1:N$)** | `550e8400-e29b-41d4-a716-446655440001` | Ing. de Sistemas (`19`) + Maestría Ing. Sistemas (`16927`) | Relación $1:N$ en formación (2 títulos) y experiencia (3 cargos sucesivos: Practicante $\rightarrow$ Junior $\rightarrow$ Senior) con cálculo exacto de meses. |
| **Caso 2. Movilidad remota internacional** | `550e8400-e29b-41d4-a716-446655440002` | Ing. Electrónica (`16`) | Reside en Bogotá (`11001`) y trabaja en modalidad `REMOTO` para empresa en EE. UU. (`84001`), clasificado como `EXPORTACION_SERVICIOS_REMOTO`. |
| **Caso 3. Fecha con precisión anual** | `550e8400-e29b-41d4-a716-446655440003` | Ing. Civil (`13`) | Registra `fecha_inicio = '2021-01-01'` con `precision_fecha = 'ANUAL'`; activa `QC-02` y evita sesgar promedios mensuales (`meses_duracion_verificados = NULL`). |
| **Caso 4. Cargo ambiguo sin homologar** | `550e8400-e29b-41d4-a716-446655440004` | Ing. Industrial (`17`) | Conserva `cargo_original = 'Ninja de Ecosistemas & Growth Hacker'`, mantiene clasificadores en `NULL` y activa la bandeja `QC-03`. |
| **Caso 5. Pluriempleo actual legítimo** | `550e8400-e29b-41d4-a716-446655440005` | Ing. Mecánica (`18`) | Dos empleos con `es_actual = TRUE` (`ROL_PRINCIPAL` en industria + `DOCENCIA_CATEDRA` en educación), validado por `QC-06`. |
| **Caso 6. Transición a sector no afín** | `550e8400-e29b-41d4-a716-446655440006` | Ing. Química (`20`) | Ejerce en `COMERCIAL_VENTAS` (`es_nucleo_ingenieria = FALSE`) en comercio minorista (`G47`), permitiendo medir la Tasa de Afinidad Curricular. |
| **Caso 7. Homonimia en cuarentena** | `CAND-SINT-0007` | Ing. Eléctrica (`15`, inferido) | Retenido en `perfiles_candidatos` (`CUARENTENA_HOMONIMIA`, 2 homónimos en acta y sin año S4); bloqueado por `chk_aislamiento_cuarentena` y detectado por `QC-01`. |
| **Caso 8. Registro desactualizado** | `550e8400-e29b-41d4-a716-446655440008` | Ing. Agrícola (`12`) | Última captura en `2024-05-10` ($906$ días de antigüedad) aún como practicante desde 2017; detectado por `QC-04` (`OBSERVACION_OBSOLETO`). |
