locals { name = var.project_tag }

data "aws_caller_identity" "current" {}

# VPC + Internet
resource "aws_vpc" "vpc" {
  cidr_block = "10.50.0.0/16"
  tags       = { Name = "${local.name}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.50.1.0/24"
  map_public_ip_on_launch = true
  tags                    = { Name = "${local.name}-public" }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

# SG (8080 open for demo; SSH optional)
resource "aws_security_group" "sg" {
  name   = "${local.name}-sg"
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.allow_ssh_from_cidr == "" ? [] : [1]
    content {
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [var.allow_ssh_from_cidr]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "al2023" {
  owners      = ["137112412989"]
  most_recent = true
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
  filter {
    name   = "architecture"
    values = ["x86_64"]
  }
}

############################################
# ROLES: Separate roles for EC2 and GitHub #
############################################

# (A) EC2 Instance Role for SSM (trusts EC2)
resource "aws_iam_role" "ec2_ssm_role" {
  name = "${local.name}-ec2-ssm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = { Service = "ec2.amazonaws.com" },
      Action   = "sts:AssumeRole"
    }]
  })
  tags = { Name = "${local.name}-ec2-ssm-role" }
}

# Minimum permissions for SSM-managed instance
resource "aws_iam_role_policy_attachment" "ec2_ssm_core" {
  role       = aws_iam_role.ec2_ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Optional: allow ECR pulls if needed later
# resource "aws_iam_role_policy_attachment" "ec2_ecr_read" {
#   role       = aws_iam_role.ec2_ssm_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
# }

# Instance profile referencing the EC2 role
resource "aws_iam_instance_profile" "ec2_ssm_profile" {
  name = "${local.name}-ec2-ssm-ip"
  role = aws_iam_role.ec2_ssm_role.name
}

# (B) GitHub OIDC Role (for Actions to assume)
# Keep this if you use GitHub OIDC to run terraform/apply, etc.
resource "aws_iam_role" "gh_oidc_role" {
  name = "${local.name}-ssm-ec2-role-v2"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect = "Allow",
      Principal = {
        Federated = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:oidc-provider/token.actions.githubusercontent.com"
      }
      Action = "sts:AssumeRoleWithWebIdentity",
      Condition = {
        StringLike = {
          "token.actions.githubusercontent.com:sub" = "repo:tomas94tomas/Mock-Gatus:*"
        }
      }
    }]
  })
  tags = { Name = "${local.name}-gh-oidc-role" }
}

resource "aws_iam_role_policy_attachment" "gh_oidc_admin" {
  role       = aws_iam_role.gh_oidc_role.name
  policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
}

############################################

# Cloud-init: install Docker + Compose, prep /opt/gatus (for later)
data "template_cloudinit_config" "user_data" {
  base64_encode = true
  part {
    content_type = "text/cloud-config"
    content      = <<-YAML
      packages: [ docker ]
      runcmd:
        - usermod -aG docker ec2-user
        - systemctl enable --now docker
        - curl -L https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m) -o /usr/local/bin/docker-compose
        - chmod +x /usr/local/bin/docker-compose
        - mkdir -p /opt/gatus/config
    YAML
  }
}

resource "aws_instance" "vm" {
  ami                    = data.aws_ami.al2023.id
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  # Use the proper EC2 instance profile for SSM
  iam_instance_profile   = aws_iam_instance_profile.ec2_ssm_profile.name

  user_data_base64       = data.template_cloudinit_config.user_data.rendered
  tags                   = { Name = "${local.name}-ec2" }
}
