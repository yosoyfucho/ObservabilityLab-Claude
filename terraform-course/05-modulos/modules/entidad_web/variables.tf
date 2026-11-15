variable "nombre" {
  description = "Nombre de la entidad."
  type        = string
}

variable "puerto" {
  description = "Puerto publicado en 127.0.0.1."
  type        = number
}

variable "color" {
  type    = string
  default = "#666666"
}

variable "security_context" {
  description = "Valor de dt.security_context de la entidad."
  type        = string
}

variable "image_id" {
  description = "ID de la imagen a usar (la crea quien llama al módulo)."
  type        = string
}

variable "network_id" {
  description = "Red a la que se conecta el contenedor."
  type        = string
}
