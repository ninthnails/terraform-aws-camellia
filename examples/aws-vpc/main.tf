variable "aws_region" {
  default = "us-east-1"
}

variable "ssh_key_name" {
  default = "my-key"
}

variable "bastion_allowed_cidrs" {
  type = list(string)
  default = [
    "10.0.0.0/16"
  ]
}

provider "aws" {
  region = var.aws_region
  version = "~> 2.45"
}

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  zone_names = chunklist(data.aws_availability_zones.available.names, 3)[0]
  vpc_cidr = "10.0.0.0/16"
  private_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 1),
    cidrsubnet(local.vpc_cidr, 8, 2),
    cidrsubnet(local.vpc_cidr, 8, 3),
    cidrsubnet(local.vpc_cidr, 8, 4),
    cidrsubnet(local.vpc_cidr, 8, 5),
    cidrsubnet(local.vpc_cidr, 8, 6),
  ]
  public_subnets = [
    cidrsubnet(local.vpc_cidr, 8, 101),
    cidrsubnet(local.vpc_cidr, 8, 102),
    cidrsubnet(local.vpc_cidr, 8, 103),
    cidrsubnet(local.vpc_cidr, 8, 104),
    cidrsubnet(local.vpc_cidr, 8, 105),
    cidrsubnet(local.vpc_cidr, 8, 106),
  ]
}

module "vpc" {
  source = "terraform-aws-modules/vpc/aws"
  version = "2.22.0"

  name = "application"

  cidr = local.vpc_cidr

  azs = local.zone_names
  private_subnets = slice(local.private_subnets, 0, length(local.zone_names))
  public_subnets = slice(local.public_subnets, 0, length(local.zone_names))

  enable_ipv6 = false

  enable_nat_gateway = false
  single_nat_gateway = false
  one_nat_gateway_per_az = false

  create_database_subnet_group = false
  create_elasticache_subnet_group = false
  create_redshift_subnet_group = false

  enable_dns_hostnames = true
  enable_dns_support = true

  map_public_ip_on_launch = false

  private_subnet_tags = {
    Name = "private"
  }
  public_subnet_tags = {
    Name = "public"
  }

  tags = {
    Environment = "lab"
    Owner = "user"
    Terraform = "true"
  }

  vpc_tags = {
    Name = "application"
  }
}

// NAT Instance
resource "aws_security_group" "nat" {
  name_prefix = "nat-"
  ingress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  ingress {
    from_port = 443
    protocol = "TCP"
    to_port = 443
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  egress {
    from_port = 80
    protocol = "TCP"
    to_port = 80
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
  egress {
    from_port = 443
    protocol = "TCP"
    to_port = 443
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
  tags = {
    Name = "nat"
  }
  vpc_id = module.vpc.vpc_id
}

data "aws_ami" "amzn-nat" {
  most_recent = true
  name_regex = "amzn-ami-vpc-nat*"
  owners = [
    "amazon"
  ]
}

resource "aws_instance" "nat" {
  ami = data.aws_ami.amzn-nat.id
  instance_type = "t3a.nano"
  source_dest_check = false
  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.nat.id]
  ebs_optimized = false
  monitoring = false
  associate_public_ip_address = true
  lifecycle {
    ignore_changes = [ami]
    create_before_destroy = true
  }
  tags = {
    Name = "nat"
  }
}

resource "aws_route" "nat-private" {
  count = length(module.vpc.private_route_table_ids)
  route_table_id = module.vpc.private_route_table_ids[count.index]
  destination_cidr_block = "0.0.0.0/0"
  instance_id = aws_instance.nat.id
}

// Bastion
data "aws_ami" "amzn2" {
  most_recent = true
  name_regex = "amzn2-ami-hvm*"
  owners = [
    "amazon"
  ]
}

resource "aws_security_group" "bastion" {
  name = "bastion"
  vpc_id = module.vpc.vpc_id
  ingress {
    from_port = 22
    protocol = "TCP"
    to_port = 22
    cidr_blocks = var.bastion_allowed_cidrs
  }
  egress {
    description = "internet"
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }
  egress {
    description = "private"
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }
  lifecycle {
    create_before_destroy = true
  }
  tags = {
    Name = "bastion"
  }
}

resource "aws_instance" "bastion" {
  ami = data.aws_ami.amzn2.id
  instance_type = "t3a.nano"
  subnet_id = module.vpc.public_subnets[0]
  vpc_security_group_ids = [aws_security_group.bastion.id]
  ebs_optimized = false
  monitoring = false
  associate_public_ip_address = true
  key_name = var.ssh_key_name
  root_block_device {
    volume_size = 10
    delete_on_termination = true
  }
  lifecycle {
    ignore_changes = [ami]
    create_before_destroy = true
  }
  tags = {
    Name = "bastion"
  }
}

resource "aws_route53_zone" "local" {
  // See https://tools.ietf.org/html/rfc2606#section-2
  name = "local.example"
  vpc {
    vpc_id = module.vpc.vpc_id
  }
}

output "vpc_id" {
  value = module.vpc.vpc_id
}

output "private_subnets" {
  value = module.vpc.private_subnets
}

output "default_security_group_id" {
  value = module.vpc.default_security_group_id
}

output "local_zone" {
  value = aws_route53_zone.local
}

output "bastion_public_ip" {
  value = aws_instance.bastion.public_ip
}
