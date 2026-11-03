# Metodología para la Consolidación, Gobernanza y Análisis de Información Profesional de Egresados a partir de LinkedIn

**Entidad:** Facultad de Ingeniería — Universidad Nacional de Colombia  
**Alcance:** Diseño metodológico de identificación, recolección, depuración, estandarización, calidad, protección de datos personales, indicadores e implementación sostenible.

---

## 1. Estrategia de Identificación de Egresados y Resolución de Identidad

### 1.1. Principio rector: Búsqueda guiada por semilla institucional

Buscar perfiles "a ciegas" en LinkedIn a partir de palabras clave genéricas produce altas tasas de falsos positivos, homonimias y sesgos de selección. Por ello, el proceso parte siempre de una **población semilla determinista**: el registro oficial de graduados de la Facultad de Ingeniería (Actas de Grado y Sistema de Información Académica).

Como fuentes complementarias legítimas se integran:

1. **Portal institucional de egresados y campañas de autogestión:** Formularios institucionales de actualización donde el graduado aporta directamente su URL de LinkedIn y suscribe la autorización de tratamiento de datos personales.
2. **Encuestas institucionales de seguimiento (Momento Cero / Observatorio Laboral para la Educación - OLE):** Cruce interno para validar cohorte de grado y primer contacto laboral.
3. **Directorios públicos de consejos profesionales (ej. COPNIA):** Consulta pública de vigencia de matrícula profesional únicamente como señal secundaria de desempate ante casos de homonimia.

### 1.2. Protocolo de localización de perfiles

Para minimizar el consumo de cuotas de búsqueda dentro de sesiones autenticadas de LinkedIn y respetar los límites operativos de la plataforma, la localización se ejecuta combinando consultas estructuradas en motores de búsqueda externos indexados (Google / Bing) y el buscador nativo o *LinkedIn Alumni Tool* mediante operadores booleanos con señales ancla:

> `site:[linkedin.com/in/](https://linkedin.com/in/) "Nombre Apellido" ("Universidad Nacional de Colombia" OR "UNAL") ("Facultad de Ingeniería" OR "Ingeniería de Sistemas" OR "Ingeniería Civil")`

### 1.3. Matriz de señales de verificación académica (S1 a S4)

Encontrar un perfil con un nombre coincidente nunca equivale a confirmar la identidad de un egresado. Todo perfil candidato se registra inicialmente en la entidad `nucleo_analitico.perfiles_candidatos` y se evalúa frente a cuatro señales objetivas contra el acta oficial de grado:

* **Señal S1 (Nombre normalizado):** Coincidencia de nombres y dos apellidos, o primer nombre, primer apellido e inicial/segundo apellido compatible.
* **Señal S2 (Institución educativa):** Mención explícita de la Universidad Nacional de Colombia y/o Facultad de Ingeniería en la sección de educación.
* **Señal S3 (Programa curricular):** Correspondencia exacta o equivalencia semántica unívoca con el catálogo oficial de programas SNIES de la Facultad (`catalogos.cat_programa`).
* **Señal S4 (Cohorte temporal):** Año de grado o finalización reportado en LinkedIn dentro de una ventana de tolerancia de $\pm 1$ año respecto al acta de grado oficial (absorbe el desfase habitual entre terminación de materias y ceremonia de graduación).

### 1.4. Tratamiento de homónimos, perfiles incompletos y niveles de confianza

Cuando existen dos o más graduados reales en las actas de la Facultad con el mismo nombre y apellido (`conteo_homonimos_acta >= 2`) y el perfil de LinkedIn carece de año de grado (S4 ausente) o ambos homónimos pertenecen a una ventana temporal superpuesta, el sistema declara **colisión de homonimia** (`S1+S2+S3_SIN_S4_HOMONIMO`).

* **Desempate por señales secundarias:** Se verifica si el perfil menciona el título del trabajo de grado/tesis, participación en grupos de investigación registrados o validación desde el correo institucional.
* **Aislamiento en cuarentena:** Si la correspondencia no puede comprobarse de forma indubitable, **se prohíbe forzar la asignación**. El registro permanece en `nucleo_analitico.perfiles_candidatos` con `estado_candidato = 'CUARENTENA_HOMONIMIA'` e `id_egresado_confirmado = NULL`, impidiendo por restricción física (`chk_aislamiento_cuarentena`) que ingrese a la población confirmada (`nucleo_analitico.egresados`).

| Nivel de Confianza | Combinación de Señales | Estado en `perfiles_candidatos` | Destino en `egresados` | Uso permitido en indicadores |
| :--- | :--- | :--- | :--- | :--- |
| **ALTO** | Autogestión autenticada del egresado o coincidencia `S1+S2+S3+S4` sin colisión de homónimos. | `VINCULADO_CONFIRMADO` | `VERIFICADO_ALTA` | Apto para la totalidad de indicadores longitudinales, sectoriales y de inserción. |
| **MEDIO** | Coincidencia `S1+S2+S3` sin fecha exacta (`S4` ausente o desfase $\pm 2$ años), con `conteo_homonimos_acta = 1`. | `VINCULADO_CONFIRMADO` | `VERIFICADO_MEDIA` | Apto para distribución por sector económico, área y movilidad; excluido de tiempos exactos de inserción si carece de mes. |
| **BAJO** | Colisión de homonimia sin desempate (`S1+S2+S3_SIN_S4_HOMONIMO`) o coincidencia parcial (`S1+S2_PARCIAL`). | `CUARENTENA_HOMONIMIA` / `CUARENTENA_DATOS_INSUFICIENTES` | **No ingresa** (`id_egresado_confirmado IS NULL`) | **Excluido totalmente** de las vistas analíticas e indicadores oficiales. |
| **DESCARTADO** | Evidencia de que pertenece a otra institución u otra facultad homónima. | `DESCARTADO_NO_EGRESADO` | **No ingresa** | Excluido; se conserva la referencia para evitar reevaluación en barridos futuros. |

---

## 2. Definición y Clasificación Estratégica de Variables (Minimización de Datos)

En cumplimiento del principio de minimización de datos personales (Ley 1581 de 2012), la arquitectura rechaza recolectar información simplemente porque sea visible en un perfil web. Las variables posibles se clasifican en cuatro categorías estrictas:

### 2.1. Matriz de pertinencia y minimización

1. **Información indispensable (Núcleo obligatorio):** Identificador interno seudonimizado (`id_egresado` UUID), referencia protegida del acta (`codigo_acta_hmac`), estado de autorización legal (`estado_autorizacion`), programa curricular (`programa_id`), nivel académico (`nivel_academico_id`), año de grado (`anio_grado`), organización empleadora original y normalizada (`empresa_texto_original`, `empresa_id`), sector económico CIIU (`sector_economico_id`), cargo original y nivel jerárquico (`cargo_original`, `cargo_nivel_id`), área funcional (`area_desempeno_id`), indicador de vigencia del empleo (`es_actual`) y metadatos de auditoría (`fuente_primaria`, `fecha_captura`, `nivel_confianza`).
2. **Información útil (Opcional con alto valor analítico):** Fechas de inicio y fin de cada experiencia (`fecha_inicio`, `fecha_fin`) acompañadas de su indicador de exactitud (`precision_fecha`), modalidad de trabajo (`modalidad_trabajo`: presencial, remoto, híbrido), tipo de rol (`tipo_vinculacion_rol`: rol principal, docencia cátedra, consultoría, práctica), tamaño de empresa (`tamano_empresa`) y triple dimensión geográfica (residencia del egresado, ubicación del puesto y país sede de la empresa).
3. **Información prescindible (Excluida por ruido analítico y costo operativo):** Listados abiertos de aptitudes (*skills* autodeclarados sin validación estandarizada), texto biográfico libre (*"Acerca de"*), publicaciones o comentarios en el *feed*, certificaciones cortas no conducentes a título y premios no académicos.
4. **Información inconveniente o prohibida (Recolección bloqueada):** Fotografía del perfil (dato biométrico sensible), fecha de nacimiento o edad exacta, estado civil, dirección de domicilio, teléfono o correo personal privado, afiliaciones políticas, religiosas o sindicales, e inferencias de salud a partir de lagunas laborales.

*(La especificación detallada de tipos de datos, dominios, obligatoriedad y reglas de validación de cada variable se encuentra en `docs/02_diccionario_y_catalogos.md`).*

---

## 3. Procedimiento de Recolección, Depuración y Consolidación

### 3.1. Inviabilidad legal y técnica del *web scraping* y de la API para enriquecimiento masivo

Un diagnóstico riguroso del ecosistema de LinkedIn demuestra que basar el seguimiento institucional en *bots* de extracción (*web scraping*) o extensiones de navegador es inviable por tres razones probadas:

* **Prohibición contractual expresa:** La Sección 8.2 (numerales 2, 3, 4 y 13) del Contrato de Licencia de LinkedIn prohíbe desarrollar o utilizar *crawlers*, scripts, plugins o métodos automatizados para copiar perfiles, así como distribuir datos sin consentimiento.
* **Jurisprudencia aplicable:** El fallo definitivo de *hiQ Labs v. LinkedIn* (2022) confirmó la responsabilidad civil por incumplimiento contractual en extracciones autenticadas, obligando a la destrucción de los datos extraídos. Por su parte, la defensa de *logged-out scraping* (*Meta v. Bright Data*, 2024) resulta inaplicable en LinkedIn porque la visualización de trayectorias educativas y laborales completas exige sesión autenticada.
* **Restricciones de la API oficial y defensas técnicas:** Los términos de uso de las APIs de LinkedIn prohíben expresamente el enriquecimiento de bases de datos internas (*Data Enrichment*) e imponen límites de almacenamiento en caché de 24 a 48 horas para perfiles de terceros. Además, la plataforma audita firmas criptográficas TLS y escanea extensiones en el DOM, bloqueando las cuentas institucionales infractoras.

### 3.2. Arquitectura de recolección lícita en dos velocidades

Para garantizar viabilidad operativa inmediata sin vulnerar normas legales ni contractuales, la recolección opera en dos niveles complementarios:

1. **Nivel Macro (Cobertura agregada inmediata mediante *LinkedIn Alumni Tool*):** La Facultad utiliza el panel oficial de exalumnos de la página institucional de la Universidad en LinkedIn para registrar cortes semestrales agregados (distribución global por empleador, sector industrial, ubicación y área funcional filtrada por programa y cohorte). Este canal es 100 % nativo, legal y anónimo, sirviendo además como línea base para calibrar sesgos de cobertura.
2. **Nivel Micro (Trayectorias longitudinales en la base de datos relacional):** Se alimenta mediante tres canales trazables registrados en `fuente_primaria`:
   * `AUTOGESTION_EGRESADO`: Campaña semestral donde el graduado actualiza sus datos y autoriza el tratamiento conforme a la Ley 1581 de 2012.
   * `CRUCE_INSTITUCIONAL_OLE`: Integración de registros con consentimiento institucional previo obtenidos al momento del grado.
   * `VERIFICACION_ASISTIDA_LINKEDIN`: Consulta puntual y estructurada por analistas humanos (bajo un tope estricto de $\le 50$ verificaciones manuales por jornada sin plugins ni automatización) para alimentar análisis estadísticos disociados de la identidad personal.

### 3.3. Reglas de depuración, deduplicación y homologación en dos capas

* **Normalización y alias de empresas:** Los nombres de empleadores reportados en texto libre se conservan en `empresa_texto_original` para trazabilidad. Para su consolidación, se transforman a mayúsculas, se eliminan tildes y sufijos societarios (`S.A.S.`, `S.A.`, `LTDA.`, `INC.`) y se cruzan contra la tabla puente `catalogos.cat_empresa_alias` para asignar un único `empresa_id` canónico vinculado a su división CIIU Rev. 4 A.C.
* **Homologación de cargos sin pérdida del dato crudo:** Nunca se sobrescribe el título del puesto declarado por el egresado (`cargo_original`). Un proceso de homologación en dos capas mapea expresiones regulares hacia el nivel jerárquico (`cargo_nivel_id`) y el área funcional CUOC (`area_desempeno_id`). Cuando un cargo es ambiguo, ambos clasificadores permanecen legítimamente en `NULL` y el registro se marca con `estado_homologacion = 'PENDIENTE_HOMOLOGACION'` para revisión asistida, sin insertar códigos numéricos ficticios como `0` o `99`.
* **Prevención de duplicados en tres niveles:**
  1. *Nivel de identidad institucional:* La columna `codigo_acta_hmac` (`UNIQUE`) en `boveda_identidad.identidad_restringida` impide registrar dos veces al mismo graduado aunque cambie el enlace de su perfil.
  2. *Nivel de formación académica:* La restricción `uq_egresado_programa_anio` (`UNIQUE (id_egresado, programa_id, anio_grado)`) evita duplicar títulos del mismo programa y cohorte.
  3. *Nivel de experiencia laboral:* La restricción `uq_experiencia_no_duplicada` (`UNIQUE (id_egresado, empresa_texto_original, cargo_original, fecha_inicio)`) bloquea cargas repetidas del mismo puesto permitiendo simultáneamente ascensos reales dentro de la misma organización (Caso 1).

---

## 4. Control de Calidad, Casos Límite y Trazabilidad

Cada dato relevante almacenado en el núcleo analítico permite responder cuatro preguntas de auditoría a través de las tablas `nucleo_analitico.auditoria_trazabilidad` y `nucleo_analitico.perfiles_candidatos`: **de dónde salió** (`fuente_primaria` y `perfil_origen_ref`), **cuándo se consultó** (`fecha_captura`), **cómo se verificó** (`senales_coincidentes` y `rol_verificador`) y **qué nivel de confianza y completitud posee** (`nivel_confianza` y `estado_completitud`).

### 4.1. Matriz determinista de tratamiento de anomalías y casos límite

| Caso límite / Anomalía | Mecanismo de detección en PostgreSQL (`schema.sql` / `quality_checks.sql`) | Decisión de tratamiento y efecto en los indicadores |
| :--- | :--- | :--- |
| **1. Homonimia sin resolver o identidad no comprobable** | Señal `S1+S2+S3_SIN_S4_HOMONIMO` con `conteo_homonimos_acta >= 2`. Detectado por regla `QC-01_CUARENTENA_IDENTIDAD` y bloqueado por `chk_aislamiento_cuarentena`. | Permanece en `perfiles_candidatos` con `estado_candidato = 'CUARENTENA_HOMONIMIA'` e `id_egresado_confirmado = NULL`. No ingresa a `egresados` ni contamina estadísticas (Caso 7). |
| **2. Fechas laborales incompletas (solo año o sin fecha)** | Validación `chk_precision_fecha_consistente` y regla `QC-02_FECHA_PRECISION_LIMITADA`. | Si solo se conoce el año, se registra `YYYY-01-01` con `precision_fecha = 'ANUAL'`. La vista `vw_experiencias_analitica` devuelve `meses_duracion_verificados = NULL` para no sesgar promedios de duración (Caso 3). |
| **3. Cargos ambiguos o creativos** | `estado_homologacion = 'PENDIENTE_HOMOLOGACION'` con `cargo_nivel_id IS NULL` o `area_desempeno_id IS NULL`. Detectado por `QC-03_HOMOLOGACION_PENDIENTE`. | Se preserva `cargo_original` intacto y el registro pasa a bandeja de supervisión humana sin bloquear la ingesta del resto de la experiencia (Caso 4). |
| **4. Registros desactualizados u obsoletos** | `fecha_captura` con antigüedad $> 18$ meses o cargo de nivel `'PRACTICANTE'` vigente por $> 24$ meses. Detectado por `QC-04_OBSOLESCENCIA_CRONOLOGICA`. | Se marca `OBSERVACION_OBSOLETO` en `egresados` y se prioriza para actualización semestral, excluyéndolo de cortes de coyuntura actual (Caso 8). |
| **5. Múltiples empleos actuales simultáneos** | Evaluación conjunta de `es_actual = TRUE` y `tipo_vinculacion_rol` mediante las reglas `QC-05` y `QC-06`. | Si combina un `ROL_PRINCIPAL` con `DOCENCIA_CATEDRA` o `CONSULTORIA_PARALELA`, se valida como pluriempleo legítimo (`QC-06`, Caso 5). Solo si registra $> 1$ `ROL_PRINCIPAL` activo simultáneo se emite alerta de posible olvido de cierre de fecha (`QC-05`). |
| **6. Contradicciones cronológicas duras** | `fecha_fin < fecha_inicio` o `es_actual = TRUE` con `fecha_fin IS NOT NULL`. | **Error bloqueante:** Las restricciones `chk_fechas_coherentes` y `chk_empleo_actual_abierto` impiden la inserción hasta corregir el dato en origen. |

---

## 5. Protección de Datos Personales, Privacidad y Anonimidad

### 5.1. Marco normativo colombiano y diferenciación entre obligaciones legales y buenas prácticas

| Dimensión | Norma / Fuente Oficial | Carácter | Aplicación concreta en la arquitectura |
| :--- | :--- | :--- | :--- |
| **Naturaleza semiprivada del dato profesional** | Ley Estatutaria 1581 de 2012 (Art. 3) y Doctrina SIC (Concepto 16-172268; Guía para el Contexto Universitario). | **Obligación Legal** | La trayectoria académica y laboral visible en redes sociales no es un "dato público" de libre tratamiento; es un **dato semiprivado** que requiere finalidad legítima y autorización o anonimización estadística. |
| **Principios de Libertad, Finalidad y Minimización** | Ley 1581 de 2012 (Arts. 4 y 9) y Decreto Único Reglamentario 1074 de 2015. | **Obligación Legal** | Recolección exclusiva de variables curriculares y laborales pertinentes; registro explícito de `estado_autorizacion` en la bóveda restringida. |
| **Responsabilidad Demostrada (Accountability)** | Decreto 1074 de 2015 y lineamientos SIC para Instituciones de Educación Superior. | **Obligación Legal** | Trazabilidad completa de fuentes, control de acceso por roles, inscripción en el RNBD e implementación de procedimiento de supresión/revocatoria. |
| **No extracción automatizada (*No-Scraping*)** | Contrato de Licencia de LinkedIn (Sección 8.2, numerales 2, 3, 4 y 13). | **Obligación Contractual** | Prohibición de *crawlers*, bots y plugins; uso exclusivo de autogestión, cruces internos, *Alumni Tool* y verificación humana acotada. |
| **Partición lógica/física y código HMAC** | Ingeniería de Privacidad por Diseño (*Privacy by Design*). | **Buena Práctica Técnica** | Separación entre `boveda_identidad` y `nucleo_analitico`; sustitución del documento de identidad por `codigo_acta_hmac` (HMAC-SHA256 con llave institucional secreta sobre el número de acta, evitando hashear cédulas predecibles). |
| **Reserva estadística ($k$-anonimato con $k \ge 5$)** | Estándar de control de revelación estadística. | **Buena Práctica Técnica** | Ninguna vista pública ni tablero institucional expone celdas o cruces con menos de 5 egresados (`HAVING COUNT(DISTINCT id_egresado) >= 5`), evitando la reidentificación por efecto mosaico. |

### 5.2. Diferencia operativa entre seudonimización y anonimización

* **Capa operativa interna (`nucleo_analitico`): Seudonimizada.** Los registros utilizan el identificador subrogado `id_egresado` (UUID v4) sin nombres, cédulas ni URLs directas. Esto protege la identidad frente a los analistas de datos, pero mantiene la trazabilidad controlada con `boveda_identidad` para poder actualizar longitudinalmente al mismo egresado en barridos posteriores sin duplicarlo.
* **Capa de publicación y consulta institucional: Anonimizada y agregada.** Los directivos, comités curriculares y pares evaluadores de acreditación consumen exclusivamente indicadores agregados (tasas, distribuciones porcentuales y medianas con $k \ge 5$) donde el vínculo con cualquier individuo queda irreversiblemente disociado.

---

## 6. Análisis e Indicadores Institucionales

La Facultad puede responder preguntas estratégicas de acreditación y reforma curricular combinando las vistas del esquema `nucleo_analitico`:

| Indicador Institucional | Pregunta que responde | Variables utilizadas en el modelo | Limitaciones y sesgos inherentes | Mitigación metodológica |
| :--- | :--- | :--- | :--- | :--- |
| **1. Tasa de Afinidad Curricular (TAC)** | ¿Qué proporción de egresados ejerce en roles propios del núcleo de ingeniería frente a transiciones hacia otros sectores (Caso 6)? | `formacion_academica.programa_id`, `experiencia_laboral.area_desempeno_id`, `cat_area_desempeno.es_nucleo_ingenieria`, `es_actual = TRUE`. | Roles directivos o gerenciales pueden clasificarse fuera del área técnica aunque dirijan empresas de ingeniería. | Analizar conjuntamente `es_nucleo_ingenieria` con la división CIIU (`sector_economico_id`) y excluir registros con `estado_homologacion = 'PENDIENTE_HOMOLOGACION'` (Caso 4). |
| **2. Distribución Sectorial de Empleabilidad (DSE)** | ¿Qué sectores económicos (CIIU Rev. 4) absorben a los graduados de cada programa curricular? | `programa_id`, `experiencia_laboral.sector_economico_id`, `cat_sector_economico.nombre_sector`, `es_actual = TRUE`. | **Sesgo de cobertura en LinkedIn:** Sobrerrepresentación de servicios TI, consultoría y banca frente a obra civil regional o agroindustria. | Reportar cada distribución acompañada de la **Tasa de Cobertura Verificada (TCV)** de la cohorte respecto al total de graduados en actas oficiales. |
| **3. Tiempo de Transición y Progresión Jerárquica (TPJ)** | ¿Cuántos meses toma escalar de niveles Junior a Senior o Líder (Caso 1)? | `id_egresado`, secuencia de `cargo_nivel_id` (`orden_seniority`), `fecha_inicio`, `fecha_fin`, `precision_fecha`. | Perfiles que solo reportan el año de inicio distorsionarían el cálculo en meses si se trataran como fechas exactas. | Utilizar exclusivamente la columna calculada `meses_duracion_verificados` de `vw_experiencias_analitica`, que filtra `precision_fecha = 'EXACTA_MENSUAL'` (protege contra el Caso 3). |
| **4. Índice de Movilidad Internacional y Exportación de Servicios (IMIES)** | ¿Cuántos egresados han emigrado físicamente frente a cuántos trabajan remotamente desde Colombia para empresas en el exterior (Caso 2)? | `egresados.ubicacion_residencia_id`, `experiencia_laboral.ubicacion_empleo_id`, `cat_empresa.ubicacion_sede_id`, `modalidad_trabajo`. | Algunos usuarios registran en su encabezado la ciudad de la empresa matriz extranjera aunque residan en Colombia. | Aplicar la regla de tres dimensiones geográficas implementada en `vw_experiencias_analitica` (`EXPORTACION_SERVICIOS_REMOTO` vs. `EMIGRACION_FISICA_EXTERIOR` vs. `MERCADO_NACIONAL_LOCAL`). |
| **5. Tasa de Pluriempleo y Vinculación Docente (TPVD)** | ¿Qué porcentaje de egresados en la industria participa simultáneamente en docencia universitaria o investigación (Caso 5)? | `id_egresado`, `es_actual = TRUE`, `tipo_vinculacion_rol IN ('ROL_PRINCIPAL', 'DOCENCIA_CATEDRA')`. | El olvido de cierre de un empleo antiguo puede simular pluriempleo falso. | Filtrar mediante las reglas de calidad `QC-05` y `QC-06`, aceptando solo combinaciones compatibles verificadas. |

---

## 7. Plan de Implementación y Sostenibilidad Operativa

Para asegurar que el proceso sea reproducible y mantenible por la Facultad sin depender de quien lo diseñó, se establece un **ciclo operativo semestral de 10 semanas** sincronizado con las ceremonias de grados:

### 7.1. Etapas, actividades, responsables y recursos

| Etapa del Ciclo Semestral | Actividades Principales | Rol Responsable | Recursos y Herramientas |
| :--- | :--- | :--- | :--- |
| **Etapa 1: Semilla y Corte Macro (Semana 1)** | 1. Cierre de actas de nuevos graduados y generación de `id_egresado` + `codigo_acta_hmac`; 2. Captura de distribución agregada en *LinkedIn Alumni Tool*. | Coordinador(a) Oficina de Egresados (`rol_custodio_identidad`). | Sistema académico oficial, llave HMAC institucional y acceso administrador a Página Universitaria en LinkedIn. |
| **Etapa 2: Campaña de Autogestión (Semanas 2 a 4)** | Envío de boletín institucional a graduados recientes e históricos con captura vencida ($> 18$ meses) para actualización voluntaria y firma de consentimiento Ley 1581. | Comunicaciones Facultad + Auxiliar Administrativo. | Formulario institucional autenticado e infraestructura de correo masivo. |
| **Etapa 3: Verificación Asistida y Homologación (Semanas 5 a 8)** | 1. Evaluación de señales S1-S4 en `perfiles_candidatos`; 2. Homologación de nuevos empleadores (Regla de Pareto 80/20 con RUES/CIIU) y cargos. | Estudiante Auxiliar de Ingeniería / Analista de Datos (12 h/semana, `rol_analista_curricular`). | Base PostgreSQL 14+, diccionarios SQL/CSV y protocolo de consulta manual ($\le 50$ perfiles/día). |
| **Etapa 4: Control de Calidad y Desempate (Semana 9)** | Ejecución de `database/quality_checks.sql`, resolución de bandeja `QC-03` (cargos ambiguos) y auditoría del 10 % de registros confirmados. | Líder de Calidad Curricular / Comité de Egresados. | Vistas `vw_reporte_calidad_datos` y consulta secundaria en repositorios de tesis / COPNIA. |
| **Etapa 5: Publicación Agregada (Semana 10)** | Generación de vistas agregadas con reserva estadística ($k \ge 5$) y entrega de boletín de indicadores por programa curricular. | Dirección Académica / Analista BI (`rol_lector_indicadores`). | Tablero institucional conectado exclusivamente a vistas agregadas. |

### 7.2. Sostenibilidad del catálogo de empresas (Regla de Pareto 80/20)

Para evitar que el equipo operativo colapse clasificando miles de razones sociales, se aplica una regla 80/20: las ~200 empresas empleadoras más frecuentes de ingenieros en Colombia se mantienen precargadas en `catalogos.cat_empresa` con su código CIIU oficial verificado en el RUES; para empresas nuevas o extranjeras de cola larga, se registra el nombre original en `empresa_texto_original` y se asigna directamente el `sector_economico_id` en `experiencia_laboral` a partir de una tabla de equivalencias entre las categorías estándar de industria de LinkedIn y las divisiones CIIU Rev. 4 A.C.

### 7.3. Indicadores de calidad del propio sistema (Meta-indicadores de gobernanza)

1. **Tasa de Cobertura Verificada (TCV):** $\text{TCV} = \frac{\text{Egresados en estado VERIFICADO\_ALTA o VERIFICADO\_MEDIA}}{\text{Total de Graduados en Actas Oficiales de la Cohorte}} \times 100$.
2. **Índice de Frescura de Datos (IFD):** Porcentaje de egresados confirmados cuya última `fecha_captura` en `auditoria_trazabilidad` tiene menos de 18 meses (Meta: $\ge 80\%$, monitoreado por `QC-04`).
3. **Tasa de Resolución de Homologación (TRH):** Porcentaje de registros en `experiencia_laboral` con `estado_homologacion = 'HOMOLOGADO'` (Meta: $\ge 95\%$, monitoreado por `QC-03`).
4. **Tasa de Precisión Temporal (TPT):** Porcentaje de experiencias laborales con `precision_fecha = 'EXACTA_MENSUAL'` aptas para indicadores de duración (monitoreado por `QC-02`).

---

## 8. Referencias Normativas y Técnicas

1. **Congreso de la República de Colombia (2012).** *Ley Estatutaria 1581 de 2012*, "Por la cual se dictan disposiciones generales para la protección de datos personales" (Arts. 3, 4, 6 y 9).
2. **Presidencia de la República de Colombia (2015).** *Decreto Único Reglamentario 1074 de 2015* (Capítulos 25 y 26), sobre autorización del titular, responsabilidad demostrada y tratamiento con fines estadísticos, históricos o científicos.
3. **Superintendencia de Industria y Comercio - SIC (2016 / 2024).** *Concepto 16-172268* sobre recolección de datos personales en redes sociales y *Guía para el tratamiento de datos personales en el contexto universitario*.
4. **LinkedIn Corporation (2025).** *Condiciones de Uso (User Agreement)*, Sección 8.2 ("Qué no hacer", numerales 2, 3, 4 y 13) y *Marketing/Developer API Terms of Use - Data Storage Requirements & Restricted Use Cases*.
5. **Jurisprudencia Internacional sobre Extracción de Datos:** *hiQ Labs, Inc. v. LinkedIn Corp.*, 31 F.4th 1180 (9th Cir. 2022) y *Stipulated Final Judgment* (N.D. Cal. Dec. 2022); *Meta Platforms, Inc. v. Bright Data Ltd.*, No. 3:23-cv-00077 (N.D. Cal. Jan. 2024).
6. **Estándares Oficiales de Clasificación en Colombia:** DANE *CIIU Rev. 4 A.C.* (Sectores económicos), DANE/OIT *CUOC / CIUO-08* (Áreas ocupacionales), DANE *DIVIPOLA* + *ISO 3166-1 alpha-2* (Ubicaciones geográficas) y Ministerio de Educación Nacional *SNIES* (Programas curriculares).
