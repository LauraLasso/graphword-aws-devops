output "ec2_instance_ips" {
  value = aws_instance.other_instances.*.public_ip
}