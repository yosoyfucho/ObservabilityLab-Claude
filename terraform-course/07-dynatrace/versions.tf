terraform {
  required_version = ">= 1.10"

  required_providers {
    dynatrace = {
      source  = "dynatrace-oss/dynatrace"
      version = "~> 1.107.0"
    }
  }
}

# El provider lee las credenciales de VARIABLES DE ENTORNO, nunca del código:
#   DYNATRACE_ENV_URL   = https://<env-id>.apps.dynatrace.com
#   DT_CLIENT_ID        = OAuth client (APIs de plataforma: buckets, settings, IAM)
#   DT_CLIENT_SECRET
#   DT_ACCOUNT_ID       = UUID de la cuenta (necesario para IAM)
# Ver README.md y el archivo credenciales.env.example.
provider "dynatrace" {}
