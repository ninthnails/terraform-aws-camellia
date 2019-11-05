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
  default = "t3a.medium"
}

variable "lb_allowed_cidrs" {
  type = list(string)
  default = [
    "0.0.0.0/0"
  ]
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
resource "aws_security_group" "main" {
  name_prefix = "${var.prefix}-manager-private-"
  vpc_id = var.vpc_id
  description = "Security group for Kafka Manager"
  tags = merge(var.tags, map("Name", "${var.prefix}-manager-private"))
}

resource "aws_security_group_rule" "egress-all" {
  from_port = 0
  protocol = "all"
  security_group_id = aws_security_group.main.id
  cidr_blocks = ["0.0.0.0/0"]
  ipv6_cidr_blocks = ["::/0"]
  to_port = 65535
  type = "egress"
}

resource "aws_security_group_rule" "ingress-ssh" {
  type = "ingress"
  security_group_id = aws_security_group.main.id
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
  security_group_id = aws_security_group.main.id
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
  security_group_id = aws_security_group.main.id
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
    cidr_blocks = var.lb_allowed_cidrs
  }
  ingress {
    from_port = 443
    protocol = "TCP"
    to_port = 443
    cidr_blocks = var.lb_allowed_cidrs
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
    api_endpoint = "${lower(aws_lb_listener.http.protocol)}://${aws_lb.alb.dns_name}/kafkacruisecontrol/"
  }
}

resource "aws_instance" "server" {
  ami = var.ami_id
  instance_type = var.instance_type
  subnet_id = data.aws_subnet.private.*.id[0]
  vpc_security_group_ids = [
    aws_security_group.main.id
  ]
  key_name = var.key_pair_name

  user_data = data.template_file.user_data.rendered

  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-manager"))
}

#################
# Load Balancer
#################
resource "aws_lb" "alb" {
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
  port = var.cruise_control_port
  protocol = "HTTP"
  vpc_id = var.vpc_id
  health_check {
    path = "/kafkacruisecontrol/state"
  }
}

resource "aws_lb_target_group_attachment" "cruise" {
  target_group_arn = aws_lb_target_group.cruise.arn
  target_id = aws_instance.server.id
  port = var.cruise_control_port
}

resource "aws_lb_target_group" "manager" {
  port = var.kafka_manager_port
  protocol = "HTTP"
  vpc_id = var.vpc_id
  health_check {
    path = "/kafkamanager"
  }
}

resource "aws_lb_target_group_attachment" "manager" {
  target_group_arn = aws_lb_target_group.manager.arn
  target_id = aws_instance.server.id
  port = var.kafka_manager_port
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port = "80"
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.manager.arn
  }
}

resource "aws_lb_listener_rule" "manager" {
  listener_arn = aws_lb_listener.http.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.manager.arn
    order = 20
  }
  condition {
    field  = "path-pattern"
    values = ["/kafkamanager/*"]
  }
}

resource "aws_lb_listener_rule" "cruise-static" {
  listener_arn = aws_lb_listener.http.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise.arn
    order = 30
  }
  condition {
    field  = "path-pattern"
    values = ["/static/*"]
  }
}

resource "aws_lb_listener_rule" "cruise-ui" {
  listener_arn = aws_lb_listener.http.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise.arn
    order = 40
  }
  condition {
    field  = "path-pattern"
    values = ["/"]
  }
}

resource "aws_lb_listener_rule" "cruise-api" {
  listener_arn = aws_lb_listener.http.arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise.arn
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
  value = "${lower(aws_lb_listener.http.protocol)}://${aws_lb.alb.dns_name}/"
}
output "public_kafka_manager_endpoint" {
  value = "${lower(aws_lb_listener.http.protocol)}://${aws_lb.alb.dns_name}/kafkamanager/"
}
