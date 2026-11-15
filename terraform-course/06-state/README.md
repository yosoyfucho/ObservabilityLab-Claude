# Nivel 06: El state a fondo

**Objetivo:** dominar la pieza más delicada de Terraform. La mayoría de los incidentes con Terraform en empresas **son problemas de state**.

## Conceptos

- **El state es un mapa:** relaciona cada recurso del código (`docker_container.gestionado`) con un objeto real (un ID de contenedor, el UUID de una política…). Sin el state, Terraform no sabe qué es suyo.
- **Contiene secretos en texto plano** (lo viste en el nivel 02). **Nunca va en git.**
- **Backend remoto:** en un equipo, el state vive en un almacenamiento compartido, como Azure Storage (`azurerm`), S3 o Terraform Cloud. Así:
  - todos trabajan sobre **el mismo** state;
  - hay **locking**: si dos personas, o dos pipelines de CI, ejecutan `apply` a la vez, el segundo espera o falla;
  - queda versionado y protegido.
- **Importar** es "adoptar" algo que ya existe y se creó a mano. Es lo que harías en AXA con configuración de Dynatrace hecha desde la interfaz.

| Comando | Para qué | Riesgo |
|---|---|---|
| `terraform state list` | Ver qué administra Terraform | ninguno |
| `terraform state show <dir>` | Ver los atributos de un recurso | ninguno (pero puede mostrar secretos) |
| bloque `import {}` | Adoptar un recurso existente | bajo, porque pasa por `plan` |
| bloque `moved {}` | Renombrar o mover sin destruir | bajo, porque pasa por `plan` |
| `terraform state rm <dir>` | Que Terraform **deje de administrar** algo (sin borrarlo) | medio |
| `terraform force-unlock` | Quitar un lock que quedó colgado | **alto**: solo si estás seguro de que no hay otro apply corriendo |

Los bloques `import` y `moved` son **declarativos**: aparecen en el plan y se revisan como cualquier cambio. Los comandos `terraform import` y `terraform state mv` son la forma antigua, que toca el state directamente.

## Pasos

```bash
cd terraform-course/06-state
terraform init
terraform apply
ls estado/                 # el state ya no está en la raíz: lo decidió el backend
terraform state list
```

## Experimentos

1. **Importar un recurso hecho a mano**, siguiendo los pasos comentados en `main.tf`:
   ```bash
   docker run -d --name tf-state-manual nginx:1.30.5-alpine
   docker inspect -f '{{.Id}}' tf-state-manual        # copia el ID
   # descomenta el bloque import en main.tf y pega el ID
   terraform plan -generate-config-out=generado.tf
   ```
   Abre `generado.tf`: Terraform escribió el código por ti, unas 60 líneas con todos los atributos. Ahora **lee el plan con atención**:
   ```
   # Warning: this will destroy the imported resource
   + env = (known after apply) # forces replacement
   Plan: 1 to import, 1 to add, 0 to change, 1 to destroy.
   ```
   **El código generado no es perfecto:** le falta `env` (la imagen de nginx trae variables de entorno propias) y, si aplicaras así, Terraform **destruiría el recurso que acabas de adoptar**. Con Dynatrace pasa lo mismo: **nunca apliques un import sin leer el plan.**

   La forma correcta: borra `generado.tf` y escribe un recurso **mínimo**, que solo declare lo que te importa:
   ```hcl
   resource "docker_container" "manual" {
     name  = "tf-state-manual"
     image = "nginx:1.30.5-alpine"

     lifecycle {
       ignore_changes = [env]   # "esto lo gestiona otro, no lo compares"
     }
   }
   ```
   Ahora el plan dice `Plan: 1 to import, 0 to add, 1 to change, 0 to destroy`. El *change* es inofensivo: son valores internos del provider (`must_run`, `start`…) que se fijan en el state. Aplica, y el siguiente `plan` dice **"No changes"**.
2. **Dejar de administrar sin borrar:**
   ```bash
   terraform state rm docker_container.gestionado
   docker ps --filter name=tf-state-gestionado     # sigue existiendo
   terraform plan                                  # "will be created": ¡quiere crearlo otra vez! (y fallaría: el nombre ya existe)
   ```
   Vuelve a adoptarlo con un bloque `import` (`to = docker_container.gestionado`). Así entiendes por qué `state rm` es delicado.
3. **Locking:** abre **dos terminales** en esta carpeta. En la primera ejecuta `terraform apply` y **no** respondas. En la segunda ejecuta `terraform plan`: verás `Error acquiring the state lock`. Esto es lo que evita que dos pipelines de CI se pisen.

## Cómo se ve un backend remoto (solo lectura)

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstateaxa"
    container_name       = "tfstate"
    key                  = "dynatrace/pro.tfstate"   # un state por entorno o componente
    use_azuread_auth     = true
  }
}
```
Pregunta en AXA qué backend usan, cómo se separan los states (por entorno, por tenant, por equipo) y quién tiene permiso de escritura.

## Limpieza

```bash
terraform destroy
docker rm -f tf-state-manual 2>/dev/null; rm -f generado.tf
```

## Reto

Después del experimento 1, usa un bloque `moved` para renombrar `docker_container.manual` a `docker_container.importado` **sin** recrearlo. El plan debe mostrar `has moved to` y **0 to destroy**.

## Preguntas de repaso

- ¿Qué pasa si dos personas ejecutan `apply` a la vez con un state local en sus portátiles?
- ¿Por qué el state no va en git?
- ¿Qué diferencia hay entre `terraform state rm` y `terraform destroy -target=…`?
- Si en Dynatrace hay 50 políticas creadas a mano y quieres pasarlas a Terraform, ¿qué pasos seguirías?
