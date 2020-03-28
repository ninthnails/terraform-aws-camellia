#################
# Variables
#################
variable "environment" {
  default = "lab"
}

variable "admin_username" {
  default = "admin"
}

variable "admin_password" {
  default = ""
}

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
  default = true
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

variable "lb_acm_certificate_arn" {
  default = ""
}

variable "lb_domain_name" {
  default = ""
}

variable "public_zone_id" {
  default = ""
}

variable "cruise_control_http_port" {
  default = 9090
}

variable "cluster_manager_https_port" {
  default = 9443
}

variable "cluster_manager_http_port" {
  default = 9000
}

variable "kafka_broker_ids" {
  type = list(string)
}

variable "kafka_cluster_size" {
  type = number
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
data "aws_region" "this" {
}

data "aws_caller_identity" "this" {
}

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
  is_admin_password_systems_manager_parameter = length(regexall("^parameter/.*", var.admin_password)) > 0
  is_admin_password_secrets_manager_secret = length(regexall("^secrets/.*", var.admin_password)) > 0
  is_lb_https_enabled = length(trimspace(var.lb_acm_certificate_arn)) > 0

  http_protocol = var.lb_enabled && local.is_lb_https_enabled ? "HTTPS" : "HTTP"
  cruise_http_port = var.lb_enabled && local.is_lb_https_enabled ? var.cruise_control_http_port : var.cruise_control_http_port
  manager_http_port = var.lb_enabled && local.is_lb_https_enabled ? var.cluster_manager_https_port : var.cluster_manager_http_port

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
  description = "Security group for Cluster Manager for Apache Kafka"
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
  from_port = var.cruise_control_http_port
  to_port = var.cruise_control_http_port
  protocol = "tcp"
}

resource "aws_security_group_rule" "ingress-manager" {
  description = "HTTP Cluster Manager for Apache Kafka"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = var.cluster_manager_http_port
  to_port = var.cluster_manager_http_port
  protocol = "tcp"
}

resource "aws_security_group_rule" "ingress-manager-https" {
  description = "HTTPS Cluster Manager for Apache Kafka"
  type = "ingress"
  security_group_id = aws_security_group.private.id
  cidr_blocks = [
    data.aws_vpc.this.cidr_block
  ]
  from_port = var.cluster_manager_https_port
  to_port = var.cluster_manager_https_port
  protocol = "tcp"
}

resource "aws_security_group" "lb" {
  name_prefix = "${var.prefix}-manager-lb-"
  vpc_id = var.vpc_id
  description = "Security group for Kafka management tools"
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
  description = "Security group for Kafka management tools public access"
  tags = merge(var.tags, map("Name", "${var.prefix}-manager-public"))
  ingress {
    description = "Cluster Manager for Apache Kafka"
    from_port = var.cluster_manager_http_port
    protocol = "TCP"
    to_port = var.cluster_manager_http_port
    cidr_blocks = var.allowed_cidrs.ipv4
    ipv6_cidr_blocks = var.allowed_cidrs.ipv6
  }
  ingress {
    description = "Cruise Control"
    from_port = var.cruise_control_http_port
    protocol = "TCP"
    to_port = var.cruise_control_http_port
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
data "aws_iam_policy_document" "assume" {
  statement {
    actions = [
      "sts:AssumeRole"
    ]
    effect = "Allow"
    principals {
      identifiers = [
        "ec2.amazonaws.com"
      ]
      type = "Service"
    }
  }
}

resource "aws_iam_role" "server" {
  assume_role_policy = data.aws_iam_policy_document.assume.json
  name_prefix = "${var.prefix}-kafka-manager-server-"
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-manager-server"))
}

resource "aws_iam_instance_profile" "server" {
  name_prefix = "${var.prefix}-kafka-manager-server-"
  role = aws_iam_role.server.id
}

data "aws_iam_policy_document" "system-manager" {
  count = local.is_admin_password_systems_manager_parameter ? 1 : 0
  statement {
    actions = [
      "ssm:GetParameter"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:ssm:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:${var.admin_password}"
    ]
  }
}

data "aws_iam_policy_document" "secrets-manager" {
  count = local.is_admin_password_secrets_manager_secret ? 1 : 0
  statement {
    actions = [
      "secretsmanager:GetSecretValue"
    ]
    effect = "Allow"
    resources = [
      "arn:aws:secretsmanager:${data.aws_region.this.name}:${data.aws_caller_identity.this.account_id}:${var.admin_password}"
    ]
  }
}

resource "aws_iam_role_policy" "ssm" {
  count = local.is_admin_password_systems_manager_parameter ? 1 : 0
  name_prefix = "system-manager-"
  policy = data.aws_iam_policy_document.system-manager[0].json
  role = aws_iam_role.server.id
}

resource "aws_iam_role_policy" "secrets-manager" {
  count = local.is_admin_password_secrets_manager_secret ? 1 : 0
  name_prefix = "secrets-manager-"
  policy = data.aws_iam_policy_document.secrets-manager[0].json
  role = aws_iam_role.server.id
}

data "template_file" "user_data" {
  template = file("${path.module}/manager-user-data.tpl")

  vars = {
    admin_enabled = length(var.admin_username) > 0 && length(var.admin_password) > 0
    admin_username = var.admin_username
    admin_password = var.admin_password
    kafka_bootstrap_servers = var.kafka_bootstrap_servers
    kafka_zookeeper_connect = var.kafka_zookeeper_connect
    zookeeper_connect = var.zookeeper_connect
    capacity = "{ \"brokerCapacities\":[ ${local.capacity_default},${join(",", local.capacity_brokers)} ] }"
    cluster_environment = var.environment
    cluster_name = "${var.prefix}-kafka"
//    api_endpoint = format("%s/kafkacruisecontrol/", var.lb_enabled ? "${lower(aws_lb_listener.http[0].protocol)}//${aws_lb.alb[0].dns_name}" : "")
    api_endpoint = "/kafkacruisecontrol/"
    cruise_control_enabled = var.kafka_cluster_size > 1
    cruise_control_username = var.admin_username
    cruise_control_password = var.admin_password
    region = data.aws_region.this.name
    topic_replication_factor = var.kafka_cluster_size < 2 ? 1 : 2
  }
}

resource "aws_instance" "server" {
  ami = var.ami_id
  iam_instance_profile = aws_iam_instance_profile.server.id
  instance_type = var.instance_type
  subnet_id = data.aws_subnet.private[0].id
  vpc_security_group_ids = [
    aws_security_group.private.id
  ]
  key_name = var.key_pair_name
  ebs_optimized = false
  credit_specification {
    cpu_credits = "standard"
  }

  user_data = data.template_file.user_data.rendered

  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-manager"))

  lifecycle {
    create_before_destroy = true
  }
}

#################
# Load Balancer
#################
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
  name = "${var.prefix}-manager-cruise-http"
  port = local.cruise_http_port
  protocol = local.http_protocol
  vpc_id = var.vpc_id
  health_check {
    path = "/kafkacruisecontrol/state"
    protocol = local.http_protocol
  }
  tags = var.tags
}

resource "aws_lb_target_group_attachment" "cruise" {
  count = var.lb_enabled ? 1 : 0
  target_group_arn = aws_lb_target_group.cruise[0].arn
  target_id = aws_instance.server.id
  port = local.cruise_http_port
}

resource "aws_lb_target_group" "cluster" {
  count = var.lb_enabled ? 1 : 0
  name = "${var.prefix}-manager-cmak-http"
  port = local.manager_http_port
  protocol = local.http_protocol
  vpc_id = var.vpc_id
  health_check {
    matcher = "200,302,401"
    path = "/cmak/api/health"
    protocol = local.http_protocol
  }
  tags = var.tags
}

resource "aws_lb_target_group_attachment" "cluster" {
  count = var.lb_enabled ? 1 : 0
  target_group_arn = aws_lb_target_group.cluster[0].arn
  target_id = aws_instance.server.id
  port = local.manager_http_port
}

resource "aws_lb_listener" "http" {
  count = var.lb_enabled && !local.is_lb_https_enabled ? 1 : 0
  load_balancer_arn = aws_lb.alb[0].arn
  port = 80
  protocol = "HTTP"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cluster[0].arn
  }
}

resource "aws_lb_listener" "https" {
  count = var.lb_enabled && local.is_lb_https_enabled ? 1 : 0
  certificate_arn = var.lb_acm_certificate_arn
  load_balancer_arn = aws_lb.alb[0].arn
  port = 443
  protocol = "HTTPS"

  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cluster[0].arn
  }

  ssl_policy = "ELBSecurityPolicy-TLS-1-2-Ext-2018-06"
}

resource "aws_lb_listener_rule" "manager" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = local.is_lb_https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cluster[0].arn
    order = 20
  }
  condition {
    path_pattern {
      values = ["/cmak/*"]
    }
  }
}

resource "aws_lb_listener_rule" "cruise-static" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = local.is_lb_https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise[0].arn
    order = 30
  }
  condition {
    path_pattern {
      values = ["/static/*"]
    }
  }
}

resource "aws_lb_listener_rule" "cruise-ui" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = local.is_lb_https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise[0].arn
    order = 40
  }
  condition {
    path_pattern {
      values = ["/"]
    }
  }
}

resource "aws_lb_listener_rule" "cruise-api" {
  count = var.lb_enabled ? 1 : 0
  listener_arn = local.is_lb_https_enabled ? aws_lb_listener.https[0].arn : aws_lb_listener.http[0].arn
  action {
    type = "forward"
    target_group_arn = aws_lb_target_group.cruise[0].arn
  }
  condition {
    path_pattern {
      values = ["/kafkacruisecontrol/*"]
    }
  }
}

#################
# Routing
#################
resource "aws_route53_record" "public-alias" {
  count = var.lb_enabled && length(var.lb_domain_name) > 0 ? 1 : 0
  alias {
    evaluate_target_health = false
    name = aws_lb.alb[0].dns_name
    zone_id = aws_lb.alb[0].zone_id
  }
  name = var.lb_domain_name
  type = "A"
  zone_id = var.public_zone_id
}

#################
# Outputs
#################
output "public_cruise_control_endpoint" {
  value = var.lb_enabled ? format("%s://%s/", lower(local.http_protocol), aws_lb.alb[0].dns_name) : format("http://%s:%s/", aws_instance.server.private_ip, var.cruise_control_http_port)
}

output "public_cluster_manager_endpoint" {
  value = var.lb_enabled ? format("%s://%s/", lower(local.http_protocol), aws_lb.alb[0].dns_name) : format("http://%s:%s/cmak/", aws_instance.server.private_ip, var.cluster_manager_http_port)
}

output "cluster_manager_internal_http" {
  value = format("http://%s:%s/cmak/", aws_instance.server.private_ip, var.cluster_manager_http_port)
}

output "cluster_manager_internal_https" {
  value = format("https://%s:%s/cmak/", aws_instance.server.private_ip, var.cluster_manager_https_port)
}
