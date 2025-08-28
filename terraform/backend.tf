terraform {
  backend "s3" {
    bucket       = "devops-project-terraform-state-2025"
    key          = "teraform/devops-project-terraform-state-2025/terraform.tfstate"
    region       = "eu-central-1"
    use_lockfile = true
    encrypt      = true
  }
}
