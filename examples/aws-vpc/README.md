# AWS VPC Example

Setup a VPC using [terraform-aws-modules/vpc/aws](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws) 
module but creates a NAT instance, instead of the costly NAT Gateway. For development purposes only.

## Usage
Create an auto variables file such as `example.auto.tfvars` with at minimum these:
```hcl
aws_region = "us-east-2"
ssh_key_name = "my-ssh-key-pair-name"
```

Then run Terraform as usual:
```shell
terraform workspace new lab
terraform init
terraform plan -out terraform.tfplan
terraform apply terraform.tfplan
```

You can connect to the EC2 instance using SSM Session Manager, either through AWS Console or using the CLI:
```shell
aws --region us-east-2 ssm start-session --target i-1234567890abcdef0
```

When you are done, delete the resources.
```shell
terraform destroy
```
