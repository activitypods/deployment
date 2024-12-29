#!/bin/bash

# To call this script every Tuesday at 4am, call "crontab -e" and enter this line :
# 0 4 * * TUE /ABSOLUTE_PATH_TO/compact-datasets.sh >> ~/cron.log 2>&1

# Add /usr/local/bin directory where docker-compose is installed
PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin

SCRIPT_DIR="$( dirname -- "${BASH_SOURCE[0]}"; )";

cd $SCRIPT_DIR

# Stop all containers including Fuseki
docker compose down

docker run --volume="$SCRIPT_DIR"/data/fuseki:/fuseki --entrypoint=/docker-compact-entrypoint.sh semapps/jena-fuseki-webacl

docker compose --env-file .env --env-file .env.local up -d

echo "Cron job finished at" $(date)
