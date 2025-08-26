output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "public_subnet_id" {
  description = "Public Subnet ID"
  value       = aws_subnet.public.id
}

output "security_group_id" {
  description = "Security Group ID"
  value       = aws_security_group.gatus_sg.id
}

output "ec2_public_ip" {
  description = "Public IP of the Gatus instance"
  value       = aws_instance.gatus.public_ip
}