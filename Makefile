COMPOSE       = docker compose -f docker-compose.prod.yml
COMPOSE_PROXY = $(COMPOSE) -f docker-compose.proxy.yml

.PHONY: up up-proxy down build rebuild logs logs-shlink logs-db \
        restart update backup shell api-key ps clean gen-certs \
        sync logs-sync

## Start core services (Shlink + MariaDB + Redis)
up:
	$(COMPOSE) up -d

## Start with Nginx reverse proxy on ports 80/443
up-proxy: gen-certs
	$(COMPOSE_PROXY) up -d

## Stop all services
down:
	$(COMPOSE) down

## Build the Shlink image from source
build:
	$(COMPOSE) build

## Force rebuild with no layer cache
rebuild:
	$(COMPOSE) build --no-cache

## Tail logs from all services
logs:
	$(COMPOSE) logs -f

## Tail Shlink logs only
logs-shlink:
	$(COMPOSE) logs -f shlink

## Tail database logs only
logs-db:
	$(COMPOSE) logs -f db

## Restart only the Shlink container (keeps DB and Redis running)
restart:
	$(COMPOSE) restart shlink

## Pull latest code from git and rebuild
update:
	git pull
	$(COMPOSE) build
	$(COMPOSE) up -d

## Backup the MariaDB database to ./backups/
backup:
	@sh deploy/backup.sh

## Open a shell inside the running Shlink container
shell:
	docker exec -it shlink sh

## Generate a new Shlink API key
api-key:
	docker exec shlink bin/cli api-key:generate

## Run one Odoo -> Shlink sync immediately (backfill / test)
sync:
	$(COMPOSE) run --rm odoo_sync python -u sync.py --once

## Tail the Odoo sync worker logs
logs-sync:
	$(COMPOSE) logs -f odoo_sync

## Show status of all containers
ps:
	$(COMPOSE) ps

## Generate self-signed SSL certs (skips if already exist)
gen-certs:
	@sh deploy/gen-certs.sh

## DANGER: Destroy all containers and volumes — deletes database data
clean:
	@echo ""
	@echo "  WARNING: This will permanently destroy all data including the database."
	@echo "  If you want to proceed, run:"
	@echo ""
	@echo "    docker compose -f docker-compose.prod.yml down -v"
	@echo ""
