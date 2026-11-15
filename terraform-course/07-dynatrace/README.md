# Nivel 07: Dynatrace con Terraform

**Objetivo:** administrar Dynatrace como en AXA: buckets, RBAC con `dt.security_context` y OpenPipeline como código. También aprenderás a **adoptar** la configuración que ya existe.

> **Estado:** este nivel **todavía no se ejecutó** contra el tenant (`terraform validate` pasa, pero falta un `apply` real). Hazlo con calma y **leyendo cada plan**. El tenant de prueba vence el **30 de noviembre de 2026**.

## Conceptos

### Credenciales: hay varias, y no son intercambiables

| Credencial | Para qué sirve en el provider | Variables de entorno |
|---|---|---|
| **OAuth client** (`dt0s02…`) | APIs de **plataforma**: buckets de Grail, OpenPipeline, settings y, con el account ID, **IAM** | `DT_CLIENT_ID`, `DT_CLIENT_SECRET`, `DT_ACCOUNT_ID` |
| Access token clásico (`dt0c01…`) | APIs **clásicas** (configuración antigua) | `DYNATRACE_API_TOKEN` |
| Platform token (`dt0s16…`) | Alternativa al OAuth para las APIs de plataforma | `DYNATRACE_PLATFORM_TOKEN` |

El token `dt0c01` del lab **solo tiene permisos de ingesta**, así que no sirve para esto. Necesitas un OAuth client.

### La política de RBAC
```
ALLOW storage:buckets:read;
ALLOW storage:logs:read, storage:spans:read WHERE storage:dt.security_context = "axa-a";
```
Quien esté en el grupo `lab-entidad-a-lectura` **solo ve** los logs y spans cuyo campo `dt.security_context` sea `axa-a`. Así, más o menos, funciona el RBAC de AXA que describiste.

## Paso 0: crear el OAuth client (en la interfaz)

1. En Dynatrace, abre el avatar → **Account Management** → **Identity & access management** → **OAuth clients** → **Create client**.
2. Dale un nombre, como `terraform-lab`, y concédele los permisos para:
   - **buckets de Grail:** lectura y escritura de *bucket definitions*;
   - **settings / OpenPipeline:** lectura y escritura de *settings objects*;
   - **IAM:** gestión de grupos y políticas de la cuenta.

   Los nombres exactos de los scopes cambian entre versiones de la interfaz; busca por *bucket*, *settings* e *iam / policies / groups*. Si al aplicar falta alguno, el error de la API te dirá cuál.
3. Copia el **client ID**, el **client secret** (solo se muestra una vez) y el **account UUID**, que aparece en la URL de Account Management.

Después, en tu terminal:
```bash
cd terraform-course/07-dynatrace
cp credenciales.env.example credenciales.env
open -e credenciales.env            # completa los valores y guarda
set -a; source credenciales.env; set +a
```

## Paso 1: el bucket

```bash
terraform init
terraform plan -target=dynatrace_platform_bucket.lab_tf
terraform apply -target=dynatrace_platform_bucket.lab_tf
```
`-target` limita el plan a un solo recurso: útil para ir paso a paso, pero **no lo uses como costumbre**. Comprueba en **Settings → Storage management → Grail buckets** que aparece `observabilitylab_tf_logs`, con 10 días.

Ahora provoca un **drift**: cambia la retención a 12 días **desde la interfaz** y ejecuta `terraform plan`. ¿Lo detecta? ¿Qué propone?

## Paso 2: RBAC por entidad

```bash
terraform plan
```
Antes de aplicar, lee el plan: deberían ser **2 grupos, 2 políticas y 2 bindings**, todos `+`. Luego:
```bash
terraform apply
terraform output grupos
```
Revisa en Account Management los grupos y políticas creados. Para **probarlo de verdad**, invita a un segundo usuario (puede ser una dirección tuya con `+alias`), agrégalo solo a `lab-entidad-a-lectura` y entra con él: con `fetch logs` solo debería ver datos con `dt.security_context == "axa-a"`.

Para que haya datos con security context, hace falta asignarlo, y ese es el paso 3.

## Paso 3: adoptar la pipeline de OpenPipeline (export + import)

Creamos la pipeline `observabilitylab-backend` **a mano**. Así la pasarías a código, que es lo que se hace en una empresa con configuración heredada:

```bash
# El binario del provider incluye un modo de exportación:
PROVIDER=$(find .terraform/providers -name 'terraform-provider-dynatrace*' -type f | head -1)
mkdir -p export && cd export
"$PROVIDER" -export dynatrace_openpipeline_v2_logs_pipelines dynatrace_openpipeline_v2_logs_routing dynatrace_platform_bucket
ls -R
```
Revisa los `.tf` generados. Igual que en el nivel 06, **el código exportado no se aplica sin leerlo**. Después:
1. Copia al nivel 07 solo el recurso de la pipeline `observabilitylab-backend`, con un bloque `import { to = …; id = … }` (el ID viene en el export).
2. `terraform plan` debe decir **`1 to import, 0 to add, 0 to change`**. Si propone cambios, ajusta el código hasta que no los haya.
3. **Ahora sí, cambia algo por código:** agrega a la pipeline un procesador en la etapa **Permission** que fije `dt.security_context = "axa-b"` para los logs de `lab-backend`. Aplica, enciende el lab (`make up` y `make load`) y comprueba con DQL:
   ```
   fetch logs, from:-5m | filter service.name == "lab-backend" | summarize count(), by:{dt.security_context}
   ```

## Limpieza

```bash
terraform destroy
```
Lee el plan de destroy antes de confirmar: **si importaste la pipeline, `destroy` la borra**. Si quieres conservarla, quítala antes del state con `terraform state rm …`, o usa un bloque `removed { from = … lifecycle { destroy = false } }`.

## Reto

Agrega una **tercera entidad** solo tocando `var.entidades` (vía `terraform.tfvars`), sin escribir recursos nuevos. ¿Cuántos recursos propone el plan?

## Preguntas de repaso

- ¿Por qué el token `dt0c01` del lab no sirve para Terraform?
- ¿Qué pasa si alguien cambia a mano una política que administra Terraform?
- ¿Por qué el código exportado se revisa antes de aplicarlo?
- En AXA, ¿dónde crees que se asigna `dt.security_context`: en el OneAgent, en el Collector, en OpenPipeline o en varios sitios?
