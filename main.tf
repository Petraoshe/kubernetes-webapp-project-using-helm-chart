# 1.create A VPC Infrastructure
resource "aws_vpc" "kubenetes-vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "kubenetes-vpc"
  }
}
#  2.create public subnet1. 
resource "aws_subnet" "kubenetes-pub-sn1" {
  vpc_id            = aws_vpc.kubenetes-vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "eu-west-2a"
  tags = {
    Name = "kubenetes-pub_sn1"
  }
}

# 3.create public subnet2. 
resource "aws_subnet" "kubenetes-pub-sn2" {
  vpc_id            = aws_vpc.kubenetes-vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-west-2b"
  tags = {
    Name = "kubenetes-pub-sn2"
  }
}

# 6.internet gateways
resource "aws_internet_gateway" "kubenetes-igw" {
  vpc_id = aws_vpc.kubenetes-vpc.id
  tags = {
    Name = "kubenetes-igw"
  }
}

# 7. route tables
resource "aws_route_table" "kubenetes-rt" {
  vpc_id = aws_vpc.kubenetes-vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.kubenetes-igw.id
  }

  tags = {
    Name = "kubenetes-rt"
  }
}

# 8. route table association for Public Subnet1
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.kubenetes-pub-sn1.id
  route_table_id = aws_route_table.kubenetes-rt.id
}

#  10. route table association for Pubblic Subnet2
resource "aws_route_table_association" "c" {
  subnet_id      = aws_subnet.kubenetes-pub-sn2.id
  route_table_id = aws_route_table.kubenetes-rt.id
}

# 12. Security/port
resource "aws_security_group" "kubenetes-fe-sg" {
  name        = "kubenetes-fe-sg"
  description = "inbound tls"
  vpc_id      = aws_vpc.kubenetes-vpc.id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "jenkins"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Out all port to VPC"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "kubenetes-fe-sg"
  }
}

#Create a Keypair
resource "aws_key_pair" "kubenetes-key" {
  key_name   = var.keyname
  public_key = file(var.kubenetes-key)
}

#Create Master SErver
resource "aws_instance" "kubenetes-Master-Server" {
  ami                         = var.ami
  instance_type               = var.instance-type
  vpc_security_group_ids      = [aws_security_group.kubenetes-fe-sg.id]
  subnet_id                   = aws_subnet.kubenetes-pub-sn1.id
  key_name                    = var.keyname
  associate_public_ip_address = true
  tags = {
    Name = "kubenetes-Master-Server26"
  }
}

#Create Master SErver
resource "aws_instance" "kubenetes-Worker-Server" {
  count = 2
  ami                         = var.ami
  instance_type               = var.instance-type
  vpc_security_group_ids      = [aws_security_group.kubenetes-fe-sg.id]
  subnet_id                   = aws_subnet.kubenetes-pub-sn1.id
  key_name                    = var.keyname
  associate_public_ip_address = true
  tags = {
    Name = "kubenetes-Worker-Server${count.index}"
  }
}

data "aws_instance" "kubenetes-Master-Server" {
  filter {
    name   = "tag:Name"
    values = ["kubenetes-Master-Server26"]
  }
  depends_on = [
    aws_instance.kubenetes-Master-Server
  ]
}

data "aws_instance" "kubenetes-Worker-Server" {
  count = 2
  filter {
    name   = "tag:Name"
    values = ["kubenetes-Worker-Server${count.index}"]
  }
  depends_on = [
    aws_instance.kubenetes-Worker-Server
  ]
}

resource "aws_instance" "Kubenetes-Ansible-Server" {
  ami                         = var.ami
  instance_type               = var.instance-type
  vpc_security_group_ids      = [aws_security_group.kubenetes-fe-sg.id]
  subnet_id                   = aws_subnet.kubenetes-pub-sn2.id
  key_name                    = var.keyname
  associate_public_ip_address = true
  connection {  
      type        = "ssh" 
      host        = self.public_ip
      user        = "ubuntu"
      private_key = file("~/Keypairs/kubenetes-key")
    }  
  provisioner "file" {
    source      = "/Users/petra/Keypairs/kubenetes-key"
    destination = "/home/ubuntu/kubenetes-key" 
  }
  provisioner "file" {
      source = "/Users/petra/Downloads/kubernetes_project copy/yml"
      destination = "/home/ubuntu/yml"    
  }
     user_data = <<-EOF
#!/bin/bash
sudo apt-get update -y
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1    
sudo apt-get install software-properties-common -y
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt-get install ansible -y
sudo chmod 400 /home/ubuntu/kubenetes-key
sudo mkdir /etc/ansible
sudo touch /etc/ansible/hosts
sudo chown ubuntu:ubuntu /etc/ansible/hosts
sudo bash -c 'echo "StrictHostKeyChecking No" >> /etc/ssh/ssh_config'
sudo echo "[Master]" >> /etc/ansible/hosts
sudo echo "${data.aws_instance.kubenetes-Master-Server.public_ip} ansible_ssh_private_key_file=/home/ubuntu/kubenetes-key" >> /etc/ansible/hosts
sudo echo "[Workers]" >> /etc/ansible/hosts
sudo echo "${data.aws_instance.kubenetes-Worker-Server[0].public_ip} ansible_ssh_private_key_file=/home/ubuntu/kubenetes-key" >> /etc/ansible/hosts
sudo echo "${data.aws_instance.kubenetes-Worker-Server[1].public_ip} ansible_ssh_private_key_file=/home/ubuntu/kubenetes-key" >> /etc/ansible/hosts
sudo su -c 'ansible-playbook -i /etc/ansible/hosts /home/ubuntu/Playbook/installation.yml' ubuntu 
sudo su -c 'ansible-playbook -i /etc/ansible/hosts /home/ubuntu/Playbook/cluster.yml' ubuntu
sudo su -c 'ansible-playbook -i /etc/ansible/hosts /home/ubuntu/Playbook/join_master.yml' ubuntu  
   EOF 

  /* provisioner "remote-exec" {
      inline = [
        "sudo apt-get update -y",
        "sudo apt-get install software-properties-common -y",
        "sudo add-apt-repository --yes --update ppa:ansible/ansible", 
        "sudo apt-get install ansible -y", 
        "sudo chmod 400 /home/ubuntu/kubenetes-key",
        "sudo mkdir /etc/ansible", 
        "sudo touch /etc/ansible/hosts",
        "sudo chown ubuntu:ubuntu /etc/ansible/hosts",
        "sudo bash -c ' echo \"StrictHostKeyChecking No\" >> /etc/ssh/ssh_config'",
        "sudo echo \"[Master]\" >> /etc/ansible/hosts",
        "sudo echo \"${data.aws_instance.kubenetes-Master-Server.public_ip} ansible_ssh_private_key_file=/home/ubuntu/kubenetes-key\" >> /etc/ansible/hosts",
        "sudo echo \"[Workers]\" >> /etc/ansible/hosts",
        "sudo echo \"${data.aws_instance.kubenetes-Worker-Server[0].public_ip} ansible_ssh_private_key_file=/home/ubuntu/kubenetes-key\" >> /etc/ansible/hosts",
        "sudo echo \"${data.aws_instance.kubenetes-Worker-Server[1].public_ip} ansible_ssh_private_key_file=/home/ubuntu/kubenetes-key\" >> /etc/ansible/hosts",
        "ansible -m ping all",
        echo "${file(var.cluster_init_yml)}" >> /etc/ansible/cluster.yml
        "ansible-playbook -i /etc/ansible/hosts yml/installation.yml",
        "ansible-playbook -i /etc/ansible/hosts yml/cluster.yml",
        "ansible-playbook -i /etc/ansible/hosts yml/join_master.yml",
           
      ]
  }   */
  tags = {
    Name = "Kubenetes-Ansible-Server3"
  }
  
}
