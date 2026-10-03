# ---------- Сеть ----------
resource "yandex_vpc_network" "net" {
  name = "lb-net"
}

resource "yandex_vpc_subnet" "subnet" {
  name           = "lb-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.net.id
  v4_cidr_blocks = [var.subnet_cidr]
}

# ---------- Образ ----------
data "yandex_compute_image" "ubuntu" {
  family = "ubuntu-2204-lts"
}

# ---------- 2 одинаковые ВМ (count) ----------
resource "yandex_compute_instance" "vm" {
  count       = var.vm_count
  name        = "web-${count.index + 1}"
  hostname    = "web-${count.index + 1}"
  platform_id = "standard-v3"
  zone        = var.zone

  resources {
    cores         = 2
    memory        = 2
    core_fraction = 20
  }

  boot_disk {
    initialize_params {
      image_id = data.yandex_compute_image.ubuntu.id
      size     = 10
      type     = "network-hdd"
    }
  }

  network_interface {
    subnet_id = yandex_vpc_subnet.subnet.id
    nat       = true # публичный IP — нужен ВМ для установки nginx из интернета
  }

  scheduling_policy {
    preemptible = true # прерываемые ВМ дешевле;
  }

  metadata = {
    user-data = templatefile("${path.module}/cloud-init.yaml", {
      user    = var.vm_user
      ssh_key = trimspace(file(pathexpand(var.ssh_public_key_path)))
    })
  }
}

# ---------- Целевая группа ----------
resource "yandex_lb_target_group" "tg" {
  name      = "web-tg"
  region_id = "ru-central1"

  dynamic "target" {
    for_each = yandex_compute_instance.vm
    content {
      subnet_id = yandex_vpc_subnet.subnet.id
      address   = target.value.network_interface[0].ip_address
    }
  }
}

# ---------- Сетевой балансировщик ----------
resource "yandex_lb_network_load_balancer" "lb" {
  name = "web-nlb"

  listener {
    name        = "http-listener"
    port        = 80 # слушает на 80
    target_port = 80 # отправляет на 80 порт ВМ
    protocol    = "tcp"

    external_address_spec {
      ip_version = "ipv4"
    }
  }

  attached_target_group {
    target_group_id = yandex_lb_target_group.tg.id

    healthcheck {
      name                = "http-hc"
      interval            = 2
      timeout             = 1
      unhealthy_threshold = 2
      healthy_threshold   = 2

      http_options {
        port = 80
        path = "/"
      }
    }
  }
}
