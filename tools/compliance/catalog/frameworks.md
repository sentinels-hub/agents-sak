# Compliance — Frameworks

## Frameworks soportados

### ISO 27001 — Seguridad de la Información

**Alcance**: Sistema de gestión de seguridad de la información (SGSI).

Controles relevantes para Sentinels:
- **A.8 Asset Management** — Inventario de activos, clasificación
- **A.9 Access Control** — Control de acceso, identidad
- **A.12 Operations Security** — Procedimientos operativos, monitoreo
- **A.14 System Development** — Desarrollo seguro, testing, cambios
- **A.16 Incident Management** — Gestión de incidentes
- **A.18 Compliance** — Cumplimiento legal y normativo

### ISO 9001 — Gestión de Calidad

**Alcance**: Sistema de gestión de calidad.

Cláusulas relevantes:
- **7.5 Documented Information** — Control de documentos
- **8.1 Operational Planning** — Planificación operativa
- **8.5 Production / Service Provision** — Provisión del servicio
- **9.1 Monitoring, Measurement** — Medición y análisis
- **10.2 Nonconformity / Corrective Action** — No conformidades

### SOC 2 Type II — Trust Service Criteria

**Alcance**: Controles de servicio en operación durante un periodo.

Criterios relevantes:
- **CC6 Logical and Physical Access** — Control de acceso
- **CC7 System Operations** — Operaciones del sistema
- **CC8 Change Management** — Gestión de cambios
- **PI1 Processing Integrity** — Integridad de procesamiento

### ENS Alta — Esquema Nacional de Seguridad

**Alcance**: Seguridad de sistemas de información del sector público (España).

Medidas relevantes:
- **op.exp.1** — Control de acceso
- **op.exp.3** — Gestión de configuración
- **op.exp.6** — Gestión de cambios
- **op.exp.8** — Registro de actividad
- **mp.sw.1** — Desarrollo de aplicaciones
- **mp.info.4** — Firma y sellado de tiempo

## Retención de evidencia

Según `policy.yaml`:

| Tipo | Retención |
|------|-----------|
| Engineering evidence | Long term |
| Operational logs | 12 meses online + archivo |
| **Compliance evidence** | **6–7 años** |
