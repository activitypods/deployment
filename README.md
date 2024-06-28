[![ActivityPods](https://badgen.net/badge/Powered%20by/ActivityPods/28CDFB)](https://activitypods.org)

# ActivityPods deployment

See the documentation to find how to use this repository to deploy an ActivityPods provider:

https://docs.activitypods.org/tutorials/deploy-your-own-pod-provider/

## Commands

`make start` Starts the containers for production.

`make stop` Stops and removes running containers.

`make config` Prints the config with the `.env`-file-provided environment variables filled.

`make attach` Attaches to the [Moleculer](https://moleculer.services/) CLI of the ActivityPods backend.
