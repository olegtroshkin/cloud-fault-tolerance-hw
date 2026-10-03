# Домашнее задание к занятию «Отказоустойчивость в облаке» — Трошкин Олег

---

### Задание 1

Terraform Playbook создаёт в Yandex Cloud:

* сеть и подсеть;
* 2 одинаковые виртуальные машины (аргумент `count`), на которые через cloud-init устанавливается и запускается Nginx на порту 80;
* целевую группу, в которую помещены обе ВМ;
* сетевой балансировщик нагрузки: слушает порт 80, отправляет трафик на порт 80 ВМ, HTTP healthcheck на порт 80.

Все файлы лежат в папке [terraform](terraform/).

<details>
<summary><b>main.tf</b></summary>

```hcl
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
    nat       = true
  }

  scheduling_policy {
    preemptible = true
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
    port        = 80
    target_port = 80
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
```
</details>

<details>
<summary><b>cloud-init.yaml</b> — установка и запуск Nginx</summary>

```yaml
#cloud-config
users:
  - name: ${user}
    groups: sudo
    shell: /bin/bash
    sudo: ["ALL=(ALL) NOPASSWD:ALL"]
    ssh_authorized_keys:
      - ${ssh_key}

package_update: true
packages:
  - nginx

runcmd:
  - systemctl enable --now nginx
```
</details>

<details>
<summary><b>providers.tf</b></summary>

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    yandex = {
      source  = "yandex-cloud/yandex"
      version = ">= 0.120.0"
    }
  }
}

provider "yandex" {
  service_account_key_file = var.sa_key_file
  cloud_id                 = var.cloud_id
  folder_id                = var.folder_id
  zone                     = var.zone
}
```
</details>

<details>
<summary><b>outputs.tf</b></summary>

```hcl
output "vm_internal_ips" {
  value = yandex_compute_instance.vm[*].network_interface[0].ip_address
}

output "vm_external_ips" {
  value = yandex_compute_instance.vm[*].network_interface[0].nat_ip_address
}

output "lb_external_ip" {
  value = tolist(tolist(
    yandex_lb_network_load_balancer.lb.listener
  )[0].external_address_spec)[0].address
}
```
</details>

Результат `terraform apply`:

```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

lb_external_ip = "84.201.144.108"
vm_internal_ips = [
  "10.10.1.20",
  "10.10.1.23",
]
```

#### Статус балансировщика и целевой группы

Балансировщик `web-nlb` в статусе **Active**, обе ВМ в целевой группе `web-tg` в состоянии **Healthy**:



#### Запрос на внешний IP балансировщика

Запрос на `http://84.201.144.108` возвращает дефолтную страницу Nginx:


