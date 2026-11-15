# Nivel 04: Muchos recursos (for_each, count, data sources)

**Objetivo:** crear N recursos a partir de una sola definición, y entender por qué **`for_each` casi siempre es mejor que `count`**.

## Conceptos

| | `count` | `for_each` |
|---|---|---|
| Recibe | un número | un mapa o un set |
| Identidad de cada instancia | su **posición**: `worker[0]`, `worker[1]` | su **clave**: `web["entidad-a"]` |
| Si quitas un elemento del medio | **los siguientes se desplazan** y Terraform los recrea | solo se borra ese |
| Úsalo para | copias idénticas e intercambiables | cosas con identidad propia (entidades, buckets, políticas) |

Y además:
- **Data source** (`data "..."`): lee algo que ya existe sin administrarlo. En Dynatrace lo usarás, por ejemplo, para leer una política o un grupo que creó otro equipo.
- **`templatefile()`**: separa el contenido (HTML, JSON, DQL…) del código Terraform.
- **Expresiones `for` y splat `[*]`**: transforman colecciones.

## Pasos

```bash
cd terraform-course/04-for-each
terraform init
terraform apply
terraform output
open http://localhost:8091
open http://localhost:8092
terraform state list
```
Fíjate en las direcciones del state: `docker_container.web["entidad-a"]` frente a `docker_container.worker[0]`.

## Experimentos

1. **Agregar una entidad.** Crea `terraform.tfvars` con:
   ```hcl
   entidades = {
     "entidad-a" = { puerto = 8091, color = "#1f77b4", security_context = "axa-a" }
     "entidad-b" = { puerto = 8092, color = "#2ca02c", security_context = "axa-b" }
     "entidad-c" = { puerto = 8093, color = "#d62728", security_context = "axa-c" }
   }
   ```
   Con `terraform plan` solo debería aparecer **1 recurso nuevo**.
2. **Quitar la entidad del medio:** borra `entidad-b` del mapa y ejecuta `plan`. Solo se destruye esa; `a` y `c` no se tocan.
3. **El problema de `count`:** con `replicas_worker = 3` aplicado, imagina que necesitas quitar el worker 1. Con `count` no puedes: solo puedes bajar el número, y siempre se borra **el último**. Ese es el problema de identificar las cosas por posición.
4. **Consola interactiva:** prueba expresiones con `terraform console`:
   ```
   > var.entidades["entidad-a"].puerto
   > [for k, v in var.entidades : upper(k)]
   > { for k, v in var.entidades : v.security_context => k }
   ```

## Limpieza

```bash
terraform destroy
rm -f terraform.tfvars
```

## Reto

Agrega al objeto de cada entidad un campo `retencion_dias`, y un output que devuelva **solo** las entidades con retención mayor a 30 días. Pista: `{ for k, v in var.entidades : k => v if v.retencion_dias > 30 }`.

## Preguntas de repaso

- ¿Por qué `for_each` es más seguro que `count` para modelar entidades?
- ¿Qué diferencia hay entre un `resource` y un `data`?
- Si en AXA hubiera un `for_each` sobre una lista de 40 políticas IAM, ¿qué pasa al renombrar la clave de una de ellas?
