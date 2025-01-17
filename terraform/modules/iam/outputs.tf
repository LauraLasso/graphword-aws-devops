output "ec2_instance_profile_name" {
  description = "Nombre del perfil de instancia EC2 vinculado al rol predeterminado."
  value       = aws_iam_instance_profile.ec2_instance_profile.name
}