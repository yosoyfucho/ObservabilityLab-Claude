# ObservabilityLab

Laboratorio local de observabilidad basado en **OpenTelemetry**, pensado para parecerse a un entorno con **Dynatrace (Grail) + OTLP**, pero que también funciona 100 % en local con el stack de Grafana.

```
 ┌──────────────┐  HTTP + traceparent  ┌─────────────┐
 │ lab-frontend │ ───────────────────► │ lab-backend │      (misma app Python, OTel SDK)
 └──────┬───────┘                      └──────┬──────┘
        │        OTLP/HTTP (trazas, métricas, logs)
        └──────────────────┬──────────────────┘
                           ▼
            ┌─────────────────────────────┐
            │ OpenTelemetry Collector     │  distribución de Dynatrace
            │ (dynatrace-otel-collector)  │
            └──┬────────┬────────┬────────┬┘
               │        │        │        │  (solo si hay token en .env)
               ▼        ▼        ▼        ▼
            Tempo  Prometheus   Loki   Dynatrace ── Grail (DQL)
           (trazas) (métricas) (logs)   OTLP /api/v2/otlp
               └────────┴────────┘
                     Grafana
```

## Requisitos

- Docker Desktop (probado en Apple Silicon) con ~3 GB libres para el stack
- `make`

## Uso rápido

```bash
make up      # levanta todo (construye la app)
make load    # arranca el generador de tráfico
make help    # lista todos los comandos
```

| Servicio   | URL                                 |
|------------|-------------------------------------|
| Grafana    | http://localhost:3000 (sin login)   |
| Prometheus | http://localhost:9090               |
| Tempo      | http://localhost:3200               |
| Loki       | http://localhost:3100               |
| Collector  | OTLP en `:4317` (gRPC) / `:4318` (HTTP), health en `:13133` |
| Frontend   | http://localhost:8000 (`/`, `/checkout`) |

El dashboard **App overview (OTel)** se abre por defecto en Grafana. Desde una traza en Tempo puedes saltar a sus logs en Loki, y desde un log a su traza, porque todos los logs llevan `trace_id`.

## La app

`app/app.py` usa el SDK de OpenTelemetry para Python sin auto-instrumentación, para que se vea qué produce cada señal:

- **Trazas**: span `SERVER` por request, spans internos (`process_order`, `charge_payment`) y un span de base de datos simulado (`SELECT orders`). El frontend llama al backend propagando `traceparent`, así que cada `/checkout` es una traza distribuida.
- **Métricas**: `http.server.request.duration`, `http.client.request.duration` (histogramas, convenciones semánticas) y `app.orders` (contador por `outcome`).
- **Logs**: logging estándar de Python exportado por OTLP, con contexto de traza, y también como JSON por stdout.

`/error` del backend falla según `ERROR_RATE` (0.3 por defecto), así que alrededor del 30 % de los checkouts terminan en 500.

## Enviar también a Dynatrace (Grail)

> Usa un entorno propio, por ejemplo una prueba gratuita de Dynatrace SaaS, y no un tenant corporativo.

1. En Dynatrace: **Access tokens → Generate new token** con los scopes:
   - `openTelemetryTrace.ingest`
   - `metrics.ingest`
   - `logs.ingest`
2. Copia `.env.example` a `.env` y completa:
   ```bash
   DT_ENDPOINT=https://<environment-id>.live.dynatrace.com
   DT_API_TOKEN=dt0c01.XXXX...
   ```
   Usa el dominio `.live.dynatrace.com`, que es el de la API, y no `.apps.dynatrace.com`.
3. `make up`. `make mode` debería decir `local + Dynatrace (Grail)`.

Con el token, `make up` suma `docker-compose.dynatrace.yml`, y este fusiona `otel-collector/dynatrace.yaml` sobre la config base. El resultado son **pipelines paralelos**: los mismos datos siguen llegando al stack local y además se envían a Dynatrace.

**Por qué hay un `cumulative_to_delta`:** Dynatrace solo acepta métricas OTLP con temporalidad **delta**, mientras que el SDK y Prometheus usan **cumulative**. El pipeline `metrics/dynatrace` las convierte; el de Prometheus las deja como están.

### Consultas DQL de ejemplo (Notebooks)

Valida los nombres de campo con un `fetch ... | limit 1` en tu tenant.

```
fetch spans
| filter service.name == "lab-frontend" and span.kind == "server"
| summarize requests = count(), by: { span.name }
```

```
fetch logs
| filter service.name == "lab-backend" and loglevel == "ERROR"
| sort timestamp desc
| limit 50
```

```
timeseries orders = sum(app.orders), by: { outcome }
```

## OpenPipeline (procesamiento en Dynatrace)

Todo lo que entra por OTLP pasa por **OpenPipeline** antes de guardarse en Grail. Sin configuración propia, los logs siguen la ruta `Default route → default`. En el tenant de prueba se configuró lo siguiente, desde la interfaz (**Settings → Process and contextualize → OpenPipeline → Logs**):

| Pieza | Configuración |
|---|---|
| **Bucket** (Storage management → Grail buckets) | `observabilitylab_logs`, tabla `logs`, retención **7 días** (el bucket por defecto `default_logs` guarda 35) |
| **Dynamic route** `observabilitylab-backend` | Matcher `service.name == "lab-backend"`, ordenada **antes** de la ruta por defecto |
| **Pipeline** `observabilitylab-backend`, etapa *Processing* | Procesador DQL: `fieldsAdd lab.pipeline = "observabilitylab-backend", payment.failed = (error.message == "payment provider timeout")` |
| Etapa *Metric extraction* | Counter `log.observabilitylab.payment_failures`, matcher `payment.failed == true`, dimensión extra `http.route` (`service.name` ya viene entre las recomendadas) |
| Etapa *Bucket assignment* | Todo (`true`) → `observabilitylab_logs` |

Verificación en un Notebook:

```
fetch logs, from:-5m
| filter service.name == "lab-backend"
| summarize n = count(), fallidos = countIf(payment.failed == true), by:{dt.system.bucket, lab.pipeline}
```

```
timeseries fallidos = sum(log.observabilitylab.payment_failures), by:{service.name, http.route}, from:-10m
```

**Collector vs OpenPipeline:** en el Collector, en el borde, conviene filtrar ruido, agregar atributos y convertir temporalidad. En OpenPipeline, en el servidor, conviene parsear, enmascarar, extraer métricas o eventos y decidir bucket y retención de forma centralizada.

## Estructura

```
app/                        app Python + Dockerfile
otel-collector/config.yaml  pipelines locales (Tempo, Prometheus, Loki)
otel-collector/dynatrace.yaml  overlay: pipelines hacia Dynatrace
prometheus/                 config (receptor OTLP + scraping de componentes)
loki/  tempo/               configs de almacenamiento local
grafana/                    datasources (con correlación traza↔log) y dashboard
docker-compose.yml          stack completo
docker-compose.dynatrace.yml  override con credenciales de Dynatrace
```

## Notas

- Todos los puertos están publicados solo en `127.0.0.1`.
- Retención corta: 3 días en Prometheus y Loki, 24 h en Tempo. `make clean` borra todos los datos.
- El Collector de Dynatrace usa nombres de componentes nuevos (`otlp_http`, `otlp_grpc`, `cumulative_to_delta`). Si copias configs antiguas que usan `otlphttp` o `cumulativetodelta`, ajústalos.
