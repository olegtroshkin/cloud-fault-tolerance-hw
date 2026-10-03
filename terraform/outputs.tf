output "vm_internal_ips" {
  description = "Внутренние IP ВМ"
  value       = yandex_compute_instance.vm[*].network_interface[0].ip_address
}

output "vm_external_ips" {
  description = "Публичные IP ВМ"
  value       = yandex_compute_instance.vm[*].network_interface[0].nat_ip_address
}

output "lb_external_ip" {
  description = "Публичный IP балансировщика"
  value = tolist(tolist(
    yandex_lb_network_load_balancer.lb.listener
  )[0].external_address_spec)[0].address
}
