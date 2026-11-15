# Nivel 08: Terraform en equipo

**Objetivo:** entender el flujo de trabajo que probablemente encontrarás en el repo de Terraform de AXA, y saber **revisar un plan** como lo haría alguien de plataforma.

## 1. El flujo típico: nadie ejecuta `apply` desde su portátil

```
rama → código → PR → CI ejecuta fmt/validate/plan → revisión humana del PLAN → merge → CI ejecuta apply
```

- El **plan se publica en el PR** y es lo que de verdad se revisa, más que el código.
- El **apply lo hace el pipeline de CI**, con credenciales de un *service principal* o un OAuth client, no las de una persona.
- El **state** vive en un backend remoto con locking (nivel 06).

En [`ejemplo-ci.yml`](ejemplo-ci.yml) tienes un pipeline de ejemplo de GitHub Actions comentado. Está fuera de `.github/` a propósito, para que **no se ejecute**.

## 2. Calidad antes del plan

```bash
terraform fmt -recursive          # formato estándar (en CI: fmt -check)
terraform validate                # sintaxis y tipos
```
Herramientas habituales, opcionales:
- **tflint:** errores y malas prácticas;
- **checkov / trivy:** reglas de seguridad;
- **pre-commit:** ejecuta lo anterior antes de cada commit.

Pruébalo en este curso desde la carpeta `terraform-course/`:
```bash
terraform fmt -recursive -check -diff
```

## 3. Varios entornos o tenants

Dos enfoques comunes:

| Enfoque | Cómo | Cuándo |
|---|---|---|
| **Una carpeta por entorno** | `envs/dev/`, `envs/pro/`, cada uno con su backend y su `tfvars`, que llaman a los mismos módulos | El más común y explícito. Recomendado |
| **Workspaces** | `terraform workspace new pro`: el mismo código con varios states | Sencillo, pero es fácil equivocarse de workspace |

Con Dynatrace, lo habitual es **un state por tenant o entorno**, y a veces por dominio (IAM, OpenPipeline, dashboards), para que un cambio no toque todo a la vez.

## 4. Secretos

- **Nunca** en los `.tf` ni en `tfvars` versionados.
- Por **variables de entorno** (`DT_CLIENT_SECRET`…) que inyecta el CI desde un gestor de secretos, como Azure Key Vault o GitHub Secrets.
- Recuerda que **el state contiene secretos**, así que el acceso al backend debe ser restringido.

## 5. Checklist para revisar un plan

1. **Cuenta los números:** `Plan: X to add, Y to change, Z to destroy`. ¿Encajan con lo que el PR dice que hace?
2. **Busca `-/+` y `destroy`:** ¿algún reemplazo inesperado? Atención especial a buckets, políticas y pipelines.
3. **Busca `# forces replacement`:** ¿qué atributo lo provoca?
4. **Mira los `~` de recursos que el PR no menciona:** podría ser drift (alguien tocó la interfaz) o un cambio de versión del provider.
5. **Revisa `(sensitive value)`:** ¿se está metiendo algún secreto donde no debe?
6. **Imports y moves:** ¿dicen `0 to destroy`?

## 6. Detección de drift programada

Un job programado (por ejemplo, cada noche) que ejecuta `terraform plan -detailed-exitcode`. El código de salida indica el resultado: `0` sin cambios, `1` error, `2` hay diferencias. Con `2`, alguien cambió algo a mano y se abre una alerta o un issue.

## Preguntas para hacerte (y hacer) en AXA

- ¿Dónde está el repo de Terraform de Dynatrace? ¿Hay un repo de **módulos** separado?
- ¿Qué backend usan y cómo separan los states?
- ¿Quién aprueba los PR y quién (o qué) ejecuta el `apply`?
- ¿Hay detección de drift? ¿Está prohibido cambiar a mano en la interfaz lo que administra Terraform?
- ¿Usan solo Terraform, o también **Monaco** (la herramienta de configuración como código de Dynatrace)?

## Reto final ("hero")

Reorganiza el nivel 07 como lo harías en un equipo:
```
dynatrace/
├── modules/
│   └── entidad_rbac/        ← grupo + política + binding
└── envs/
    └── lab/
        ├── main.tf          ← llama a modules/entidad_rbac con for_each
        ├── backend.tf       ← backend local, por ahora
        └── terraform.tfvars
```
Usa bloques `moved` para que el refactor **no destruya ni recree** nada: el plan debe terminar en `0 to add, 0 to change, 0 to destroy`. Si lo consigues, ya sabes Terraform lo suficiente para trabajar con el repo de AXA.
