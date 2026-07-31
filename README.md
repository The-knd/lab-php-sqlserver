# Fase 1

## Estado actual del laboratorio

Infraestructura Docker con dos contenedores (`lab-php-nginx` y `lab-sqlserver`) que emula un servidor real con dos versiones de PHP (8.1 y 8.4) sirviendo dos aplicaciones Laravel independientes contra un SQL Server, mas un esquema de usuarios del sistema para compatibilidad de permisos con el host.

---

## Arquitectura de usuarios (`lab-php-nginx`)

| Usuario | uid | Grupo primario | Grupos secundarios | Rol |
|---------|-----|----------------|--------------------|-----|
| `root` | 0 | root | — | Superusuario del contenedor |
| `www-data` | 33 | www-data | — | Workers de nginx, propietario del socket FPM |
| `phpuser` | 1000 | phpuser | www-data | Workers de PHP-FPM (ambas versiones) |
| `devuser` | 2000 | devuser | www-data, phpuser | Tareas administrativas/desarrollo |

La correspondencia `phpuser:uid=1000` contra `admin33:uid=1000` del host permite que los archivos creados por PHP-FPM (logs, cache, vendor) tengan el mismo UID que el usuario del host, haciendo posible editar directamente desde el IDE.

---

## Modelo de ejecucion de procesos

```
supervisord (root)
├── nginx (master: root, workers: www-data)
│   ├── puerto 8081 → socket 8.1 → app-php81
│   └── puerto 8082 → socket 8.4 → app-php84
├── php-fpm8.1 (master: root)
│   ├── socket: /run/php/php8.1-fpm.sock (prop. www-data:www-data)
│   └── workers: phpuser (uid 1000)
└── php-fpm8.4 (master: root)
    ├── socket: /run/php/php8.4-fpm.sock (prop. www-data:www-data)
    └── workers: phpuser (uid 1000)
```

- Los **sockets** son propiedad de `www-data` para que nginx pueda conectarse.
- Los **workers** FPM corren como `phpuser`, escribiendo logs, cache, y vistas compiladas con uid 1000.
- Nginx enruta por **puerto**: `8081` → socket 8.1, `8082` → socket 8.4.

---

## Dependencias del sistema (Dockerfile)

### PHP 8.1
- `php8.1-fpm`, `php8.1-cli`, `php8.1-curl`, `php8.1-mbstring`, `php8.1-xml`, `php8.1-zip`, `php8.1-bcmath`, `php8.1-sqlite3`, `php8.1-dev`

### PHP 8.4
- `php8.4-fpm`, `php8.4-cli`, `php8.4-curl`, `php8.4-mbstring`, `php8.4-xml`, `php8.4-zip`, `php8.4-bcmath`, `php8.4-sqlite3`, `php8.4-dev`

### Herramientas de compilacion (para drivers SQL Server)
- `build-essential`, `gcc`, `g++`, `make`, `autoconf`, `automake`, `libtool`, `php-pear`, `curl`, `wget`, `git`, `unzip`

### SQL Server (instalado en Fase 2)
- ODBC Driver 18 (`msodbcsql18` + `unixodbc-dev`)
- `sqlsrv` + `pdo_sqlsrv` compilados via PECL para PHP 8.1 y 8.4

---

## Proyectos Laravel

| Directorio | PHP | Laravel | DB actual | Session driver |
|------------|-----|---------|-----------|----------------|
| `laravel-apps/app-php81/` | 8.1.34 | ^10.10 | SQLite (`database/database.sqlite`) | `file` |
| `laravel-apps/app-php84/` | 8.4.23 | ^12.0 | SQLite (`database/database.sqlite`) | `file` |

Ambos proyectos tienen `vendor/` instalado, `APP_KEY` generada, y `storage/` + `bootstrap/cache/` con permisos `phpuser:phpuser` (uid 1000), editables desde el host.

---

## Flujo de datos entre contenedores

```
Host:8001 ──> lab-php-nginx:8081 ──> nginx ──> FPM socket 8.1 ──> app-php81 (Laravel 10)
Host:8002 ──> lab-php-nginx:8082 ──> nginx ──> FPM socket 8.4 ──> app-php84 (Laravel 12)

Ambos usan SQLite (local) o SQL Server via hostname `lab-sqlserver:1433`.
```

Ambos contenedores en red bridge `lab-network`. El hostname `lab-sqlserver` resuelve desde `lab-php-nginx`.

---

## Comandos de operacion

```bash
# Construir y levantar
docker compose build --no-cache lab-php-nginx
docker compose up -d

# Probar
curl -s http://localhost:8001/ | head -1     # PHP 8.1 / Laravel 10
curl -s http://localhost:8002/ | head -1     # PHP 8.4 / Laravel 12

# Shell
docker exec -it lab-php-nginx bash
docker exec -it lab-sqlserver bash

# Logs
docker logs lab-php-nginx
```

---

## Reproduccion del laboratorio completo (Fase 2)

Flujo para dejar el laboratorio funcionando desde cero sobre un checkout fresco. La infraestructura (contenedores, drivers sqlsrv, ODBC 18, Nginx, usuarios, base de datos inicial) se reconstruye solo con Docker; los pasos manuales restantes son exclusivos de las apps Laravel porque `vendor/` y `.env` no estan versionados (solo `.env.example`).

### 1. Prerequisitos

- Docker Engine + Docker Compose.
- Usuario host con **uid 1000** para que coincida con `phpuser` del contenedor (bind mounts escribibles por PHP-FPM). Si el uid difiere, los permisos se normalizan en el paso 5.

### 2. Clonar, construir y levantar

```bash
cd pruebas-sqlserver
docker compose build lab-php-nginx
docker compose up -d
```

- `lab-sqlserver` ejecuta `entrypoint.sh` + `init-db.sql` solo la primera vez que se crea el volumen (crea la DB `laboratorio` y la tabla `test_connectivity`). Para reejecutar desde cero: `docker compose down -v && docker compose up -d`.
- `lab-php-nginx` ya incluye `sqlsrv` + `pdo_sqlsrv` compilados para PHP 8.1 y 8.4 (con `--with-php-config` para instalar cada `.so` en su directorio ABI) y ODBC Driver 18.

### 3. Preparar los `.env` de las apps

```bash
cp laravel-apps/app-php81/.env.example laravel-apps/app-php81/.env
cp laravel-apps/app-php84/.env.example laravel-apps/app-php84/.env
```

Valores que deben quedar en ambos (estado de trabajo actual):

| Variable | app-php81 | app-php84 |
|----------|-----------|-----------|
| `DB_CONNECTION` | `sqlite` | `sqlite` |
| `SESSION_DRIVER` | `file` | `file` |

En `app-php81` el ejemplo ya trae `CACHE_DRIVER=file` y `QUEUE_CONNECTION=sync`. En `app-php84` ajustar `CACHE_STORE=file` y `QUEUE_CONNECTION=sync` para evitar dependencia de tablas de base de datos.

Crear el archivo de SQLite que usa la conexion sqlite:

```bash
touch laravel-apps/app-php81/database/database.sqlite
touch laravel-apps/app-php84/database/database.sqlite
```

### 4. Instalar dependencias y generar APP_KEY

```bash
docker exec -u phpuser lab-php-nginx php8.1 /usr/local/bin/composer install --working-dir=/var/www/app-php81
docker exec -u phpuser lab-php-nginx php8.4 /usr/local/bin/composer install --working-dir=/var/www/app-php84

docker exec -u phpuser lab-php-nginx php8.1 /var/www/app-php81/artisan key:generate
docker exec -u phpuser lab-php-nginx php8.4 /var/www/app-php84/artisan key:generate
```

Se corre como `phpuser` para que `vendor/`, `.env` y `storage/` queden con uid 1000 y sigan editables desde el host.

### 5. Permisos de los bind mounts

```bash
docker exec lab-php-nginx chown -R phpuser:phpuser /var/www/app-php81 /var/www/app-php84
```

### 6. Verificar el laboratorio

Drivers SQL Server cargados en ambas versiones (deben mostrar `pdo_sqlsrv` y `sqlsrv` sin warnings):

```bash
docker exec lab-php-nginx php8.1 -m | grep -E 'sqlsrv|pdo_sqlsrv'
docker exec lab-php-nginx php8.4 -m | grep -E 'sqlsrv|pdo_sqlsrv'
```

Conexion a SQL Server (ODBC 18 exige confiar en el certificado autofirmado del contenedor via `TrustServerCertificate=yes`):

```bash
docker exec lab-php-nginx php8.1 -r '$c=new PDO("sqlsrv:Server=lab-sqlserver,1433;Database=master;TrustServerCertificate=yes","sa","Test1234!");echo "PHP 8.1 OK: ".$c->query("SELECT @@VERSION AS v")->fetch()["v"]."\n";'
docker exec lab-php-nginx php8.4 -r '$c=new PDO("sqlsrv:Server=lab-sqlserver,1433;Database=master;TrustServerCertificate=yes","sa","Test1234!");echo "PHP 8.4 OK: ".$c->query("SELECT @@VERSION AS v")->fetch()["v"]."\n";'
```

Apps respondiendo:

```bash
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8001/   # PHP 8.1 / Laravel 10
curl -s -o /dev/null -w "%{http_code}\n" http://localhost:8002/   # PHP 8.4 / Laravel 12
```

---

## Estructura de directorios

```
pruebas-sqlserver/
├── README.md                          <- Este archivo
├── AGENTS.md                          <- Estado historico del proyecto
├── docker-compose.yml                 <- Orquestador
├── lab-php-nginx/
│   ├── Dockerfile                     <- Imagen con PHP 8.1/8.4, Nginx, Supervisor, sqlsrv
│   └── supervisord.conf               <- 3 programas: nginx, php-fpm81, php-fpm84
├── lab-sqlserver/
│   ├── entrypoint.sh                  <- Inicia SQL Server y ejecuta init-db.sql
│   └── init-db.sql                    <- Crea DB laboratorio + tabla test_connectivity
├── laravel-apps/
│   ├── app-php81/                     <- Laravel 10.x
│   │   ├── .env                       <- sqlite
│   │   ├── routes/web.php
│   │   └── ...
│   └── app-php84/                     <- Laravel 12.x
│       ├── .env                       <- sqlite
│       ├── routes/web.php
│       └── ...
└── nginx-conf/
    ├── nginx.conf                     <- Config principal
    ├── php81-site.conf                <- Server block PHP 8.1 (puerto 8081)
    └── php84-site.conf                <- Server block PHP 8.4 (puerto 8082)
```
