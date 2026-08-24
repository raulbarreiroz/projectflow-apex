# Guía de arranque de ProjectFlow APEX

Esta guía levanta Oracle Database XE 21c, instala Oracle APEX 24.2 cuando hace
falta, configura ORDS y conserva tanto la base de datos como la configuración
de ORDS entre reinicios.

## Requisitos

- Docker Desktop o Docker Engine con Docker Compose.
- Al menos 4 GB de memoria disponibles para Oracle.
- Acceso a `container-registry.oracle.com`.
- Conexión a Internet para descargar APEX 24.2 y ORDS durante el build.

Si Docker no puede descargar las imágenes de Oracle, inicia sesión:

```bash
docker login container-registry.oracle.com
```

## Configuración inicial

Desde la raíz del repositorio, crea el archivo local de variables:

```bash
cp docker/.env.example docker/.env
```

En PowerShell:

```powershell
Copy-Item docker/.env.example docker/.env
```

Edita `docker/.env` y reemplaza todos los valores `change-me`. El servicio de
base de datos debe permanecer como:

```dotenv
DB_SERVICE=XEPDB1
```

Si reutilizas un volumen de Oracle existente, `ORACLE_PASSWORD` debe coincidir
con la contraseña con la que ese volumen fue creado. La contraseña
`APEX_ADMIN_PASSWORD` solo crea el usuario ADMIN cuando aún no existe; no
sobrescribe su contraseña en instalaciones existentes.

## Construcción y arranque

Ejecuta:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml up -d --build
```

El primer arranque puede tardar varios minutos. El flujo automático:

1. espera hasta que `XEPDB1` acepte conexiones;
2. instala APEX 24.2 únicamente si no está instalado;
3. crea el usuario ADMIN de INTERNAL únicamente si no existe;
4. instala o configura ORDS únicamente cuando faltan sus metadatos o su pool;
5. inicia ORDS en primer plano y publica las imágenes de APEX bajo `/i/`.

Ningún reinicio elimina usuarios, roles ni metadatos existentes.

## Comprobación

Consulta el estado:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml ps
```

Sigue el arranque de APEX y ORDS:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml logs -f apex
```

Cuando ambos servicios estén saludables:

- Administración APEX: <http://localhost:8081/ords/apex_admin>
- ORDS: <http://localhost:8081/ords/>
- Imágenes APEX: <http://localhost:8081/i/>
- Workspace: `INTERNAL`
- Usuario inicial: el valor de `APEX_ADMIN_USER`

## Reinicios

Detener sin borrar datos:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml down
```

Volver a iniciar:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml up -d
```

No uses `docker compose down -v` salvo que quieras eliminar la base de datos y
la configuración persistente de ORDS.

## Diagnóstico

### Oracle no queda saludable

Revisa:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml logs oracle-db
```

Comprueba que Docker tenga memoria suficiente y que `ORACLE_PASSWORD` coincida
con el volumen existente.

### APEX u ORDS no arranca

Revisa:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml logs apex
```

El build descarga APEX y ORDS desde los sitios oficiales de Oracle. Comprueba
la conexión a Internet y el acceso a `container-registry.oracle.com`. La
configuración persistente se guarda en `docker-apex_apex_config`.

### Los estilos o imágenes no cargan

Comprueba <http://localhost:8081/i/apex_version.txt>. ORDS se inicia con
`/opt/apex/images` y contexto `/i`; no es necesario ejecutar manualmente
`reset_image_prefix.sql`.

### Inspección manual

Para abrir una shell:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec apex bash
```

Para conectarte a la PDB desde el contenedor de Oracle:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml exec oracle-db bash
sqlplus sys/<ORACLE_PASSWORD>@XEPDB1 as sysdba
```

No desbloquees ni utilices `APEX_240200` como gateway. Es un esquema interno
administrado por APEX. ORDS utiliza `ORDS_PUBLIC_USER` como usuario de ejecución
y `APEX_PUBLIC_USER` como gateway PL/SQL.
