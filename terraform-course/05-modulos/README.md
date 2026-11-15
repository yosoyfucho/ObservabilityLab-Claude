# Nivel 05: Módulos

**Objetivo:** empaquetar código reutilizable y entender cómo se organiza un repo de Terraform "de verdad", como el de AXA.

## Conceptos

- **Root module:** la carpeta donde ejecutas `terraform`. **Child module:** cualquier carpeta que llamas con `module "x" { source = ... }`.
- **Un módulo es como una función:** sus variables son los parámetros y sus outputs, lo que devuelve. Desde fuera **solo** puedes leer sus outputs, no sus recursos internos.
- **`source`** puede ser:
  - una ruta local: `./modules/x`;
  - un repositorio git: `git::https://…//modules/x?ref=v1.2.0`;
  - el Terraform Registry.

  En empresas lo típico es un **repo de módulos versionados con tags**, que consumen los repos de cada equipo o entorno.
- **Dirección en el state:** `module.entidad["entidad-a"].docker_container.web`.

```
05-modulos/
├── main.tf                    ← root: lo que se despliega
└── modules/
    └── entidad_web/           ← módulo reutilizable
        ├── main.tf
        ├── variables.tf       ← su "contrato" de entrada
        ├── outputs.tf         ← lo que expone
        └── index.html.tftpl
```

## Pasos

```bash
cd terraform-course/05-modulos
terraform init        # ahora también "instala" el módulo local
terraform apply
terraform output
terraform state list
```

## Experimentos

1. **Valor opcional:** `entidad-b` no define `color`. Mira en el plan qué color recibe gracias a `optional(string, "#666666")`.
2. **Renombrar sin destruir (`moved`).** Con el stack aplicado, cambia en `main.tf` el nombre del bloque `module "entidad"` a `module "web"`, y en el output `module.entidad` a `module.web`. Ejecuta `terraform init` (el módulo cambió de nombre) y luego `plan`:
   ```
   Plan: 2 to add, 0 to change, 2 to destroy.
   ```
   Para Terraform son recursos **distintos**, porque cambió su dirección en el state. Ahora agrega al final de `main.tf`:
   ```hcl
   moved {
     from = module.entidad
     to   = module.web
   }
   ```
   y vuelve a ejecutar `plan`:
   ```
   # module.entidad["entidad-a"].docker_container.web has moved to module.web["entidad-a"].docker_container.web
   Plan: 0 to add, 0 to change, 0 to destroy.
   ```
   **Esta técnica es clave para refactorizar código en producción sin borrar recursos**, por ejemplo políticas IAM o buckets con datos. Ojo: `moved` solo cambia la *dirección*. Si además cambias un atributo que obliga a reemplazar (como el nombre del contenedor), el recurso se reemplaza igual.
3. **Encapsulamiento:** intenta agregar en el root un output con `module.entidad["entidad-a"].docker_container.web.id`. Da error: solo puedes leer outputs del módulo. ¿Cómo lo resolverías? (Agregando un output al módulo.)

## Limpieza

```bash
terraform destroy
```

## Reto

Mueve también la red y la imagen a un segundo módulo, `modules/base`, que exponga `network_id` e `image_id` como outputs. Luego haz que el root conecte ambos módulos: `module.base.network_id` → `module.entidad`.

## Preguntas de repaso

- ¿Qué ventajas tiene un módulo frente a copiar y pegar recursos?
- ¿Por qué conviene versionar los módulos con tags (`?ref=v1.2.0`)?
- ¿Qué problema resuelve el bloque `moved`?
- En el repo de Terraform de AXA, ¿qué módulos esperarías encontrar para Dynatrace?
