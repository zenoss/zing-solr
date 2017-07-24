DOCKER_COMPOSE       := /usr/local/bin/docker-compose

.PHONY: default
default: run

.PHONY: docker-compose
docker-compose: $(DOCKER_COMPOSE)

$(DOCKER_COMPOSE): DOCKER_COMPOSE_VERSION := 1.14.0
$(DOCKER_COMPOSE):
	@if [ ! -w $(@D) ]; then echo 'No docker-compose found. Please run "sudo make docker-compose" to install it.'; exit 2; else true; fi
	@curl -L https://github.com/docker/compose/releases/download/$(DOCKER_COMPOSE_VERSION)/docker-compose-`uname -s`-`uname -m` > $@
	@chmod +x $@

.PHONY: run
run: $(DOCKER_COMPOSE)
	@$(DOCKER_COMPOSE) up --build

.PHONY: test
test:
	echo "Not implemented"

.PHONY: clean
clean:
	$(DOCKER_COMPOSE) down

.PHONY: mrclean
mrclean: clean
