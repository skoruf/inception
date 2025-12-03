COMPOSE_FILE = ./srcs/docker-compose.yml

build:
	docker compose -f $(COMPOSE_FILE) up --build

kill:
	docker compose -f $(COMPOSE_FILE) kill

down:
	docker compose -f $(COMPOSE_FILE) down

clean:
	docker compose -f $(COMPOSE_FILE) down -v

restart: clean build
