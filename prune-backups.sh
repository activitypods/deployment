#!/bin/bash
# Deletes the dataset dumps older than RETENTION_DAYS (first argument, default 14) from BACKUP_DIR.
# The backend copies the dumps of every night to BACKUP_DIR and never deletes them. The uploads and
# keys are overwritten at each copy, so they don't pile up.
#
# To call this script every day at 6am, call "crontab -e" and enter this line :
# 0 6 * * * /ABSOLUTE_PATH_TO/prune-backups.sh >> ~/cron.log 2>&1

set -u

RETENTION_DAYS=${1:-14}

SCRIPT_DIR="$( dirname -- "${BASH_SOURCE[0]}"; )";

cd $SCRIPT_DIR

BACKUP_DIR=$(grep -E '^BACKUP_DIR=' .env 2>/dev/null | tail -1 | cut -d= -f2-)
BACKUP_DIR=${BACKUP_DIR:-./data/backups}

if [ ! -d "$BACKUP_DIR/datasets" ]; then
  echo "$(date -u) No datasets directory in $BACKUP_DIR, nothing to prune"
  exit 0
fi

# Never delete the last dumps, even if the backups have stopped for longer than the retention
if [ -z "$(find "$BACKUP_DIR/datasets" -name '*.nq.gz' -mtime -"$RETENTION_DAYS" -print -quit)" ]; then
  echo "$(date -u) No dump newer than $RETENTION_DAYS days in $BACKUP_DIR/datasets, are the backups running? Nothing deleted"
  exit 1
fi

deleted=$(find "$BACKUP_DIR/datasets" -name '*.nq.gz' -mtime +"$RETENTION_DAYS" -print -delete | wc -l)

echo "$(date -u) Deleted $deleted dumps older than $RETENTION_DAYS days, $(df -Ph "$BACKUP_DIR" | awk 'NR==2 {print $4}') free"
