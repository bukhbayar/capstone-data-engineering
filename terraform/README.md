
# Directory structure
```
terraform_demo/
├── main.tf               # root module (wires VPC, S3, EC2)
├── versions.tf           # TF + provider versions
├── backend.tf            # (optional) remote state
├── variables.tf          # global variables
├── terraform.tfvars      # environment values
├── outputs.tf            # global outputs
└── modules/
    ├── vpc/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── s3_bucket/
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── ec2_instance/
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
```