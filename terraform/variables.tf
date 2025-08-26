variable "region"              { type = string  default = "eu-central-1" }
variable "project_tag"         { type = string  default = "mock-gatus" }
variable "allow_ssh_from_cidr" { type = string  default = "" } # set your IP/CIDR to enable SSH, leave empty to disable
