# Parte 2: RBAC por entidad con dt.security_context, como en AXA.
# Por cada entidad: un GRUPO, una POLÍTICA que solo deja leer los datos de su
# security context, y el BINDING que asocia la política al grupo en este entorno.

resource "dynatrace_iam_group" "entidad" {
  for_each = var.entidades

  name        = "lab-${each.key}-lectura"
  description = "${each.value.descripcion}: solo ve datos con dt.security_context = ${each.value.security_context}"
}

resource "dynatrace_iam_policy" "entidad" {
  for_each = var.entidades

  name        = "lab-${each.key}-lectura"
  description = "Lectura de datos de ${each.key} (dt.security_context = ${each.value.security_context})"
  environment = var.environment_id

  # Lenguaje de políticas de Dynatrace. Una sentencia por línea, terminada en ";".
  # La condición WHERE filtra por el campo dt.security_context de cada registro.
  statement_query = <<-EOT
    ALLOW storage:buckets:read;
    ALLOW storage:logs:read, storage:spans:read WHERE storage:dt.security_context = "${each.value.security_context}";
  EOT
}

resource "dynatrace_iam_policy_bindings_v2" "entidad" {
  for_each = var.entidades

  group       = dynatrace_iam_group.entidad[each.key].id
  environment = var.environment_id

  policy {
    id = dynatrace_iam_policy.entidad[each.key].id
  }
}

output "grupos" {
  value = { for k, g in dynatrace_iam_group.entidad : k => g.name }
}
