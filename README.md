# ProjectFlow APEX

Entorno de desarrollo para ProjectFlow basado en Oracle Database XE 21c,
Oracle APEX 24.2, ORDS y Docker Compose.

## Estructura

```text
projectflow-apex/
├── docker/
│   ├── docker-compose.yml
│   └── .env.example
├── db/
│   ├── schema.sql
│   ├── procedures.sql
│   ├── triggers.sql
│   └── seed_data.sql
├── apex/
│   ├── app_export.sql
│   └── plugins/
├── docs/
│   ├── arquitectura.md
│   └── guia-arranque.md
├── scripts/
├── Dockerfile.apex
└── README.md
```

## Requisitos

- Docker Desktop con Docker Compose.
- Al menos 4 GB de memoria disponibles para Oracle.
- Conexión a Internet durante la construcción. La imagen descarga APEX 24.2 y
  ORDS directamente desde Oracle.

## Configuración

1. Clona el repositorio:

   ```bash
   git clone https://github.com/raulbarreiroz/projectflow-apex.git
   cd projectflow-apex
   ```

2. Crea la configuración local:

   ```bash
   cp docker/.env.example docker/.env
   ```

   En PowerShell:

   ```powershell
   Copy-Item docker/.env.example docker/.env
   ```

3. Cambia las contraseñas de ejemplo en `docker/.env`.

## Ejecución

Desde la raíz del proyecto:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml up -d --build
```

El contenedor espera a `XEPDB1`, instala APEX cuando hace falta, prepara ORDS y
lo mantiene en ejecución. El primer arranque puede tardar varios minutos.

Para detener los contenedores sin eliminar los volúmenes:

```bash
docker compose --env-file docker/.env -f docker/docker-compose.yml down
```

Accesos:

- Administración APEX: <http://localhost:8081/ords/apex_admin>
- ORDS: <http://localhost:8081/ords/>
- Imágenes estáticas: <http://localhost:8081/i/>

Consulta la [guía de arranque](docs/guia-arranque.md) para la configuración
inicial, reinicios y solución de problemas.

## Base de datos y APEX

Los artefactos SQL se mantienen en `db/` y la exportación de la aplicación en
`apex/app_export.sql`. Consulta [la documentación de arquitectura](docs/arquitectura.md)
para conocer el orden de ejecución y los componentes del entorno.