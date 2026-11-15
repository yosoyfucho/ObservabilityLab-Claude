# Nivel 03: Un provider real (Docker)

**Objetivo:** administrar infraestructura de verdad y entender el **grafo de dependencias**, la diferencia entre **actualizar y reemplazar** y qué pasa con el **drift**.

## Conceptos

- **Provider:** un plugin que traduce tus `resource` a llamadas de API. Aquí es Docker; en AXA será Dynatrace (y probablemente Azure o AWS). La forma de trabajar es **idéntica**.
- **Dependencias implícitas:** si un recurso usa un atributo de otro (`docker_image.nginx.image_id`), Terraform crea primero el referenciado. Rara vez hace falta `depends_on`.
- **Actualizar o reemplazar.** Algunos cambios la API los admite "en caliente"; otros obligan a destruir y volver a crear. En el plan:
  - `~` **update in-place**: se modifica sin destruir.
  - `-/+` **replace**: se destruye y se crea de nuevo. Terraform marca con `# forces replacement` el atributo que lo provoca.

  En producción, **un `-/+` inesperado es la señal de alarma número uno** al revisar un plan.

## Pasos

```bash
cd terraform-course/03-docker
terraform init
terraform plan
```
Fíjate en el **orden** que propone y en los valores `(known after apply)`.

```bash
terraform apply
curl http://localhost:8081
docker ps --filter name=tf-curso
```

Para ver el grafo de dependencias, con Graphviz instalado (`brew install graphviz`):
```bash
terraform graph | dot -Tsvg > grafo.svg && open grafo.svg
```

## Experimentos

1. **Cambio que obliga a reemplazar:** ejecuta `terraform plan -var 'puerto=8082'`. Verás `-/+` y `# forces replacement` en `ports`. Aplícalo y comprueba que el contenedor tiene **otro ID**.
2. **Cambio sin efecto:** cambia el `mensaje` con `-var 'mensaje=Hola AXA'`. ¿Qué pasa? `upload` solo actúa al crear el contenedor, así que el plan también lo reemplaza. No todo atributo es "en caliente".
3. **Drift:**
   ```bash
   docker rm -f tf-curso-web      # alguien "arregla" algo a mano
   terraform plan                 # Terraform detecta que falta y lo recrea
   ```
   Ahora prueba un drift más sutil: aplica de nuevo, ejecuta `docker network disconnect tf-curso tf-curso-web` y vuelve a ejecutar `plan`. **Dice "No changes"**: con esta versión del provider, `plan` no propone volver a conectar la red.
4. **Ver el drift que `plan` no muestra:** `terraform plan -refresh-only` sí lo detecta (`docker_container.web has changed`, el bloque `networks_advanced` desaparece), pero no propone arreglarlo.

   **Lección importante:** Terraform solo corrige el drift que el provider sabe comparar. No asumas que "No changes" significa que nadie tocó nada a mano. Con Dynatrace pasa lo mismo, y por eso conviene prohibir los cambios manuales en lo que administra Terraform.

## Limpieza

```bash
terraform destroy
```

## Reto

Agrega un segundo contenedor `redis:7-alpine` en la misma red, **sin** publicar puertos, y haz que `web` reciba una variable de entorno `REDIS_HOST` con el nombre del contenedor de Redis (bloque `env = [...]`). Comprueba en el plan que Redis se crea **antes** que `web`.

## Preguntas de repaso

- ¿Cómo sabe Terraform en qué orden crear los recursos?
- ¿Qué significa `-/+` y por qué es peligroso en producción?
- ¿Qué es el drift? ¿Terraform lo corrige solo o tienes que hacer algo?
- Si alguien cambia algo a mano en Dynatrace sobre un recurso que maneja Terraform, ¿qué pasa en el siguiente `apply`?
