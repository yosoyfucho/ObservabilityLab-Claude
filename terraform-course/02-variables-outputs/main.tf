# Nivel 02: a partir de unas pocas variables, generamos la configuración OTel de un servicio.

# "locals" son valores calculados que reutilizas dentro del código (no son entradas).
locals {
  # merge() combina mapas; si una clave se repite, gana el último mapa.
  resource_attributes = merge(
    {
      "service.name"                = var.service_name
      "deployment.environment.name" = var.environment
      "dt.security_context"         = var.security_context
    },
    var.extra_attributes,
  )

  # Convertimos el mapa al formato que espera OTEL_RESOURCE_ATTRIBUTES: k1=v1,k2=v2
  otel_resource_attributes = join(",", [for k, v in local.resource_attributes : "${k}=${v}"])

  # Una expresión condicional: en "pro" exigimos al menos 30 días de retención.
  effective_retention = var.environment == "pro" ? max(var.retention_days, 30) : var.retention_days
}

resource "local_file" "otel_env" {
  filename        = "${path.module}/salida/${var.service_name}.env"
  file_permission = "0600"
  content         = <<-EOT
    # Generado por Terraform: no editar a mano.
    OTEL_SERVICE_NAME=${var.service_name}
    OTEL_RESOURCE_ATTRIBUTES=${local.otel_resource_attributes}
    LOG_RETENTION_DAYS=${local.effective_retention}
    DT_API_TOKEN=${var.ingest_token}
  EOT
}
