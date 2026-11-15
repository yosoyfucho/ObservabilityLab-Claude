# Las variables son las "entradas" del código. Cada una tiene un tipo y, opcionalmente,
# un valor por defecto, una descripción y validaciones.

variable "service_name" {
  description = "Nombre lógico del servicio (se usa como service.name de OpenTelemetry)."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,40}$", var.service_name))
    error_message = "service_name: minúsculas, números y guiones; empieza con letra; 3 a 41 caracteres."
  }
}

variable "environment" {
  description = "Entorno de despliegue."
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "pre", "pro"], var.environment)
    error_message = "environment debe ser dev, pre o pro."
  }
}

variable "security_context" {
  description = "Valor de dt.security_context: determina quién puede ver los datos en Dynatrace."
  type        = string
}

variable "retention_days" {
  description = "Retención deseada en días para los logs de este servicio."
  type        = number
  default     = 7

  validation {
    condition     = var.retention_days >= 1 && var.retention_days <= 3657
    error_message = "retention_days debe estar entre 1 y 3657."
  }
}

variable "extra_attributes" {
  description = "Atributos de recurso adicionales (clave → valor)."
  type        = map(string)
  default     = {}
}

variable "ingest_token" {
  description = "Token de ingesta (de ejemplo). Al ser sensitive, Terraform no lo muestra en plan ni en outputs."
  type        = string
  sensitive   = true
  default     = "dt0c01.EJEMPLO-NO-REAL"
}
