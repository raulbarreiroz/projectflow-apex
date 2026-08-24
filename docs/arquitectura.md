# Arquitectura de ProjectFlow APEX

## Componentes

- **Oracle Database XE 21c** almacena el esquema, los datos y los metadatos de APEX.
- **Oracle APEX 24.2** proporciona la aplicación web.
- **Oracle REST Data Services (ORDS)** publica APEX y los servicios REST.
- **Docker Compose** coordina la base de datos y el contenedor de APEX/ORDS.

## Flujo

```text
Navegador -> localhost:8081 -> ORDS -> Oracle APEX -> Oracle XEPDB1
```

Los datos de Oracle y la configuración de ORDS se conservan en volúmenes Docker.
El nombre de proyecto Compose permanece como `docker-apex` para reutilizar los
volúmenes creados antes de mover el archivo Compose al directorio `docker/`.

## Secuencia de arranque

El contenedor APEX ejecuta una secuencia idempotente:

1. espera una conexión SYSDBA a `XEPDB1`;
2. instala APEX 24.2 solo si no existe el esquema `APEX_240200`;
3. garantiza que `APEX_PUBLIC_USER` esté disponible para el gateway;
4. instala ORDS solo si faltan `ORDS_METADATA` o la configuración del pool;
5. valida APEX y ejecuta ORDS usando `/opt/ords/config`.

Los scripts no eliminan usuarios ni roles durante un arranque normal.

## Persistencia

- `docker-apex_oracle_data`: archivos y metadatos de Oracle.
- `docker-apex_apex_config`: pool y configuración de ORDS.
- Las imágenes estáticas de APEX forman parte de la imagen del contenedor y se
  publican desde `/opt/apex/images`.

## Artefactos versionados

- `db/`: definición del esquema, lógica PL/SQL, triggers y datos de prueba.
- `apex/app_export.sql`: exportación de la aplicación APEX.
- `apex/plugins/`: plugins utilizados por la aplicación.
- `docker/`: configuración del entorno local.

Los scripts SQL se ejecutan manualmente en el orden `schema.sql`,
`procedures.sql`, `triggers.sql` y `seed_data.sql`. No están conectados
automáticamente al arranque para evitar cambios accidentales en bases existentes.

La operación diaria está documentada en la
[guía de arranque](guia-arranque.md).
