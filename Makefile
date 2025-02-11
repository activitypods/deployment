DOCKER_COMPOSE_PROD=docker compose

# Build and start

start: 
	$(DOCKER_COMPOSE_PROD) up -d

stop:
	$(DOCKER_COMPOSE_PROD) kill
	$(DOCKER_COMPOSE_PROD) rm -fv

# Maintenance

upgrade:
	$(DOCKER_COMPOSE_PROD) pull
	$(DOCKER_COMPOSE_PROD) up -d

logs:
	$(DOCKER_COMPOSE_PROD) logs -f activitypods-backend

attach:
	$(DOCKER_COMPOSE_PROD) exec activitypods-backend pm2 attach 0

config:
	$(DOCKER_COMPOSE_PROD) config
