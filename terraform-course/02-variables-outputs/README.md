# Nivel 02: Variables, locals y outputs

**Objetivo:** escribir código **parametrizable**: el mismo código sirve para muchos servicios y entornos.

## Conceptos

| Bloque | Para qué sirve | Se usa como |
|---|---|---|
| `variable` | **Entrada**: con tipo, valor por defecto, validación y `sensitive` | `var.nombre` |
| `locals` | **Cálculo interno** reutilizable | `local.nombre` |
| `output` | **Salida**: se muestra al final o la consume otro módulo | `terraform output` |

Por convención, el código se reparte en varios archivos: `versions.tf`, `variables.tf`, `main.tf` y `outputs.tf`. A Terraform le da igual; **lee todos los `.tf` de la carpeta como si fueran uno solo**.

### ¿De dónde salen los valores de las variables?
De menor a mayor prioridad (cada fuente pisa a la anterior):

1. `default` en la variable
2. Variables de entorno `TF_VAR_nombre`
3. `terraform.tfvars` y `*.auto.tfvars`, que se cargan automáticamente
4. `-var-file=archivo.tfvars`
5. `-var 'nombre=valor'` en la línea de comandos

Si una variable no tiene `default` y no le pasas valor, Terraform **te lo pregunta** de forma interactiva.

## Pasos

```bash
cd terraform-course/02-variables-outputs
terraform init
terraform plan
```
Te va a pedir `service_name` y `security_context`, porque no tienen valor por defecto. Cancela con Ctrl+C y pásalos de otra forma:

```bash
cp terraform.tfvars.example terraform.tfvars
terraform apply
cat salida/payments-api.env
terraform output
terraform output -raw otel_resource_attributes
terraform output ingest_token          # aparece como <sensitive>
terraform output -raw ingest_token     # así sí lo muestra: cuidado en CI
```

## Experimentos

1. **Las validaciones funcionan:** ejecuta `terraform plan -var 'environment=prod'`. Falla con tu mensaje de error antes de tocar nada.
2. **La prioridad de las fuentes:** ejecuta `TF_VAR_retention_days=3 terraform plan` y luego `terraform plan -var 'retention_days=21'`. ¿Cuál gana frente a `terraform.tfvars`?
3. **La lógica de los locals:** ejecuta `terraform plan -var 'environment=pro'`. ¿Qué retención efectiva sale con `retention_days = 14`?
4. **Los secretos:** fíjate en que `plan` muestra `(sensitive value)` en el contenido del archivo. Ahora abre `terraform.tfstate` y busca `EJEMPLO-NO-REAL`. **El state guarda los secretos en texto plano**, y por eso hay que protegerlo.

## Limpieza

```bash
terraform destroy
```

## Reto

Agrega una variable `owners` de tipo `list(string)`, con una validación que exija al menos un elemento, y añade al archivo una línea `OWNERS=ana,luis`. Pista: la función `join()`.

## Preguntas de repaso

- ¿Qué diferencia hay entre `variable` y `locals`?
- ¿Por qué `terraform.tfvars` no se sube a git y `terraform.tfvars.example` sí?
- `sensitive = true`, ¿oculta el valor del state?
- ¿Qué ventaja tiene validar en Terraform, en vez de dejar que falle la API?
