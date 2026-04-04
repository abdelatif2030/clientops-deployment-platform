output "app_server_public_ip" {
  description = "Public IP of the App EC2 instance"
  value       = aws_instance.app_server.public_ip
}

output "monitoring_server_public_ip" {
  description = "Public IP of the Monitoring EC2 instance"
  value       = aws_instance.monitoring_server.public_ip
}
