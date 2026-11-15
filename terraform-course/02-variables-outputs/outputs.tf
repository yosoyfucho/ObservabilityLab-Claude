# Los outputs son las "salidas": valores que quieres ver al terminar, o que otro
# módulo puede consumir (eso se ve en el nivel 05).

output "otel_resource_attributes" {
  description = "Cadena lista para usar en OTEL_RESOURCE_ATTRIBUTES."
  value       = local.otel_resource_attributes
}

output "effective_retention_days" {
  description = "Retención final, después de aplicar la regla de pro."
  value       = local.effective_retention
}

output "env_file" {
  value = local_file.otel_env.filename
}

# Un output con un valor sensible TIENE que marcarse sensitive, o Terraform da error.
output "ingest_token" {
  value     = var.ingest_token
  sensitive = true
}
