output "instance_public_ip" { value = aws_instance.vm.public_ip }
output "instance_id"        { value = aws_instance.vm.id }
output "region"             { value = var.region }
