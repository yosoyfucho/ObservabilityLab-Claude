# Nivel 03: un provider "real". Terraform habla con la API de Docker de tu Mac,
# igual que el provider de Dynatrace habla con la API de Dynatrace.

terraform {
  required_version = ">= 1.10"

  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 4.6.0"
    }
  }
}

# Configuración del provider. Sin argumentos, usa el socket local de Docker.
provider "docker" {}

variable "puerto" {
  description = "Puerto de tu Mac donde se publica el servidor web."
  type        = number
  default     = 8081
}

variable "mensaje" {
  type    = string
  default = "Hola desde un contenedor creado con Terraform"
}

# 1. Una red propia para los contenedores del curso.
resource "docker_network" "curso" {
  name = "tf-curso"
}

# 2. La imagen. Terraform la descarga (pull) si no está.
resource "docker_image" "nginx" {
  name         = "nginx:1.30.5-alpine"
  keep_locally = true # al hacer destroy, no borra la imagen del Mac
}

# 3. El contenedor. Fíjate en las referencias a los otros recursos:
#    docker_image.nginx.image_id y docker_network.curso.id
#    Así Terraform sabe el ORDEN: primero la red y la imagen, después el contenedor.
resource "docker_container" "web" {
  name  = "tf-curso-web"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = var.puerto
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name = docker_network.curso.id
  }

  # Sube un archivo dentro del contenedor al crearlo.
  upload {
    file    = "/usr/share/nginx/html/index.html"
    content = "<h1>${var.mensaje}</h1>\n"
  }

  labels {
    label = "gestionado-por"
    value = "terraform"
  }
}

output "url" {
  value = "http://localhost:${var.puerto}"
}

output "container_id" {
  value = docker_container.web.id
}
