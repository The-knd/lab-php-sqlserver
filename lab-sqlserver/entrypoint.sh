#!/bin/bash
set -e

# Iniciar SQL Server
/opt/mssql/bin/sqlservr &

echo "Esperando a SQL Server..."

until /opt/mssql-tools18/bin/sqlcmd \
    -C \
    -S localhost \
    -U sa \
    -P "$SA_PASSWORD" \
    -Q "SELECT 1" >/dev/null 2>&1
do
    echo "Esperando a SQL Server..."
    sleep 2
done

echo "Ejecutando init-db.sql"

/opt/mssql-tools18/bin/sqlcmd \
    -C \
    -S localhost \
    -U sa \
    -P "$SA_PASSWORD" \
    -i /docker-entrypoint-initdb.d/init-db.sql

echo "Inicialización completada."

wait
