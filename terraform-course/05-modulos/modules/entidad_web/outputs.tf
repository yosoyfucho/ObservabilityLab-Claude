output "url" {
  value = "http://localhost:${var.puerto}"
}

output "container_name" {
  value = docker_container.web.name
}
