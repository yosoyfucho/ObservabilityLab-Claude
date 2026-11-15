# Parte 1: un bucket de Grail, igual al que creamos a mano en la interfaz,
# pero ahora como código.

resource "dynatrace_platform_bucket" "lab_tf" {
  name         = "observabilitylab_tf_logs"
  display_name = "ObservabilityLab logs (Terraform)"
  table        = "logs"
  retention    = 10
}

output "bucket" {
  value = {
    name   = dynatrace_platform_bucket.lab_tf.name
    status = dynatrace_platform_bucket.lab_tf.status
  }
}
