# Runs the pipeline documented in README.md's Quick start via Docker, so none
# of Java/Saxon/xmllint/Python need to be installed on the host. Targets map
# 1:1 onto scripts/*.sh; see that directory for what each step actually does.

COMPOSE ?= docker compose

.PHONY: help build-image bootstrap schema validate xar test up restart-exist down logs clean

help:
	@echo "Targets:"
	@echo "  make build-image     build the tooling image used by the targets below"
	@echo "  make bootstrap       fetch Saxon/Jing/TEI Stylesheets into .lib/"
	@echo "  make schema          regenerate schema/madurai-tei.rng + madurai-tei.sch from the ODD"
	@echo "  make validate        validate the corpus (well-formedness, RELAX NG, Schematron, alignment)"
	@echo "  make xar             package the eXist app into build/madurai-tei-*.xar"
	@echo "  make test            run the transliteration test suite (pytest)"
	@echo "  make up              build the .xar and start eXist-db + the Flask service"
	@echo "  make restart-exist   restart eXist-db so a freshly built .xar is autodeployed"
	@echo "  make down            stop all containers"
	@echo "  make logs            tail logs for the running containers"
	@echo "  make clean           stop containers and remove .lib/ and build/"

build-image:
	$(COMPOSE) build build

bootstrap: build-image
	$(COMPOSE) run --rm build bash scripts/bootstrap.sh

schema: bootstrap
	$(COMPOSE) run --rm build bash scripts/build-schema.sh

validate: schema
	$(COMPOSE) run --rm build bash scripts/validate.sh

xar: build-image
	$(COMPOSE) run --rm build bash scripts/build-xar.sh

test: build-image
	$(COMPOSE) run --rm build python3 -m pytest test/ -q

up: xar
	$(COMPOSE) up -d exist flask

restart-exist:
	$(COMPOSE) restart exist

down:
	$(COMPOSE) down

logs:
	$(COMPOSE) logs -f

clean:
	$(COMPOSE) down -v
	rm -rf .lib build
