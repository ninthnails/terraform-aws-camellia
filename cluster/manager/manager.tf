#################
# Variables
#################
variable "vpc_id" {
}

variable "private_subnet_ids" {
  type = list(string)
}

variable "public_subnet_ids" {
  type = list(string)
}

variable "prefix" {
  default = "camellia"
}

variable "ami_id" {
}

variable "key_pair_name" {
}

variable "kms_key_id" {
  default = "alias/aws/ebs"
}

variable "instance_type" {
  default = "t3a.nano"
}

variable "lb_enabled" {
  default = false
}

variable "allowed_cidrs" {
  type = map(list(string))
  default = {
    ipv4 = [
      "0.0.0.0/0"
    ]
    ipv6 = [
      "::/0"
    ]
  }
}

variable "public_zone_id" {
}

variable "cruise_control_port" {
  default = 9090
}

variable "kafka_manager_port" {
  default = 9000
}

variable "kafka_broker_ids" {
  type = list(string)
}

variable "kafka_storage_volume_size" {
  type = number
}

variable "kafka_network_throughput_KB" {
  type = number
}

variable "kafka_bootstrap_servers" {
}

variable "kafka_zookeeper_connect" {
}

variable "zookeeper_connect" {
}

variable "tags" {
  type = map(string)
  default = {}
}

#################
# Data and Local Variables
#################
data "aws_vpc" "this" {
  id = var.vpc_id
}

data "aws_subnet" "private" {
  count = length(var.private_subnet_ids)
  id = var.private_subnet_ids[count.index]
}

data "aws_subnet" "public" {
  count = length(var.public_subnet_ids)
  id = var.public_subnet_ids[count.index]
}

locals {
  capacity_template = {brokerId: "%s", capacity: {DISK: "%s", CPU: "100", NW_IN: "%s", NW_OUT: "%s"}}
  capacity_default = format(jsonencode(local.capacity_template), "-1",
    var.kafka_storage_volume_size > 4 ? var.kafka_storage_volume_size - 2 : var.kafka_storage_volume_size,
    floor(var.kafka_network_throughput_KB / 2),
    ceil(var.kafka_network_throughput_KB / 2))
  capacity_brokers = formatlist(jsonencode(local.capacity_template), var.kafka_broker_ids,
    var.kafka_storage_volume_size > 4 ? var.kafka_storage_volume_size - 2 : var.kafka_storage_volume_size,
    floor(var.kafka_network_throughput_KB / 2),
    ceil(var.kafka_network_throughput_KB / 2))
}

#################
# Security Groups
#################
resource "aws_security_group" "private" {
  name_prefix = "${var.prefix}-manager-private-"
  vpc_id = var.vpc_id
  description = "Security group for Kafka Manager"
  tags = merge(var.tags, map("Name", "${var.prefix}-manager-private"))
}

resource "aws_security_group_rule" "egress-all" {
  from_port = 0
  protocol = "all"
  security_group_id = aws_security_group.private.id
  cidr_blocks = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  to_port = 65535
  type = "egress"
}

resource "aws_security_group_rule" "ingress-ssh" {
  type = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = "22"
  to_port = "22"
  protocol = "tcp"
}

resource "aws_security_group_rule" "ingress-cruise" {
  description = "HTTP Cruise Control"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = var.cruise_control_port
  to_port = var.cruise_control_port
  protocol = "tcp"
}

resource "aws_security_group_rule" "ingress-manager" {
  description = "HTTP Kafka Manager"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = var.kafka_manager_port
  to_port = var.kafka_manager_port
  protocol = "tcp"
}

resource "aws_security_group" "lb" {
  name_prefix = "${var.prefix}-manager-lb-"
  vpc_id = var.vpc_id
  description = "Security group for Kafka Manager"
  tags = merge(var.tags, map("Name", "${var.prefix}-manager-lb"))
  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = var.allowed_cidrs.ipv4
  }
  ingress {
    from_port = 443
    protocol = "TCP"
    to_port = 443
    cidr_blocks = var.allowed_cidrs.ipv4
  }
  egress {
    from_port = 0
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    to_port = 65535
  }
}

resource "aws_security_group" "public" {
  count = var.lb_enabled ? 0 : 1
  name_prefix = "${var.prefix}-manager-public-"
  vpc_id = var.vpc_id
  description = "Security group for Kafka Manager public access"
  tags = merge(var.tags, map("Name", "${var.prefix}-manager-public"))
  ingress {
    description = "Kafka Manager"
    from_port = var.kafka_manager_port
    protocol = "TCP"
    to_port = var.kafka_manager_port
    cidr_blocks = var.allowed_cidrs.ipv4
    ipv6_cidr_blocks = var.allowed_cidrs.ipv6
  }
  ingress {
    description = "Cruise Control"
    from_port = var.cruise_control_port
    protocol = "TCP"
    to_port = var.cruise_control_port
    cidr_blocks = var.allowed_cidrs.ipv4
    ipv6_cidr_blocks = var.allowed_cidrs.ipv6
  }
  egress {
    from_port = 0
    protocol = "TCP"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    to_port = 65535
  }
}

#################
# EC2 Instance
#################
data "template_file" "user_data" {
  template = file("${path.module}/manager-user-data.tpl")

  vars = {
    kafka_bootstrap_servers = var.kafka_bootstrap_servers
    kafka_zookeeper_connect = var.kafka_zookeeper_connect
    zookeeper_connect = var.zookeeper_connect
    capacity = "{ \"brokerCapacities\":[ ${local.capacity_default},${join(",", local.capacity_brokers)} ] }"
    cluster_name = "${var.prefix}-kafka"
    api_endpoint = format("%s/kafkacruisecontrol/", var.lb_enabled ? "${lower(aws_lb_listener.http[0].protocol)}//${aws_lb.alb[0].dns_name}" : "http://${aws_eip.public[0].public_ip}:${var.cruise_control_port}")
  }
}

resource "aws_instance" "server" {
  ami = var.ami_id
  instance_type = var.instance_type
  subnet_id = data.aws_subnet.private[0].id
  vpc_security_group_ids = [
    aws_security_group.private.id
  ]
  key_name = var.key_pair_name

  user_data = data.template_file.user_data.rendered

  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-manager"))

  lifecycle {
    create_before_destroy = true
  }
}

#################
# Load Balancer and Public Access
#################
data "aws_subnet" "same-zone" {
  availability_zone_id = data.aws_subnet.private[0].availability_zone_id
  filter {
    name = "subnet-id"
    values = var.public_subnet_ids
  }
}

resource "aws_network_interface" "public" {
  count = var.lb_enabled ? 0 : 1
  subnet_id = data.aws_subnet.same-zone.id
  private_ips_count = 0
  security_groups = [
    aws_security_group.public[0].id
  ]
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-manager"))
}

resource "aws_network_interface_attachment" "server-public" {
  count = var.lb_enabled ? 0 : 1
  device_index = 1
  instance_id = aws_instance.server.id
  network_interface_id = aws_network_interface.public[0].id
}

resource "aws_eip" "public" {
  count = var.lb_enabled ? 0 : 1
  network_interface = aws_network_interface.public[0].id
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-manager"))
}

resource "aws_lb" "alb" {
  count = var.lb_enabled ? 1 : 0
  internal = false
  load_balancer_type = "application"
  security_groups = [
    aws_security_group.lb.id
  ]
  subnets = data.aws_subnet.public.*.id
  enable_http2 = true

  tags = merge(var.tags, map("Name", "${var.prefix}-manager-lb"))
}

resource "aws_lb_target_group" "cruise" {
  count = var.lb_enabled ? 1 : 0
  port = var.cruise_control_port
  protocol = "HTTP"
  vpc_id = var.vpc_id
  health_check {
    path = "/kafkacruisecontrol/state"
  }
}

resource "aws_lb_target_group_attachment" "cruise" {
  count = var.lb_enabled ? 1 : 0
  target_group_arn = aws_lb_target_group.cruise[0].arn
  target_id = aws_instance.server.id
  port = var.cruise_control_port
}

resource "aws_lb_target_group" "manager" {
  count = var.lb_enabled ? 1 : 0
  port = var.kafka_manager_port
  protocol = "HTTP"
  vpc_id = var.vpc_id
  health_check {
    path = "/kafkamanager"
  }
}

resource "aws_lb_target_group_attachment" "manager" {
  count = var.lb_enabled ? 1 : 0
  target_group_arn = aws_lb_target_group.manager[0].arn
  target_id = aws_instance.server.id
  port = var.kafka_manager_port
}

resource "aws_lb_listener" "http" {
  count = var.lb_enabled ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.manager[0].arn
  }
}

resource "aws_lb_listener_rule" "manager" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.manager[0].arn
    order = 20
  }
  condition {
    field  = "path-pattern"
    values = ["/kafkamanager/*"]
  }
}

resource "aws_lb_listener_rule" "cruise-static" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise[0].arn
    order = 30
  }
  condition {
    field  = "path-pattern"
    values = ["/static/*"]
  }
}

resource "aws_lb_listener_rule" "cruise-ui" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise[0].arn
    order = 40
  }
  condition {
    field  = "path-pattern"
    values = ["/"]
  }
}

resource "aws_lb_listener_rule" "cruise-api" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise[0].arn
  }
  condition {
    field  = "path-pattern"
    values = ["/kafkacruisecontrol/*"]
  }
}

#################
# Outputs
#################
output "public_cruise_control_endpoint" {
  value = var.lb_enabled ? format("%s://%s/", lower(aws_lb_listener.http[0].protocol), aws_lb.alb[0].dns_name) : format("http://%s:%s/", aws_eip.public[0].public_ip, var.cruise_control_port)
}
output "public_kafka_manager_endpoint" {
  value = var.lb_enabled ? format("%s://%s/", lower(aws_lb_listener.http[0].protocol), aws_lb.alb[0].dns_name) : format("http://%s:%s/kafkamanager/", aws_eip.public[0].public_ip, var.kafka_manager_port)
}
