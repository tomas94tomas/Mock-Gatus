# Fill values here or via -backend-config on terraform init
#
# Example:
# terraform init \
#   -backend-config="bucket=your-tfstate-bucket" \
#   -backend-config="key=gatus/terraform.tfstate" \
#   -backend-config="region=eu-central-1" \
#   -backend-config="dynamodb_table=your-lock-table" \
#   -backend-config="encrypt=true"
terraform {
  backend "s3" {}
}