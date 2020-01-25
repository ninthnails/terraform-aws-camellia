#################
# Variables
#################
variable "aws_region" {
  default = "us-east-1"
}

variable "vpc_id" {
}

variable "private_subnet_ids" {
  type = list(string)
}

#################
# Providers
#################
provider "aws" {
  region = var.aws_region
  version = "~> 2.45"
}

provider "archive" {
  version = "~> 1.3"
}

provider "random" {
  version = "~> 2.2"
}

#################
# Modules
#################
module "image" {
  source = "../../image"
  packer_template = "aws-private.json"
  subnet_ids = var.private_subnet_ids
  vpc_id = var.vpc_id
}

#################
# Outputs
#################
output "packer_build_command" {
  value = module.image.build_command
}

output "s3_bucket_name" {
  value = module.image.bucket_name
}
