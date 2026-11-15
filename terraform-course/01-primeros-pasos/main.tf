# Nivel 01: tu primer código Terraform.
# Crea un archivo en disco con un nombre aleatorio. No hay nube ni Docker de por medio:
# solo te interesa ver el ciclo init → plan → apply → destroy y qué guarda el state.

terraform {
  required_version = ">= 1.10"

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }
}

# Un nombre aleatorio del estilo "brave-otter". Se genera UNA vez y queda en el state:
# los siguientes apply no lo cambian.
resource "random_pet" "nombre" {
  length = 2
}

# Un archivo de texto. Fíjate en la referencia random_pet.nombre.id:
# Terraform deduce que tiene que crear primero random_pet y después el archivo
# (dependencia implícita).
resource "local_file" "saludo" {
  filename = "${path.module}/salida/hola.txt"
  content  = "Hola desde Terraform. Me llamo ${random_pet.nombre.id}.\n"
}
