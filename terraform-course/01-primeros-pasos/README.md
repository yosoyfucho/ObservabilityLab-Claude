# Nivel 01: Primeros pasos

**Objetivo:** entender el ciclo de vida de Terraform y qué es el *state*.

## Conceptos

Terraform es **declarativo**: describes *cómo quieres que quede* algo, no los pasos para lograrlo. Terraform compara tres cosas:

```
   tu código (.tf)   ←→   el state (lo que cree que existe)   ←→   la realidad (la API)
```

y calcula un **plan** con lo necesario para que la realidad coincida con el código.

| Comando | Qué hace |
|---|---|
| `terraform init` | Descarga los providers y prepara la carpeta. Se hace una vez, o cuando cambias de providers |
| `terraform plan` | Muestra qué *haría*, sin tocar nada |
| `terraform apply` | Muestra el plan, pide confirmación y lo ejecuta |
| `terraform destroy` | Borra todo lo que este código creó |

## Pasos

```bash
cd terraform-course/01-primeros-pasos
terraform init
```
Fíjate en que aparecen dos cosas nuevas: la carpeta `.terraform/`, con los providers descargados, y `.terraform.lock.hcl`, que **fija las versiones exactas** de los providers (este archivo se versiona en git).

```bash
terraform plan
```
Lee el resultado. Los `+` son recursos que se van a **crear**. Verás `(known after apply)` en los valores que todavía no existen, como el nombre aleatorio.

```bash
terraform apply
```
Escribe `yes`. Después revisa el resultado:

```bash
cat salida/hola.txt
terraform state list
terraform state show random_pet.nombre
```

Ahora vuelve a ejecutar `terraform plan`. Debería decir **"No changes"**, porque el código, el state y la realidad coinciden.

## Experimentos

1. **Cambia el código:** edita el texto de `content` en `main.tf` y ejecuta `terraform plan`. Verás `-/+` o `~`. ¿El nombre aleatorio cambia? (No, porque está guardado en el state.)
2. **Cambia la realidad:** borra el archivo a mano con `rm salida/hola.txt` y ejecuta `terraform plan`. Terraform detecta que falta y lo vuelve a crear. A esto se le llama **drift**: la realidad se desvió del código.
3. **Mira el state:** abre `terraform.tfstate`. Es un JSON con todo lo que Terraform sabe. **Nunca lo edites a mano**, y en un equipo tampoco va en git (en el nivel 06 verás por qué y dónde va).

## Limpieza

```bash
terraform destroy
```

## Reto

Agrega un segundo `local_file` llamado `despedida` que escriba `salida/adios.txt` con el texto `Adiós, <nombre>`, reutilizando el mismo `random_pet`. Antes de aplicarlo, predice qué va a mostrar `plan`.

## Preguntas de repaso

- ¿Qué diferencia hay entre `plan` y `apply`?
- ¿Por qué el nombre aleatorio no cambia entre un apply y otro?
- ¿Qué se versiona en git: `.terraform/`, `.terraform.lock.hcl` o `terraform.tfstate`?
- Si borras `terraform.tfstate` y ejecutas `apply`, ¿qué crees que pasa con el archivo y con el nombre?
