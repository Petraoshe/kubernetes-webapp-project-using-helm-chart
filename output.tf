output "Kubenetes-Ansible-Server" {
  value = aws_instance.Kubenetes-Ansible-Server.public_ip
}

output "kubenetes-Master-Server" {
  value = aws_instance.kubenetes-Master-Server.public_ip
}

output "kubenetes-Worker-Server" {
  value = aws_instance.kubenetes-Worker-Server.*.public_ip
}
