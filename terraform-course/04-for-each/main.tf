# Nivel 04: muchos recursos a partir de una sola definición.
# Simulamos varias "entidades" (como las de AXA): cada una tiene su web y su security context.

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

# Un MAPA de entidades. La clave ("entidad-a"...) es la identidad estable de cada instancia.
variable "entidades" {
  description = "Entidades a desplegar: clave → configuración."
  type = map(object({
    puerto           = number
    color            = string
    security_context = string
  }))
  default = {
    "entidad-a" = { puerto = 8091, color = "#1f77b4", security_context = "axa-a" }
    "entidad-b" = { puerto = 8092, color = "#2ca02c", security_context = "axa-b" }
  }
}

variable "replicas_worker" {
  description = "Cuántos workers idénticos (ejemplo de count)."
  type        = number
  default     = 2
}

# DATA SOURCE: solo LEE algo que ya existe y que Terraform no administra.
# Aquí, la red "bridge" que Docker crea por defecto.
data "docker_network" "bridge" {
  name = "bridge"
}

resource "docker_network" "curso" {
  name = "tf-curso-04"
}

resource "docker_image" "nginx" {
  name         = "nginx:1.30.5-alpine"
  keep_locally = true
}

# for_each: una instancia por cada clave del mapa.
# Dentro del bloque, each.key es la clave y each.value, el objeto.
resource "docker_container" "web" {
  for_each = var.entidades

  name  = "tf-${each.key}"
  image = docker_image.nginx.image_id

  ports {
    internal = 80
    external = each.value.puerto
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name = docker_network.curso.id
  }

  upload {
    file = "/usr/share/nginx/html/index.html"
    # templatefile() renderiza una plantilla con variables: separa el contenido del código.
    content = templatefile("${path.module}/index.html.tftpl", {
      entidad          = each.key
      color            = each.value.color
      security_context = each.value.security_context
    })
  }

  labels {
    label = "dt.security_context"
    value = each.value.security_context
  }
}

# count: N copias idénticas, identificadas por posición (0, 1, 2...).
resource "docker_container" "worker" {
  count = var.replicas_worker

  name    = "tf-worker-${count.index}"
  image   = docker_image.nginx.image_id
  command = ["sh", "-c", "echo worker ${count.index} listo && sleep infinity"]

  networks_advanced {
    name = docker_network.curso.id
  }
}

output "urls" {
  # Una expresión "for" que transforma el mapa de recursos en un mapa de URLs.
  value = { for k, c in docker_container.web : k => "http://localhost:${c.ports[0].external}" }
}

output "workers" {
  # El operador splat [*] saca un atributo de todos los elementos de una lista.
  value = docker_container.worker[*].name
}

output "subred_bridge" {
  value = data.docker_network.bridge.ipam_config
}
