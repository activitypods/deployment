#!/bin/bash

# To call this script every Tuesday at 4am, call "crontab -e" and enter this line :
# 0 4 * * TUE /ABSOLUTE_PATH_TO/compact-datasets.sh >> ~/cron.log 2>&1

# Add /usr/local/bin directory where docker-compose is installed
PATH=/usr/sbin:/usr/bin:/sbin:/bin:/usr/local/bin

SCRIPT_DIR="$( dirname -- "${BASH_SOURCE[0]}"; )";

cd $SCRIPT_DIR

# Stop all containers including Fuseki
docker compose down

# Use the Fuseki service as defined in docker-compose.yml, so that the compaction runs with
# the same image version, volume and memory limit as the triplestore itself
docker compose run --rm --no-deps --entrypoint=/docker-compact-entrypoint.sh fuseki

docker compose up -d

echo "Cron job finished at" $(date)
