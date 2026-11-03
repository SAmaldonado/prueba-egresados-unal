# Declaración de Datos Sintéticos de Demostración (`mock_data/`)

## 1. Naturaleza 100% Ficticia de los Registros

Todos los archivos CSV contenidos en este directorio han sido generados de forma **completamente sintética** con el único propósito de comprobar el funcionamiento técnico del esquema relacional PostgreSQL, sus restricciones de integridad y las reglas de control de calidad.

* **Cero extracción de LinkedIn:** Ningún registro proviene de consultas o *scraping* sobre perfiles reales de LinkedIn.
* **Cero datos personales (PII):** No se incluyen nombres de personas reales, números de cédula, correos personales, teléfonos ni URLs de perfiles existentes.
* **Identificadores y empresas simuladas:** Los identificadores `UUID` siguen el patrón de prueba `550e8400-e29b-41d4-a716-44665544000X`, las referencias de origen utilizan el espacio de nombres no resoluble `urn:sintetico:perfil:...`, los códigos HMAC son cadenas hexadecimales simuladas y las razones sociales llevan el sufijo explícito `[SINTETICA]`.
* **Diferenciación frente a consentimiento real:** En `identidad_restringida_ficticia.csv`, la columna `estado_autorizacion` utiliza exclusivamente el valor `'DATO_SINTETICO_DEMO'` con `es_dato_sintetico = TRUE`. En una implementación institucional real, ningún dato individual semiprivado puede procesarse como `'AUTORIZADO_TITULAR'` sin contar previamente con el soporte auditable de autorización expresa e informada conforme a la Ley Estatutaria 1581 de 2012.

## 2. Cobertura de los 8 Escenarios Obligatorios de Prueba

| Escenario | Identificador en los archivos CSV | Qué comportamiento del modelo demuestra |
| :--- | :--- | :--- |
| **Caso 1. Trayectoria profesional completa** | `550e8400-e29b-41d4-a716-446655440001` | Relación `1:N` con 2 formaciones académicas (Pregrado 2020 y Maestría 2023 en Sistemas) y 3 experiencias laborales secuenciales (Practicante -> Junior -> Senior actual). |
| **Caso 2. Movilidad internacional y trabajo remoto** | `550e8400-e29b-41d4-a716-446655440002` | Egresado de Ing. Electrónica que reside en Bogotá (`11001`), trabaja en modalidad `REMOTO` para una empresa con sede matriz y puesto adscrito en Austin, EE. UU. (`84001`). |
| **Caso 3. Fechas incompletas (precisión anual)** | `550e8400-e29b-41d4-a716-446655440003` | Egresado de Ing. Civil con experiencia (`id_experiencia = 1005`) donde solo se conoce el año de inicio (`2021`). Almacena `2021-01-01` con `precision_fecha = 'ANUAL'` para impedir cálculos engañosos de duración en meses. |
| **Caso 4. Cargo ambiguo** | `550e8400-e29b-41d4-a716-446655440004` | Egresada de Ing. Industrial con `cargo_original = 'Ninja de Ecosistemas & Growth Hacker'`. Conserva el texto original intacto y deja `cargo_nivel_id` y `area_desempeno_id` en `NULL` bajo `estado_homologacion = 'PENDIENTE_HOMOLOGACION'`. |
| **Caso 5. Múltiples empleos actuales** | `550e8400-e29b-41d4-a716-446655440005` | Egresado de Ing. Mecánica con dos trabajos actuales legítimos (`es_actual = TRUE`): un `ROL_PRINCIPAL` en industria manufacturera y una `DOCENCIA_CATEDRA` universitaria. |
| **Caso 6. Transición hacia un sector no afín** | `550e8400-e29b-41d4-a716-446655440006` | Egresado de Ing. Química que se desempeña como Ejecutivo Comercial en comercio minorista (`sector_economico_id = 'G47'`, `area_desempeno_id = 'COMERCIAL_VENTAS'`). |
| **Caso 7. Homonimia sin resolver** | `CAND-SINT-0007` (Solo en `perfiles_candidatos.csv`) | Perfil candidato que coincide parcialmente con Ingeniería Eléctrica pero presenta colisión con 2 homónimos en actas de grado y carece de año de grado. Permanece en `CUARENTENA_HOMONIMIA` con `id_egresado_confirmado = NULL` y **no ingresa** a `egresados.csv` ni a `formacion_academica.csv`. |
| **Caso 8. Información desactualizada** | `550e8400-e29b-41d4-a716-446655440008` | Egresada de Ing. Agrícola (cohorte 2017) con última verificación del `2024-05-10` que aún figura como practicante activa desde 2017, disparando alerta de obsolescencia. |
