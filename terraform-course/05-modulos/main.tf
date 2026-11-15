# Nivel 05: el "root module" (esta carpeta) llama a un módulo hijo una vez por entidad.

terraform {
  required_version = ">= 1.10"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6.0"
    }
  }
}

provider "docker" {}

variable "entidades" {
  type = map(object({
    puerto           = number
    color            = optional(string, "#666666") # optional(): campo con valor por defecto
    security_context = string
  }))
  default = {
    "entidad-a" = { puerto = 8101, color = "#1f77b4", security_context = "axa-a" }
    "entidad-b" = { puerto = 8102, security_context = "axa-b" }
  }
}

# Recursos COMPARTIDOS: se crean una vez y se pasan a cada módulo.
resource "docker_network" "curso" {
  name = "tf-curso-05"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.30.5-alpine"
  keep_locally = true
}

module "entidad" {
  source   = "./modules/entidad_web" # puede ser una ruta local, un repo git o el registry
  for_each = var.entidades

  nombre           = each.key
  puerto           = each.value.puerto
  color            = each.value.color
  security_context = each.value.security_context
  image_id         = docker_image.nginx.image_id
  network_id       = docker_network.curso.id
}

output "urls" {
  value = { for k, m in module.entidad : k => m.url }
}
