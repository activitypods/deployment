[![ActivityPods](https://badgen.net/badge/Powered%20by/ActivityPods/28CDFB)](https://activitypods.org)

# ActivityPods deployment

See the documentation to find how to use this repository to deploy an ActivityPods provider:

https://docs.activitypods.org/tutorials/deploy-your-own-pod-provider/

## Commands

`make start` Starts the containers for production.

`make stop` Stops and removes running containers.

`make config` Prints the config with the `.env`-file-provided environment variables filled.

`make logs` Display the logs of the ActivityPods backend.

`make attach` Attaches to the [Moleculer](https://moleculer.services/) CLI of the ActivityPods backend.

## Versions

The ActivityPods and Fuseki versions are pinned in `.env` (see `.env.example`): `ACTIVITYPODS_VERSION`, `FUSEKI_VERSION`, and `FUSEKI_MEMORY_LIMIT`, which also sizes the Fuseki JVM heap (65% of the limit). Every server running this repository should only differ by its `.env*` files.

## Backups

Every night at 4am (Paris time), the backend dumps all the datasets and copies them, with the uploads and the keys, to the `BACKUP_DIR` of the `.env` file (default `./data/backups`, prefer a separate disk). The dumps are kept forever: add `prune-backups.sh` to the crontab (see the script) to delete those older than 14 days.

## Upgrading

1. Back up the `data/` directory (stop the containers first, so that Fuseki's files are consistent). Use `tar --sparse`: without it, the preallocated TDB2 index files are restored at their full size (e.g. 30 GB instead of 300 MB). If it's too late, `find data/fuseki/databases -type f -size +1M -exec fallocate --dig-holes {} \;` makes them sparse again.
2. `git pull`, then set the new `ACTIVITYPODS_VERSION` in `.env`, then `make upgrade`.
3. If the new version comes with a migration, run it from the Moleculer CLI (`make attach`), e.g. `call migration-2-2-0.migrate --username *` for 2.2.0, and check the logs for `Unable to migrate Pod` errors.

## Debug tools

Fuseki (3030), tripleadmin (3033), the Traefik dashboard (8080), Arena (4567) and cAdvisor (8090) are only published on the server's localhost. Reach them through an SSH tunnel, e.g. `ssh -L 3030:localhost:3030 -L 3033:localhost:3033 user@server`, then open http://localhost:3033.
