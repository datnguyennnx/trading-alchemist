#!/bin/bash
set -e

# Connect to the default database and create TimescaleDB extension
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
    -- Enable TimescaleDB extension
    CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;
    
    -- Display a message if successful
    SELECT 'TimescaleDB extension has been installed!' AS message;
EOSQL

echo "TimescaleDB initialization complete" 