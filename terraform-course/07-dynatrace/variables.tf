variable "environment_id" {
  description = "ID del entorno de Dynatrace (la parte <id> de https://<id>.apps.dynatrace.com)."
  type        = string
}

variable "entidades" {
  description = "Entidades y su valor de dt.security_context."
  type = map(object({
    security_context = string
    descripcion      = string
  }))
  default = {
    "entidad-a" = { security_context = "axa-a", descripcion = "Entidad A del lab" }
    "entidad-b" = { security_context = "axa-b", descripcion = "Entidad B del lab" }
  }
}
