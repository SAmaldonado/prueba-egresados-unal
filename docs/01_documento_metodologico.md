# Metodología para la Consolidación, Gobernanza y Análisis de Información Profesional de Egresados a partir de LinkedIn

**Entidad:** Facultad de Ingeniería — Universidad Nacional de Colombia  
**Alcance:** Diseño metodológico de identificación, recolección, depuración, estandarización, calidad, protección de datos personales, indicadores e implementación sostenible  8].

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

```text
site:[linkedin.com/in/](https://linkedin.com/in/) "Nombre Apellido" ("Universidad Nacional de Colombia" OR "UNAL") ("Facultad de Ingeniería" OR "Ingeniería de Sistemas" OR "Ingeniería Civil")
