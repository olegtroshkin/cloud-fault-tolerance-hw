variable "sa_key_file" {
  description = "Путь к JSON-ключу сервисного аккаунта"
  type        = string
}

variable "cloud_id" {
  description = "ID облака"
  type        = string
}

variable "folder_id" {
  description = "ID каталога"
  type        = string
}

variable "zone" {
  description = "Зона доступности"
  type        = string
  default     = "ru-central1-a"
}

variable "vm_count" {
  description = "Количество одинаковых ВМ"
  type        = number
  default     = 2
}

variable "vm_user" {
  description = "Имя пользователя на ВМ"
  type        = string
  default     = "ubuntu"
}

variable "ssh_public_key_path" {
  description = "Путь к публичному SSH-ключу"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}

variable "subnet_cidr" {
  description = "CIDR подсети"
  type        = string
  default     = "10.10.1.0/24"
}
