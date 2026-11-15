# Módulo "entidad_web": todo lo que necesita UNA entidad, empaquetado.
# Un módulo es una carpeta de .tf con entradas (variables) y salidas (outputs).
# No declara el bloque provider: lo hereda de quien lo llama.

terraform {
  required_providers {
    docker = {
      source = "kreuzwerker/docker"
    }
  }
}

resource "docker_container" "web" {
  name  = "tf-mod-${var.nombre}"
  image = var.image_id

  ports {
    internal = 80
    external = var.puerto
    ip       = "127.0.0.1"
  }

  networks_advanced {
    name = var.network_id
  }

  upload {
    file = "/usr/share/nginx/html/index.html"
    content = templatefile("${path.module}/index.html.tftpl", {
      entidad          = var.nombre
      color            = var.color
      security_context = var.security_context
    })
  }

  labels {
    label = "dt.security_context"
    value = var.security_context
  }
}
