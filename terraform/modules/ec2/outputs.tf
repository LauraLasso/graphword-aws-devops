output "ec2_instance_ips" {
  value = aws_instance.module_instances.*.public_ip
}