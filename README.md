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

## Upgrading

1. Back up the `data/` directory (stop the containers first, so that Fuseki's files are consistent).
2. `git pull`, then set the new `ACTIVITYPODS_VERSION` in `.env`, then `make upgrade`.
3. If the new version comes with a migration, run it from the Moleculer CLI (`make attach`), e.g. `call migration-2-2-0.migrate --username *` for 2.2.0, and check the logs for `Unable to migrate Pod` errors.
