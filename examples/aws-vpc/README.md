# AWS VPC Example

Setup a VPC using [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) 
module but creates bastion (jump box) and NAT instance, instead of the costly NAT Gateway. For development purposes.

## Usage
Create an auto variables file such as `example.auto.tfvars` with at minimum these:
```hcl-terraform
aws_region = "us-east-2"
ssh_key_name = "my-ssh-key-pair-name"
bastion_allowed_cidrs = [
  "1.2.3.4/32"
]
```

Then run Terraform as usual:
```shell script
terraform workspace new lab
terraform init
terraform plan -out terraform.tfplan
terraform apply terraform.tfplan
```

The bastion public IP address will be printed out so that you can SSH to it using your key.
```shell script
ssh -i my-ssh-key-pair.pem ec2-user@9.8.7.6
```

When you are down, delete the resources.
```shell script
terraform destroy
```
