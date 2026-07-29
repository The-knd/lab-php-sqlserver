# AGENTS.md - Estado inicial del proyecto

## Proposito del laboratorio

Infraestructura Docker para experimentar con la coexistencia de dos versiones de PHP (8.1 y 8.4) sirviendo dos aplicaciones Laravel independientes, con un SQL Server como base de datos de respaldo. El objetivo principal es explorar la instalacion manual de los drivers `pdo_sqlsrv` para SQL Server mediante compilacion desde PECL, emulando un servidor real.

## Arquitectura

### Docker Compose (`docker-compose.yml`)

| Servicio | Imagen/Contexto | Container Name | Puertos host:interno | Red |
|----------|----------------|----------------|---------------------|-----|
| `lab-sqlserver` | `mcr.microsoft.com/mssql/server:2022-latest` | `lab-sqlserver` | `1433:1433` | `lab-network` |
| `lab-php-nginx` | `./lab-php-nginx/Dockerfile` | `lab-php-nginx` | `8001:80` | `lab-network` |

Red: `lab-network` (bridge)
Volumen persistente: `sqlserver-data:/var/opt/mssql`

#### Dependencias
- `lab-php-nginx` depende de `lab-sqlserver` con `condition: service_healthy`
- `lab-sqlserver` uso custom entrypoint `entrypoint.sh` para iniciar SQL Server y ejecutar init-db.sql

#### Volumenes montados en lab-php-nginx
- `./laravel-apps/app-php81:/var/www/app-php81`
- `./laravel-apps/app-php84:/var/www/app-php84`
- `./nginx-conf/nginx.conf:/etc/nginx/nginx.conf`
- `./nginx-conf/php81-site.conf:/etc/nginx/sites-available/php81-site.conf`
- `./nginx-conf/php84-site.conf:/etc/nginx/sites-available/php84-site.conf`

### SQL Server (`lab-sqlserver`)

- **EULA**: Aceptada (`ACCEPT_EULA=Y`)
- **SA Password**: `Test1234!`
- **Edicion**: Express (`MSSQL_PID=Express`)
- **Entrypoint**: `entrypoint.sh` que:
  1. Inicia SQL Server en background
  2. Espera hasta que responda (polling con `sqlcmd -C`)
  3. Ejecuta `init-db.sql`
- **init-db.sql**: Crea base de datos `laboratorio` y tabla `test_connectivity`
- **Healthcheck**: `sqlcmd -C -Q "SELECT 1"` cada 10s
- **Alcanzable desde lab-php-nginx** via hostname `lab-sqlserver:1433`

### Contenedor PHP+Nginx (`lab-php-nginx`)

#### Stack

| Componente | Que instala | Detalle |
|------------|------------|---------|
| **Base** | `ubuntu:22.04` | PPA ondrej/php para PHP multi-version |
| **Nginx** | `nginx` | Desde repos Ubuntu 22.04 |
| **PHP 8.1** | `php8.1-fpm`, `php8.1-cli`, `php8.1-curl`, `php8.1-mbstring`, `php8.1-xml`, `php8.1-zip`, `php8.1-bcmath` | Ondrej PPA. Socket en `/run/php/php8.1-fpm.sock` |
| **PHP 8.4** | `php8.4-fpm`, `php8.4-cli`, `php8.4-curl`, `php8.4-mbstring`, `php8.4-xml`, `php8.4-zip`, `php8.4-bcmath` | Ondrej PPA. Socket en `/run/php/php8.4-fpm.sock` |
| **Composer** | Binario global `/usr/local/bin/composer` | Instalado via PHP 8.1 |
| **Supervisor** | `supervisor` | Gestiona 3 procesos (ver abajo) |
| **Build tools** | `build-essential`, `gcc`, `g++`, `make`, `autoconf`, `automake`, `libtool`, `php8.1-dev`, `php8.4-dev`, `php-pear`, `curl`, `wget`, `git`, `unzip` | Preparado para compilar drivers SQL Server |

**NO instala**: ODBC Driver, `pdo_sqlsrv`, `sqlsrv`, ni ninguna extension relacionada con SQL Server.

#### Supervisor: procesos gestionados

| Proceso | Comando | Socket |
|---------|---------|--------|
| `nginx` | `nginx -g "daemon off;"` | TCP :80 |
| `php-fpm81` | `php-fpm8.1 -F` | `/run/php/php8.1-fpm.sock` |
| `php-fpm84` | `php-fpm8.4 -F` | `/run/php/php8.4-fpm.sock` |

### Nginx: routing por server_name

Archivo `nginx-conf/nginx.conf` incluye todos los `.conf` en `/etc/nginx/sites-available/`.

| Server block | server_name | host:puerto | Root | PHP Socket |
|-------------|-------------|------------|------|-----------|
| `php81-site.conf` | `php81.localhost` | `:8001` | `/var/www/app-php81/public` | `unix:/run/php/php8.1-fpm.sock` |
| `php84-site.conf` | `php84.localhost` | `:8001` | `/var/www/app-php84/public` | `unix:/run/php/php8.4-fpm.sock` |

### Proyectos Laravel

| Directorio | PHP | Laravel | DB default |
|-----------|-----|---------|-----------|
| `laravel-apps/app-php81/` | 8.1.34 | `^10.10` (Laravel 10.x) | SQLite |
| `laravel-apps/app-php84/` | 8.4.23 | `^12.0` (Laravel 12.x) | SQLite |

Ambos proyectos fueron creados via `composer create-project` desde dentro del contenedor. `storage/` y `bootstrap/cache/` tienen permisos `www-data`.

## Estructura de archivos del proyecto (excluyendo vendor)

```
pruebas-sqlserver/
├── AGENTS.md                           <- Este archivo
├── docker-compose.yml                  <- Orquestador
├── lab-php-nginx/
│   ├── Dockerfile                      <- Imagen Ubuntu + PHP 8.1/8.4 + Nginx + Supervisor + Composer + build tools
│   └── supervisord.conf                <- 3 programas: nginx, php-fpm81, php-fpm84
├── lab-sqlserver/
│   ├── entrypoint.sh                   <- Inicia SQL Server, espera, ejecuta init-db.sql
│   └── init-db.sql                     <- Crea DB laboratorio + tabla test_connectivity
├── laravel-apps/
│   ├── app-php81/                      <- Laravel 10.x producido con PHP 8.1
│   │   ├── .env                        <- DB_CONNECTION=sqlite por defecto
│   │   ├── routes/web.php
│   │   └── ...
│   └── app-php84/                      <- Laravel 12.x producido con PHP 8.4
│       ├── .env                        <- DB_CONNECTION=sqlite por defecto
│       ├── routes/web.php
│       └── ...
└── nginx-conf/
    ├── nginx.conf                      <- Config principal Nginx
    ├── php81-site.conf                 <- Server block para PHP 8.1 (server_name php81.localhost)
    └── php84-site.conf                 <- Server block para PHP 8.4 (server_name php84.localhost)
```

## Comandos de operacion

### Levantar/Detener
```bash
cd /home/admin33/Proyectos/pruebas-sqlserver
docker compose up -d                    # Levantar
docker compose down                     # Detener
docker compose build --no-cache         # Reconstruir desde cero
```

### Acceder
```bash
docker exec -it lab-php-nginx bash      # Shell en PHP+Nginx
docker exec -it lab-sqlserver bash      # Shell en SQL Server
```

### Probar
```bash
curl -H "Host: php81.localhost" http://localhost:8001/   # Laravel PHP 8.1
curl -H "Host: php84.localhost" http://localhost:8001/   # Laravel PHP 8.4
```

### Verificar servicios
```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
docker exec lab-php-nginx php8.1 -v
docker exec lab-php-nginx php8.4 -v
```

## Proximo paso esperado

Instalacion manual del driver `pdo_sqlsrv` via PECL en ambos PHP:

```bash
docker exec -it lab-php-nginx bash

# Instalar ODBC Driver 18 (dependencia)
curl -s https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
curl -s https://packages.microsoft.com/config/ubuntu/22.04/prod.list > /etc/apt/sources.list.d/mssql-release.list
apt-get update
ACCEPT_EULA=Y apt-get install -y msodbcsql18 unixodbc-dev

# Compilar e instalar extension pdo_sqlsrv
pecl install pdo_sqlsrv

# Habilitar en ambos PHP
echo "extension=pdo_sqlsrv.so" > /etc/php/8.1/mods-available/pdo_sqlsrv.ini
echo "extension=pdo_sqlsrv.so" > /etc/php/8.4/mods-available/pdo_sqlsrv.ini
phpenmod -v 8.1 pdo_sqlsrv
phpenmod -v 8.4 pdo_sqlsrv
php8.1 -m | grep pdo_sqlsrv
php8.4 -m | grep pdo_sqlsrv
```

## Notas tecnicas adicionales

- El separador de directorio de Laravel 11+ (`bootstrap/app.php`) difiere entre Laravel 10 y 12. Ambos coexisten sin conflicto.
- Los drivers `pdo_sqlsrv` se instalan por separado para cada version de PHP via PECL (no son compatibles entre versiones).
- `lab-sqlserver` y `lab-php-nginx` se comunican via Docker DNS: `lab-sqlserver:1433`.
