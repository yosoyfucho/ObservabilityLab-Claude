"""App de ejemplo instrumentada con OpenTelemetry para el ObservabilityLab.

La misma imagen corre como dos servicios (frontend y backend) para generar
trazas distribuidas. Todo sale por OTLP hacia el OpenTelemetry Collector.

Endpoints:
  GET /          -> respuesta rápida
  GET /checkout  -> llama al backend (/work y /error): traza distribuida
  GET /work      -> latencia aleatoria + span de "base de datos"
  GET /error     -> falla aleatoriamente (ERROR_RATE)

Configuración por variables estándar de OTel (OTEL_SERVICE_NAME,
OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_RESOURCE_ATTRIBUTES, ...).
"""

import json
import logging
import os
import random
import signal
import sys
import time
import urllib.error
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse

from opentelemetry import metrics, propagate, trace
from opentelemetry._logs import set_logger_provider
from opentelemetry.exporter.otlp.proto.http._log_exporter import OTLPLogExporter
from opentelemetry.exporter.otlp.proto.http.metric_exporter import OTLPMetricExporter
from opentelemetry.exporter.otlp.proto.http.trace_exporter import OTLPSpanExporter
from opentelemetry.sdk._logs import LoggerProvider, LoggingHandler
from opentelemetry.sdk._logs.export import BatchLogRecordProcessor
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.sdk.metrics.view import ExplicitBucketHistogramAggregation, View
from opentelemetry.sdk.resources import Resource
from opentelemetry.sdk.trace import TracerProvider
from opentelemetry.sdk.trace.export import BatchSpanProcessor
from opentelemetry.trace import SpanKind, Status, StatusCode

PORT = int(os.environ.get("PORT", "8000"))
ERROR_RATE = float(os.environ.get("ERROR_RATE", "0.3"))
BACKEND_URL = os.environ.get("BACKEND_URL") or f"http://localhost:{PORT}"

# Buckets recomendados por las convenciones semánticas de OTel para duraciones HTTP (segundos).
HTTP_BUCKETS = [0.005, 0.01, 0.025, 0.05, 0.075, 0.1, 0.25, 0.5, 0.75, 1, 2.5, 5, 7.5, 10]

# --- Setup de OpenTelemetry ---------------------------------------------------

resource = Resource.create()  # lee OTEL_SERVICE_NAME y OTEL_RESOURCE_ATTRIBUTES

tracer_provider = TracerProvider(resource=resource)
tracer_provider.add_span_processor(BatchSpanProcessor(OTLPSpanExporter()))
trace.set_tracer_provider(tracer_provider)

meter_provider = MeterProvider(
    resource=resource,
    metric_readers=[PeriodicExportingMetricReader(OTLPMetricExporter())],
    views=[
        View(instrument_name="http.*.request.duration",
             aggregation=ExplicitBucketHistogramAggregation(HTTP_BUCKETS)),
    ],
)
metrics.set_meter_provider(meter_provider)

logger_provider = LoggerProvider(resource=resource)
logger_provider.add_log_record_processor(BatchLogRecordProcessor(OTLPLogExporter()))
set_logger_provider(logger_provider)

tracer = trace.get_tracer("observabilitylab.app")
meter = metrics.get_meter("observabilitylab.app")

server_duration = meter.create_histogram(
    "http.server.request.duration", unit="s", description="Duración de requests HTTP recibidos")
client_duration = meter.create_histogram(
    "http.client.request.duration", unit="s", description="Duración de requests HTTP salientes")
orders = meter.create_counter(
    "app.orders", unit="{order}", description="Órdenes procesadas, por resultado")

# --- Logging: OTLP + JSON por stdout ------------------------------------------

_RESERVED = set(vars(logging.makeLogRecord({}))) | {"message", "asctime"}


class JsonFormatter(logging.Formatter):
    def format(self, record):
        ctx = trace.get_current_span().get_span_context()
        entry = {
            "ts": self.formatTime(record, "%Y-%m-%dT%H:%M:%S"),
            "level": record.levelname.lower(),
            "msg": record.getMessage(),
        }
        if ctx.is_valid:
            entry["trace_id"] = format(ctx.trace_id, "032x")
            entry["span_id"] = format(ctx.span_id, "016x")
        entry.update({k: v for k, v in vars(record).items() if k not in _RESERVED})
        return json.dumps(entry)


stdout_handler = logging.StreamHandler(sys.stdout)
stdout_handler.setFormatter(JsonFormatter())
log = logging.getLogger("app")
log.setLevel(logging.INFO)
log.propagate = False
log.addHandler(stdout_handler)
log.addHandler(LoggingHandler(level=logging.INFO, logger_provider=logger_provider))

# --- Lógica de negocio simulada -----------------------------------------------


def call_backend(path):
    """Request HTTP saliente con propagación de contexto (traceparent)."""
    url = BACKEND_URL + path
    host = urlparse(url).hostname
    with tracer.start_as_current_span("GET", kind=SpanKind.CLIENT, attributes={
        "http.request.method": "GET", "url.full": url, "server.address": host,
    }) as span:
        headers = {}
        propagate.inject(headers)
        start = time.perf_counter()
        try:
            with urllib.request.urlopen(urllib.request.Request(url, headers=headers), timeout=5) as resp:
                status = resp.status
        except urllib.error.HTTPError as exc:
            status = exc.code
        span.set_attribute("http.response.status_code", status)
        if status >= 500:
            span.set_status(Status(StatusCode.ERROR))
        client_duration.record(time.perf_counter() - start, {
            "http.request.method": "GET", "server.address": host,
            "http.response.status_code": status,
        })
        return status


def handle_root():
    return 200, {"ok": True, "service": resource.attributes.get("service.name")}


def handle_work():
    with tracer.start_as_current_span("process_order"):
        time.sleep(random.expovariate(1 / 0.05))
        with tracer.start_as_current_span("SELECT orders", kind=SpanKind.CLIENT, attributes={
            "db.system.name": "postgresql", "db.operation.name": "SELECT",
            "db.collection.name": "orders",
        }):
            time.sleep(random.expovariate(1 / 0.1))
    orders.add(1, {"outcome": "ok"})
    return 200, {"ok": True, "work": "done"}


def handle_error():
    with tracer.start_as_current_span("charge_payment", attributes={"payment.provider": "fakepay"}):
        time.sleep(random.uniform(0.01, 0.05))
        if random.random() < ERROR_RATE:
            orders.add(1, {"outcome": "failed"})
            raise RuntimeError("payment provider timeout")
    orders.add(1, {"outcome": "ok"})
    return 200, {"ok": True}


def handle_checkout():
    statuses = [call_backend("/work"), call_backend("/error")]
    if any(s >= 500 for s in statuses):
        raise RuntimeError(f"checkout falló, backend respondió {statuses}")
    return 200, {"ok": True, "checkout": "complete"}


ROUTES = {
    "/": handle_root,
    "/work": handle_work,
    "/error": handle_error,
    "/checkout": handle_checkout,
}

# --- Servidor HTTP ------------------------------------------------------------


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        path = urlparse(self.path).path
        route = path if path in ROUTES else None
        ctx = propagate.extract(self.headers)
        start = time.perf_counter()

        with tracer.start_as_current_span(
            f"GET {route or ''}".strip(), context=ctx, kind=SpanKind.SERVER,
            record_exception=False, set_status_on_exception=False,
            attributes={"http.request.method": "GET", "url.path": path, **({"http.route": route} if route else {})},
        ) as span:
            try:
                status, body = ROUTES[route]() if route else (404, {"ok": False, "error": "not found"})
            except Exception as exc:  # noqa: BLE001 - es una demo
                span.record_exception(exc)
                status, body = 500, {"ok": False, "error": str(exc)}

            span.set_attribute("http.response.status_code", status)
            if status >= 500:
                span.set_status(Status(StatusCode.ERROR, body.get("error")))

            elapsed = time.perf_counter() - start
            attrs = {"http.request.method": "GET", "http.response.status_code": status}
            if route:
                attrs["http.route"] = route
            server_duration.record(elapsed, attrs)

            log.log(
                logging.ERROR if status >= 500 else logging.INFO,
                "%s %s -> %s", "GET", path, status,
                extra={**attrs, "url.path": path, "duration_ms": round(elapsed * 1000, 2),
                       **({"error.message": body["error"]} if status >= 500 else {})},
            )
            self._send(status, json.dumps(body).encode())

    def _send(self, status, body):
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass  # usamos nuestro propio log JSON/OTLP


def _shutdown(*_):
    sys.exit(0)


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, _shutdown)
    log.info("starting on port %s (backend=%s)", PORT, BACKEND_URL)
    try:
        ThreadingHTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
    finally:
        tracer_provider.shutdown()
        meter_provider.shutdown()
        logger_provider.shutdown()
