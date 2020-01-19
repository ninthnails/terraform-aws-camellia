#################
# Variables
#################
variable "prefix" {
  default = "camellia"
}

variable "vpc_id" {
}

variable "subnet_ids" {
  type = list(string)
}

variable "packer_template" {
  default = "aws-default.json"
}

variable "packer_instance_type" {
  default = "t3.micro"
  description = "Type of EC2 instance use for Packer. Must be an EBS optimized type."
}

variable "tags" {
  type = map(string)
  default = {}
}

#################
# Providers
#################
provider "archive" {
}

#################
# Data and local variables
#################
data "aws_region" "current" {}

data "aws_vpc" "this" {
  id = var.vpc_id
}

locals {
  bucket_name = "${var.prefix}-image-${data.aws_region.current.name}-${random_id.s3.hex}"
}

#################
# Resources
#################
resource "random_id" "s3" {
  byte_length = 16
}

resource "aws_s3_bucket" "source" {
  acl = "private"
  bucket = local.bucket_name
  region = data.aws_region.current.name
  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "aws:kms"
      }
    }
  }
  tags = merge(var.tags, map("Name", local.bucket_name))
  versioning {
    enabled = true
  }
}

resource "aws_iam_role" "service" {
  name = "${var.prefix}-kafka-codebuild"
  tags = var.tags
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "codebuild.amazonaws.com"
     },
     "Effect": "Allow"
   }
 ]
}
  EOF
}

resource "aws_iam_role_policy" "codebuild" {
  name = "codebuild"
  role = aws_iam_role.service.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:*",
        "ec2:CreateNetworkInterface",
        "ec2:DescribeNetworkInterfaces",
        "ec2:DeleteNetworkInterface",
        "ec2:DescribeSubnets",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeDhcpOptions",
        "ec2:DescribeVpcs",
        "ec2:CreateNetworkInterfacePermission"
      ],
      "Effect": "Allow",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion",
        "s3:PutObject"
      ],
      "Resource": [
        "arn:aws:s3:::${local.bucket_name}",
        "arn:aws:s3:::${local.bucket_name}/*"
      ]
    },
    {
      "Effect": "Allow",
      "Resource": [
        "arn:aws:s3:::${local.bucket_name}"
      ],
      "Action": [
        "s3:ListBucket",
        "s3:GetBucketAcl",
        "s3:GetBucketLocation"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "sts:DecodeAuthorizationMessage"
      ],
      "Resource": "*"
    },
    {
      "Sid": "PackerIAM",
      "Effect": "Allow",
      "Action": [
        "iam:PassRole",
        "iam:GetInstanceProfile"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
  EOF
}

resource "aws_iam_role" "packer" {
  name = "${var.prefix}-packer-instance-role"
  tags = var.tags
  assume_role_policy = <<EOF
{
 "Version": "2012-10-17",
 "Statement": [
   {
     "Action": "sts:AssumeRole",
     "Principal": {
       "Service": "ec2.amazonaws.com"
     },
     "Effect": "Allow"
   }
 ]
}
  EOF
}

resource "aws_iam_instance_profile" "packer" {
  name = aws_iam_role.packer.name
  role = aws_iam_role.packer.name
}

resource "aws_iam_role_policy" "packer" {
  name = "ec2"
  role = aws_iam_role.packer.id
  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [{
      "Effect": "Allow",
      "Action" : [
        "ec2:AttachVolume",
        "ec2:AuthorizeSecurityGroupIngress",
        "ec2:CopyImage",
        "ec2:CreateImage",
        "ec2:CreateKeypair",
        "ec2:CreateSecurityGroup",
        "ec2:CreateSnapshot",
        "ec2:CreateTags",
        "ec2:CreateVolume",
        "ec2:DeleteKeyPair",
        "ec2:DeleteSecurityGroup",
        "ec2:DeleteSnapshot",
        "ec2:DeleteVolume",
        "ec2:DeregisterImage",
        "ec2:DescribeImageAttribute",
        "ec2:DescribeImages",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus",
        "ec2:DescribeRegions",
        "ec2:DescribeSecurityGroups",
        "ec2:DescribeSnapshots",
        "ec2:DescribeSubnets",
        "ec2:DescribeTags",
        "ec2:DescribeVolumes",
        "ec2:DetachVolume",
        "ec2:GetPasswordData",
        "ec2:ModifyImageAttribute",
        "ec2:ModifyInstanceAttribute",
        "ec2:ModifySnapshotAttribute",
        "ec2:RegisterImage",
        "ec2:RunInstances",
        "ec2:StopInstances",
        "ec2:TerminateInstances",
        "ec2:CreateLaunchTemplate",
        "ec2:DeleteLaunchTemplate",
        "ec2:CreateFleet",
        "ec2:DescribeSpotPriceHistory"
      ],
      "Resource" : "*"
  }]
}
  EOF
}

resource "aws_cloudwatch_log_group" "packer" {
  name = "/aws/codebuild/${var.prefix}-kafka-automation-packer"
  retention_in_days = 7
}

resource "aws_security_group" "codebuild-egress" {
  name_prefix = "${var.prefix}-kafka-codebuild-"
  description = "Group that CodeBuild uses to allow access to resources in the VPC and the Internet."
  vpc_id = var.vpc_id
  egress {
    from_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
    to_port = 0
  }
  tags = merge(var.tags, map("Name", "${var.prefix}-kafka-codebuild"))
}

resource "aws_codebuild_project" "packer" {
  depends_on = [
    aws_iam_role.service,
    aws_iam_role_policy.codebuild
  ]
  name = "${var.prefix}-kafka-automation-packer"
  description = "Runs Packer to build AMI"
  service_role = aws_iam_role.service.arn

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.packer.name
    }
  }

  artifacts {
    type = "NO_ARTIFACTS"
  }

  environment {
    compute_type = "BUILD_GENERAL1_SMALL"
    image = "aws/codebuild/amazonlinux2-x86_64-standard:1.0"
    type = "LINUX_CONTAINER"
  }

  source {
    buildspec = <<EOF
---
version: 0.2
phases:
  install:
    runtime-versions:
       java: corretto8
    commands:
      - curl -sL -o packer.zip https://releases.hashicorp.com/packer/1.4.5/packer_1.4.5_linux_amd64.zip && unzip packer.zip
      - pip3 -q install 'ansible~=2.7,<2.8'
      - curl -sL https://bintray.com/sbt/rpm/rpm > /etc/yum.repos.d/bintray-sbt-rpm.repo
      - yum install -y sbt
      - mkdir project && echo "sbt.version=1.2.8" > project/build.properties
      - sbt --version
  pre_build:
    commands:
      - ./packer validate
        -var region=${data.aws_region.current.name}
        -var vpc_id=${data.aws_vpc.this.id}
        -var vpc_cidr=${data.aws_vpc.this.cidr_block}
        -var subnet_id=${var.subnet_ids[0]}
        -var ami_base_name=${var.prefix}
        -var iam_instance_profile=${aws_iam_instance_profile.packer.name}
        -var instance_type=${var.packer_instance_type}
        -var source_version=$${CODEBUILD_SOURCE_VERSION-LATEST}
        -var build_id=$${CODEBUILD_BUILD_ID-UNKNOWN}
        ${var.packer_template}
  build:
    commands:
      - ./packer build -color=false
        -var region=${data.aws_region.current.name}
        -var vpc_id=${data.aws_vpc.this.id}
        -var vpc_cidr=${data.aws_vpc.this.cidr_block}
        -var subnet_id=${var.subnet_ids[0]}
        -var ami_base_name=${var.prefix}
        -var iam_instance_profile=${aws_iam_instance_profile.packer.name}
        -var instance_type=${var.packer_instance_type}
        -var source_version=$${CODEBUILD_SOURCE_VERSION-LATEST}
        -var build_id=$${CODEBUILD_BUILD_ID-UNKNOWN}
        ${var.packer_template}
cache:
  paths:
    - '/root/.m2/repository/**/*'
    - '/root/.ivy2/cache/**/*'
    - '/root/.sbt/**/*'
    - '/root/.gradle/**/*'
EOF
    type = "S3"
    location = "${local.bucket_name}/codebuild/${var.prefix}-kafka-packer-sources.zip"
  }

  tags = var.tags

  vpc_config {
    security_group_ids = [aws_security_group.codebuild-egress.id]
    subnets = var.subnet_ids
    vpc_id = var.vpc_id
  }
}

data "archive_file" "sources" {
  type = "zip"
  output_path = "${path.module}/sources.zip"
  source_dir = "${path.module}/packer"
}

resource "aws_s3_bucket_object" "sources" {
  acl = "private"
  key = "codebuild/${var.prefix}-kafka-packer-sources.zip"
  bucket = local.bucket_name
  source = data.archive_file.sources.output_path
  storage_class = "STANDARD_IA"
  etag = data.archive_file.sources.output_md5
}

#################
# Outputs
#################
output "bucket_name" {
  value = local.bucket_name
}

output "build_command" {
  value = "aws --region ${data.aws_region.current.name} codebuild start-build --project-name ${aws_codebuild_project.packer.name}${length(replace(trimspace(aws_s3_bucket_object.sources.version_id), "null", "")) > 0 ? format(" --source-version '%s'", aws_s3_bucket_object.sources.version_id) : ""}"
}
