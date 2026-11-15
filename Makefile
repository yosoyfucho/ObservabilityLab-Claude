.PHONY: help certs up down restart ps logs load stop-load urls mode reload-prometheus clean

# Si .env define DT_API_TOKEN, se suma el overlay que envía también a Dynatrace.
DT_ENABLED := $(shell grep -qsE '^DT_API_TOKEN=.+' .env && echo 1)
COMPOSE := docker compose -f docker-compose.yml $(if $(DT_ENABLED),-f docker-compose.dynatrace.yml) --profile load

help: ## Muestra esta ayuda
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

up: certs ## Levanta el stack (local, + Dynatrace si hay token en .env)
	$(COMPOSE) up -d --build $(shell docker compose config --services)
	@$(MAKE) --no-print-directory mode urls

down: ## Detiene el stack (conserva los datos)
	$(COMPOSE) down

restart: down up ## Reinicia el stack

ps: ## Estado de los contenedores
	$(COMPOSE) ps

logs: ## Sigue los logs (make logs s=otel-collector para un servicio)
	$(COMPOSE) logs -f --tail=50 $(s)

load: ## Arranca el generador de tráfico
	$(COMPOSE) up -d loadgen

stop-load: ## Detiene el generador de tráfico
	$(COMPOSE) stop loadgen

mode: ## Indica si el Collector exporta también a Dynatrace
	@echo "Modo: $(if $(DT_ENABLED),local + Dynatrace (Grail),solo local — agrega DT_API_TOKEN en .env para Dynatrace)"

urls: ## Muestra las URLs del lab
	@echo "Grafana     http://localhost:3000"
	@echo "Prometheus  http://localhost:9090"
	@echo "Tempo       http://localhost:3200/ready"
	@echo "Loki        http://localhost:3100/ready"
	@echo "Collector   http://localhost:13133  (health) · OTLP en :4317 / :4318"
	@echo "Frontend    http://localhost:8000  (/, /checkout)"

reload-prometheus: ## Recarga la config de Prometheus sin reiniciar
	curl -s -X POST http://localhost:9090/-/reload && echo "Prometheus recargado"

certs: ## Genera la CA y los certificados mTLS del lab (si no existen)
	@tls/gen-certs.sh

clean: ## Detiene todo y BORRA los volúmenes de datos
	$(COMPOSE) down -v
