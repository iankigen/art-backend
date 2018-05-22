#compose:
#	cp docker-compose.yml.template docker-compose.yml

#start:
#	docker-compose up

#exec:
#	docker-compose exec art-backend /bin/bash -it

#open:
#	open http://0.0.0.0:8080/admin


PROJECT_NAME := Andela-Resource-Tracker
REPO_NAME ?= art-backend
ORG_NAME ?= bench-projects
# File names
DOCKER_TEST_COMPOSE_FILE := docker/test/docker-compose.yml
DOCKER_REL_COMPOSE_FILE := docker/release/docker-compose.yml

# Docker compose project names
DOCKER_TEST_PROJECT := "$(PROJECT_NAME)test"
DOCKER_REL_PROJECT := "$(PROJECT_NAME)rel"
APP_SERVICE_NAME := app
DOCKER_REGISTRY ?= gcr.io

# Repository Filter
ifeq ($(DOCKER_REGISTRY), docker.io)
	REPO_FILTER := $(ORG_NAME)/$(REPO_NAME)
else
	REPO_FILTER := $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)[^[:space:]|\$$]*
endif

.PHONY: help


## Show help
help:
	@echo ''
	@echo 'Usage:'
	@echo '${YELLOW} make ${RESET} ${GREEN}<target> [options]${RESET}'
	@echo ''
	@echo 'Targets:'
	@awk '/^[a-zA-Z\-\_0-9]+:/ { \
    	message = match(lastLine, /^## (.*)/); \
		if (message) { \
			command = substr($$1, 0, index($$1, ":")-1); \
			message = substr(lastLine, RSTART + 3, RLENGTH); \
			printf "  ${YELLOW}%-$(TARGET_MAX_CHAR_NUM)s${RESET} %s\n", command, message; \
		} \
	} \
    { lastLine = $$0 }' $(MAKEFILE_LIST)
	@echo ''
    
## Generate Virtual environment
venv:
	${INFO} "Creating Python Virtual Environment"
	@ cd src && python3 -m venv env
	${SUCCESS} "Virtual Environment has be created successfully, run ' source src/env/bin/activate' to activate it"
	${INFO} "Run 'make start' command, when its done, visit http://api.art.andela.com to access the app"
	${INFO} "If you encounter any issues, contact your team lead or add an issue on GitHub"
	@ echo " "

## Generate .env file from the provided sample
env_file:
	@ chmod +x scripts/utils.sh && scripts/utils.sh addEnvFile
	@ echo " "

## Start django local development server containers
start:env_file
	${INFO} "Creating postgresql database volume"
	@ echo " "
	@ docker volume create --name=data > /dev/null
	@ echo "  "
	@ ${INFO} "Building required docker images"
	@ docker-compose -f $(ln) build nginx
	@ docker-compose -f $(DOCKER_DEV_COMPOSE_FILE) build app
	@ ${INFO} "Build Completed successfully"
	@ echo " "
	@ ${INFO} "Starting local development server"
	@ docker-compose -f $(DOCKER_DEV_COMPOSE_FILE) up

## Stop local development server containers
stop:
	${INFO} "Stop development server containers"
	@ docker-compose -f $(DOCKER_DEV_COMPOSE_FILE) down -v
	${INFO} "All containers stopped successfully"

## Run project test cases
test:env_file
	${INFO} "Creating cache docker volume"
	@ echo " "
	@ docker volume create --name=cache > /dev/null
	${INFO} "Building required docker images for testing"
	@ echo " "
	@ docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) build --pull test
	${INFO} "Build Completed successfully"
	@ echo " "
	@ ${INFO} "Running tests in docker container"
	@ docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) up test
	${CHECK} $(DOCKER_TEST_PROJECT) $(DOCKER_TEST_COMPOSE_FILE) test
	${INFO}"Copying test coverage reports"
	@ bash -c 'if [ -d "reports" ]; then rm -Rf reports; fi'
	@ docker cp $$(docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) ps -q test):/application/.coverage reports
	@ ${INFO} "Cleaning workspace after test"
	@ docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) down -v

## Build and collect project artifacts
build:
	${INFO} "Creating builder image..."
	@ docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) build builder
	${INFO} "Building application artifacts..."
	@ docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) up builder
	${CHECK} $(DOCKER_TEST_PROJECT) $(DOCKER_TEST_COMPOSE_FILE) builder
	${INFO} "Copying application artifacts..."
	@ docker cp $$(docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) ps -q builder):/wheelhouse/. artifacts
	${INFO} "Build complete"

## Create and test project release image
release:
	${INFO} "Pulling latest images..."
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) pull test
	${INFO} "Building images..."
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) build app
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) build test
	${INFO} "Collecting static files..."
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) run --rm app manage.py collectstatic --noinput
	${INFO} "Running database migrations..."
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) run --rm app manage.py migrate --noinput
	${INFO} "Running acceptance tests..."
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) up test
	${CHECK} $(DOCKER_REL_PROJECT) $(DOCKER_REL_COMPOSE_FILE) test
	${INFO} "Acceptance testing complete"

tag:
	${INFO} "Tagging release image with tags $(TAG_ARGS)..."
	@ $(foreach tag,$(TAG_ARGS), docker tag $(IMAGE_ID) $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME):$(tag);)
	${SUCCESS} "Tagging complete"


publish:
	${INFO} "Publishing release image $(IMAGE_ID) to $(DOCKER_REGISTRY)/$(ORG_NAME)/$(REPO_NAME)..."
	@ $(foreach tag,$(shell echo $(REPO_EXPR)), docker push $(tag);)
	${INFO} "Publish complete"
## Destroy test and release environments
destroy:
	${INFO} "Destroying test environment..."
	@ docker-compose -p $(DOCKER_TEST_PROJECT) -f $(DOCKER_TEST_COMPOSE_FILE) down -v
	${INFO} "Destroying release environment..."
	@ docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) down -v
	${INFO} "Removing dangling images..."
	@ docker images -q -f dangling=true -f label=application=$(PROJECT_NAME) | xargs -I ARGS docker rmi -f ARGS
	${INFO} "Clean complete"

## Remove all development containers and volumes
clean:
	${INFO} "Cleaning your local environment"
	${INFO} "Note all ephemeral volumes will be destroyed"
	@ docker-compose -f $(DOCKER_DEV_COMPOSE_FILE) down -v
	@ docker images -q -f label=application=$(PROJECT_NAME) | xargs -I ARGS docker rmi -f ARGS
	@ chmod +x scripts/utils.sh
	@ scripts/utils.sh removeHost api.hof.andela.com
	@ scripts/utils.sh removeHost database.hof.andela.com
	${INFO} "Removing dangling images"
	@ docker images -q -f dangling=true -f label=application=$(PROJECT_NAME) | xargs -I ARGS docker rmi -f ARGS
	${INFO} "Clean complete"

## [ service ] Ssh into service container
ssh:
	@ docker-compose -f $(DOCKER_DEV_COMPOSE_FILE) exec $(SSH_ARGS) bash

# extract ssh arguments

ifeq (ssh,$(firstword $(MAKECMDGOALS)))
  SSH_ARGS := $(word 2, $(MAKECMDGOALS))
  ifeq ($(SSH_ARGS),)
    $(error You must specify a service)
  endif
  $(eval $(SSH_ARGS):;@:)
endif

# extract ssh arguments

ifeq (tag,$(firstword $(MAKECMDGOALS)))
  TAG_ARGS := $(word 2, $(MAKECMDGOALS))
  ifeq ($(TAG_ARGS),)
    $(error You must specify a tag)
  endif
  $(eval $(TAG_ARGS):;@:)
endif


  # COLORS
GREEN  := $(shell tput -Txterm setaf 2)
YELLOW := $(shell tput -Txterm setaf 3)
WHITE  := $(shell tput -Txterm setaf 7)
NC := "\e[0m"
RESET  := $(shell tput -Txterm sgr0)
# Shell Functions
INFO := @bash -c 'printf $(YELLOW); echo "===> $$1"; printf $(NC)' SOME_VALUE
SUCCESS := @bash -c 'printf $(GREEN); echo "===> $$1"; printf $(NC)' SOME_VALUE
# check and inspect Logic

INSPECT := $$(docker-compose -p $$1 -f $$2 ps -q $$3 | xargs -I ARGS docker inspect -f "{{ .State.ExitCode }}" ARGS)

CHECK := @bash -c 'if [[ $(INSPECT) -ne 0 ]]; then exit $(INSPECT); fi' VALUE

APP_CONTAINER_ID := $$(docker-compose -p $(DOCKER_REL_PROJECT) -f $(DOCKER_REL_COMPOSE_FILE) ps -q $(APP_SERVICE_NAME))

IMAGE_ID := $$(docker inspect -f '{{ .Image }}' $(APP_CONTAINER_ID))


# Introspect repository tags
REPO_EXPR := $$(docker inspect -f '{{range .RepoTags}}{{.}} {{end}}' $(IMAGE_ID) | grep -oh "$(REPO_FILTER)" | xargs)