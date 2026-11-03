# Sistema de Seguimiento a Egresados a partir de LinkedIn — Metodología, Gobernanza y Arquitectura de Datos

Propuesta metodológica e implementación de arquitectura relacional en **PostgreSQL 14+** para la identificación, recolección lícita, depuración, estandarización, control de calidad y análisis de trayectorias profesionales de egresados de la **Facultad de Ingeniería**.

---

## 1. Matriz de Cumplimiento de Requisitos de la Convocatoria

Para facilitar la revisión del comité evaluador, esta tabla vincula cada requisito de las secciones **3.1**, **3.2** y **3.3** de la guía técnica con el artefacto exacto del repositorio que lo resuelve[cite: 7, 8]:

| Sección de la Guía | Requisito Evaluado | Archivo y Ubicación Exacta en este Repositorio |
| :--- | :--- | :--- |
| **3.1.1. Identificación de egresados** | Estrategia de búsqueda por semilla institucional, matriz de señales (S1-S4), manejo de homónimos y niveles de confianza[cite: 7, 8]. | [`docs/01_documento_metodologico.md` (Sección 1)](docs/01_documento_metodologico.md) y tabla `nucleo_analitico.perfiles_candidatos` en [`database/schema.sql`](database/schema.sql). |
| **3.1.2. Definición de variables** | Principio de minimización (indispensables, útiles, prescindibles y prohibidas), justificación y reglas de registro[cite: 7, 8]. | [`docs/01_documento_metodologico.md` (Sección 2)](docs/01_documento_metodologico.md) y [`docs/02_diccionario_y_catalogos.md` (Sección 2)](docs/02_diccionario_y_catalogos.md). |
| **3.1.3. Recolección y consolidación** | Recolección lícita en dos velocidades (*Alumni Tool* + autogestión/verificación asistida), deduplicación y homologación en dos capas[cite: 6, 7, 8]. | [`docs/01_documento_metodologico.md` (Sección 3)](docs/01_documento_metodologico.md) y [`database/catalogos.sql`](database/catalogos.sql). |
| **3.1.4. Calidad y trazabilidad** | Reglas deterministas para fechas incompletas, cargos ambiguos, datos obsoletos, pluriempleo e información no verificable[cite: 7, 8]. | [`docs/01_documento_metodologico.md` (Sección 4)](docs/01_documento_metodologico.md) y reglas `QC-01` a `QC-06` en [`database/quality_checks.sql`](database/quality_checks.sql). |
| **3.1.5. Protección de datos** | Cumplimiento de Ley 1581 de 2012, Doctrina SIC, Sección 8.2 de LinkedIn, separación de bóveda PII, seudonimización y $k$-anonimato ($k \ge 5$)[cite: 3, 6, 7, 8]. | [`docs/01_documento_metodologico.md` (Sección 5)](docs/01_documento_metodologico.md) y esquema `boveda_identidad` en [`database/schema.sql`](database/schema.sql). |
| **3.1.6. Análisis e indicadores** | Indicadores de afinidad curricular, sectores CIIU, progresión jerárquica, movilidad remota internacional y control de sesgos[cite: 7, 8]. | [`docs/01_documento_metodologico.md` (Sección 6)](docs/01_documento_metodologico.md) y vistas en [`database/quality_checks.sql`](database/quality_checks.sql). |
| **3.1.7. Implementación sostenible** | Ciclo operativo semestral en 10 semanas, responsables, recursos, regla 80/20 de empleadores y meta-indicadores (TCV, IFD, TRH, TPT). | [`docs/01_documento_metodologico.md` (Sección 7)](docs/01_documento_metodologico.md). |
| **3.2.1. Estructura de Base de Datos** | Justificación de PostgreSQL 14+, diccionario de datos, llaves (`UUID`, PK, FK, UK), catálogos (SNIES, CIIU, CUOC, DIVIPOLA) y controles SQL[cite: 7, 8]. | [`docs/02_diccionario_y_catalogos.md`](docs/02_diccionario_y_catalogos.md), [`database/schema.sql`](database/schema.sql) y [`database/catalogos.sql`](database/catalogos.sql). |
| **3.2.2. Datos de prueba (Mock Data)** | 8 escenarios 100 % sintéticos que comprueban relaciones $1:N$, movilidad remota, fechas anuales, cargos ambiguos, pluriempleo, cuarentena por homonimia y obsolescencia[cite: 7, 8]. | [`mock_data/README.md`](mock_data/README.md), archivos [`mock_data/*.csv`](mock_data/) y [`database/load_mock_data.sql`](database/load_mock_data.sql). |

---

## 2. Arquitectura de la Solución y Modelo Entidad-Relación

La solución rechaza el *web scraping* automatizado (prohibido por la Sección 8.2 de las Condiciones de Uso de LinkedIn y riesgoso frente a la Ley Estatutaria 1581 de 2012) e implementa una arquitectura relacional normalizada (3FN) dividida en tres esquemas en **PostgreSQL 14+**:

1. **`boveda_identidad`**: Custodia restringida de la relación entre el `id_egresado` (`UUID`) y el código `HMAC-SHA256` del acta de grado, junto con el estado de autorización legal[cite: 7].
2. **`nucleo_analitico`**: Entorno seudonimizado que aisla candidatos en cuarentena (`perfiles_candidatos`) de los graduados confirmados (`egresados`, `formacion_academica`, `experiencia_laboral` y `auditoria_trazabilidad`)[cite: 5, 7].
3. **`catalogos`**: Nomenclaturas oficiales verificadas (SNIES, DANE CIIU Rev. 4 A.C., CUOC/CIUO-08, DIVIPOLA e ISO 3166-1).

```mermaid
erDiagram
    IDENTIDAD_RESTRINGIDA ||--|| EGRESADOS : "seudonimiza (1:1)"
    EGRESADOS ||--o| PERFILES_CANDIDATOS : "origen_verificado (0:1)"
    EGRESADOS ||--|{ FORMACION_ACADEMICA : "acredita (1:N)"
    EGRESADOS ||--o{ EXPERIENCIA_LABORAL : "desempena (1:N)"
    EGRESADOS ||--|{ AUDITORIA_TRAZABILIDAD : "audita (1:N)"

    CAT_UBICACION ||--o{ EGRESADOS : "residencia"
    CAT_UBICACION ||--o{ EXPERIENCIA_LABORAL : "ubicacion_puesto"
    CAT_UBICACION ||--o{ CAT_EMPRESA : "sede_matriz"
    CAT_ESTADO_VERIFICACION ||--o{ EGRESADOS : "clasifica_estado"
    CAT_PROGRAMA ||--o{ FORMACION_ACADEMICA : "programa_confirmado"
    CAT_PROGRAMA ||--o{ PERFILES_CANDIDATOS : "programa_inferido"
    CAT_NIVEL_ACADEMICO ||--o{ FORMACION_ACADEMICA : "nivel"
    CAT_EMPRESA ||--o{ EXPERIENCIA_LABORAL : "empleador"
    CAT_EMPRESA ||--o{ CAT_EMPRESA_ALIAS : "tiene_alias"
    CAT_SECTOR_ECONOMICO ||--o{ CAT_EMPRESA : "sector_principal"
    CAT_SECTOR_ECONOMICO ||--o{ EXPERIENCIA_LABORAL : "sector_declarado"
    CAT_CARGO_NIVEL ||--o{ EXPERIENCIA_LABORAL : "nivel_jerarquico"
    CAT_AREA_DESEMPENO ||--o{ EXPERIENCIA_LABORAL : "area_funcional"
