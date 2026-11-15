# Terraform: de cero a hero

Curso práctico, en español, pensado para usar Terraform con Dynatrace como se hace en un equipo de plataforma.

- **Niveles 1 a 6:** corren 100 % en local, con Docker. No necesitan cuentas ni tienen costo, y puedes romperlos sin miedo.
- **Nivel 7:** Dynatrace de verdad, con el tenant de prueba del lab.
- **Nivel 8:** cómo se trabaja con Terraform en equipo.

| Nivel | Tema | Aprendes |
|---|---|---|
| [01](01-primeros-pasos/) | Primeros pasos | Qué es IaC; el ciclo `init` → `plan` → `apply` → `destroy`; qué es el *state* |
| [02](02-variables-outputs/) | Variables y outputs | `variable`, `locals`, `output`, tipos, validaciones, `*.tfvars` |
| [03](03-docker/) | Un provider real | Provider de Docker, dependencias, actualizar frente a reemplazar, *drift* |
| [04](04-for-each/) | Muchos recursos | `for_each`, `count`, `templatefile`, *data sources* |
| [05](05-modulos/) | Módulos | Empaquetar y reutilizar; inputs y outputs de módulo; bloque `moved` |
| [06](06-state/) | El state a fondo | `state list/show/rm`, `import`, backends remotos y *locking* |
| [07](07-dynatrace/) | Dynatrace | Autenticación, bucket de Grail, RBAC con `dt.security_context`, exportar configuración existente |
| [08](08-equipo/) | En equipo | `fmt`, `validate`, plan en PR, entornos, secretos, revisión de cambios |

## Cómo usar el curso

1. Entra a cada carpeta **en orden** y lee su `README.md`.
2. Escribe los comandos tú mismo; no los copies sin leerlos. Lo importante es **leer lo que imprime `terraform plan`**.
3. Cada nivel termina con un **reto** y unas **preguntas de repaso**. Si sabes responderlas, puedes pasar al siguiente.
4. Antes de pasar al nivel siguiente, ejecuta `terraform destroy`.

Requisitos: Terraform ≥ 1.10 (`terraform version`) y Docker en marcha.

## Glosario mínimo

| Término | Qué es |
|---|---|
| **IaC** | *Infrastructure as Code*: describir la infraestructura en archivos versionados, en vez de crearla a mano |
| **Provider** | Plugin que sabe hablar con una API (Docker, AWS, Dynatrace…) |
| **Resource** | Algo que Terraform crea y administra (un contenedor, un bucket, una política) |
| **Data source** | Algo que Terraform solo *lee*, sin administrarlo |
| **State** | Archivo donde Terraform recuerda qué creó y con qué ID. Es la pieza más delicada |
| **Plan** | El diff entre lo que dice el código y lo que hay en la realidad, más el state |
| **Module** | Carpeta de `.tf` reutilizable, con entradas (variables) y salidas (outputs) |
