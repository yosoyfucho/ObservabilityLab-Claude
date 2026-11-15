# Nivel 06: el state a fondo. Importar lo que ya existe, sacar cosas del state y backends.

terraform {
  required_version = ">= 1.10"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6.0"
    }
  }

  # BACKEND: dónde se guarda el state. Por defecto es "local" (terraform.tfstate en
  # esta carpeta). Aquí lo hacemos explícito y lo dejamos en otra ruta.
  # En un equipo se usa un backend REMOTO con locking (ver README):
  #   backend "azurerm" { ... }   o   backend "s3" { ... }
  backend "local" {
    path = "estado/curso.tfstate"
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:1.30.5-alpine"
  keep_locally = true
}

resource "docker_container" "gestionado" {
  name  = "tf-state-gestionado"
  image = docker_image.nginx.image_id
}

# --- Experimento de IMPORT (lee el README antes de descomentar) -------------
# 1) Crea un contenedor A MANO:  docker run -d --name tf-state-manual nginx:1.30.5-alpine
# 2) Descomenta el bloque import de abajo y ejecuta:
#      terraform plan -generate-config-out=generado.tf
#    Terraform escribe en generado.tf el resource que corresponde a lo que existe.
# 3) LEE EL PLAN: el código generado provoca un reemplazo (falta "env"). El README
#    explica cómo escribir un recurso mínimo con lifecycle.ignore_changes para adoptarlo
#    sin destruirlo.
#
# import {
#   to = docker_container.manual
#   id = "<ID completo del contenedor: docker inspect -f '{{.Id}}' tf-state-manual>"
# }
