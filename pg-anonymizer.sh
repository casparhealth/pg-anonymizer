#!/bin/bash

# 1 Start
DATE_TIME=$(date "+%Y.%m.%d-%H:%M:%S")
echo "### ANONYMIZER SCRIPT IS STARTED AT $DATE_TIME ###"
echo ""

# 2 Setup the pg-anonymizer tool
echo "### SETUP PG-ANONYMIZER TOOL ###"
echo ""
npm install
npm run prepack

# 3 Run anonymization
echo "### RUN ANONYMIZER ###"
echo ""
export PG_URL="postgres://$PGUSER:$PGPASSWORD@$PGHOST:5432/$PGDATABASE"
export PG_DB_FILE_NAME="$PGDATABASE-anon-$DATE_TIME.sql";
time npx pg-anonymizer $PG_URL \
  --configFile faker.config \
  --extension extensions.js \
  --fakerLocale de \
  --output $PG_DB_FILE_NAME

## 4 Close DB connections
echo "### CLOSE CONNECTIONS TO THE DB ###"
echo ""
psql -d postgres \
    -c "SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = '$PGDATABASE';"

## 5 Drop DB
echo "### DROP THE $PGDATABASE DB ###"
echo ""
psql -d postgres \
    -c "DROP DATABASE $PGDATABASE;"

## 6 Re-create DB
echo "### RE-CREATE THE $PGDATABASE DB ###"
echo ""
psql -d postgres \
  -c "CREATE DATABASE $PGDATABASE;"

## 7 Restore permissions
echo "### RESTORE DB ACCESS PRIVILEGES ###"
echo ""
psql -c "GRANT CONNECT,TEMPORARY ON DATABASE $PGDATABASE TO caspar; \
    GRANT CONNECT ON DATABASE $PGDATABASE TO reporting_analytics; \
    GRANT CONNECT,CREATE ON DATABASE $PGDATABASE TO reporting_migrations; \
    GRANT CONNECT,TEMPORARY,CREATE ON DATABASE $PGDATABASE TO tmservice;"

## 8 Load the DB
echo "### LOAD THE $PGDATABASE DB ###"
echo ""
time psql $PGDATABASE < $PG_DB_FILE_NAME
