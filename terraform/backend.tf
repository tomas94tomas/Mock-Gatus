terraform {
  backend "s3" {
    bucket = "devops-project-terraform-state-2025"
    key    = "terraform/terraform.tfstate" 
    region = "eu-central-1"
    encrypt = true
  }
}
