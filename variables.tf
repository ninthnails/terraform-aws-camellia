variable "prefix" {
  default = "camellia"
}

variable "vpc_id" {
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "private_zone_ids" {
  type = list(string)
  default = []
}

variable "manager_lb_acm_certificate_arn" {
  default = ""
}

variable "manager_lb_enabled" {
  default = false
}

variable "public_zone_id" {
  type = string
  default = ""
}

variable "allowed_cidrs" {
  type = map(list(string))
  default = {
    ipv4 = [
      "10.0.0.0/16"
    ]
    ipv6 = []
  }
}

variable "key_pair_name" {
}

variable "camellia_ami_id" {
  type = string
}

variable "zookeeper_instance_type" {
  default = "t3a.nano"
}

variable "zookeeper_cluster_size" {
  default = 1
}

variable "kafka_instance_type" {
  default = "t3a.nano"
}

variable "kafka_storage_type" {
  default = "ebs"
}

variable "kafka_storage_volume_type" {
  default = "gp2"
}

variable "kafka_storage_volume_size" {
  default = 1
}

variable "manager_admin_password" {
  default = ""
}

variable "manager_instance_type" {
  default = "t3a.nano"
}

variable "kafka_cluster_size" {
  default = 1
}

variable "tags" {
  type = map(string)
  default = {}
}
