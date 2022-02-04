#Variável feita para ser aplicada em:
#Bloco interface de rede
#Bloco ip público
variable "priv_ip"{
  type = string
  description = "define o IP privado"

}


#A documentação pode ser encontrada com "aws terraform recurso_necessario"
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "3.74.0"
    }
  }
}

#Configurações pro terraform se comunicar com a AWS
provider "aws" {
  region     = "us-east-1"
  #access_key = ""
  #secret_key = ""

}

#Define uma vpc na amazon (rede) para a comunicação com o terraform
resource "aws_vpc" "vpc_brq" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "VPC_juan"
  }
}

#gateway (comunicação entre o vpc e a internet) chamado gw brq (no terraform) e nome gatejuan na aws
resource "aws_internet_gateway" "gw_brq" {
  vpc_id = aws_vpc.vpc_brq.id
  tags = {
    Name = "gateJuan"
  }
}

#definindo duas rotas. Todo o tráfego da rede vai pro gateway
resource "aws_route_table" "rotas_brq" {
  vpc_id = aws_vpc.vpc_brq.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw_brq.id
  }

  route {
    ipv6_cidr_block = "::/0"
    gateway_id      = aws_internet_gateway.gw_brq.id
  }

  tags = {
    Name = "rotaJuan"
  }
}

#subrede
resource "aws_subnet" "subrede_brq" {
  vpc_id            = aws_vpc.vpc_brq.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a" 
  #a, b ou c
  #muitos recursos se conectando, o que pode dar problema
  tags = {
    Name = "subredeJuan"
  }
}

#associação entre a subnet e a tabela de roteamento
#instancias criadas na aws tem redes sob essas rotas
resource "aws_route_table_association" "associacao" {
  subnet_id      = aws_subnet.subrede_brq.id
  route_table_id = aws_route_table.rotas_brq.id
}

#criando um firewall, grupo de segurança
#quais portas serão aceitas
resource "aws_security_group" "firewall" {
  name        = "open_the_door"
  description = "Abrir porta 22 (SSH), 443 (HTTPS) e 80 (HTTP)"
  vpc_id      = aws_vpc.vpc_brq.id

#firewall, você pode abrir essa porta que tá chegando aí
#mas só quem está com esse ip
#ip com tudo 0: abrir pra rede toda
  ingress {
    description = "HTTPS"
    from_port   = 443 #from port to port: range de portas
    to_port     = 443
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
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "firewallJuan"
  }
}

#criando interface de rede
resource "aws_network_interface" "interface_rede" {
  subnet_id       = aws_subnet.subrede_brq.id
  private_ips     = [var.priv_ip]
  security_groups = [aws_security_group.firewall.id]
  tags = {
    Name = "interfaceJuan"
  }
}


#criando um ip público
resource "aws_eip" "ip_publico" {
  vpc                       = true
  network_interface         = aws_network_interface.interface_rede.id
  associate_with_private_ip = var.priv_ip
  #esse recurso(do bloco) vai depender desse outro
  #então o terraform é obrigado a criar um e o outro dps
  depends_on                = [aws_internet_gateway.gw_brq]
}

output "printar_ip_publico"{
  value = aws_eip.ip_publico.public_ip
}

#criando instância com uma página da web
resource "aws_instance" "app_web" {
  ami               = "ami-04505e74c0741db8d"
  instance_type     = "t2.micro"
  availability_zone = "us-east-1a"

  network_interface {
    device_index         = 0
    network_interface_id = aws_network_interface.interface_rede.id
  }
  #Com o terraform é possível configurar máquinas
  #Estou entrando na máquina e rodando comandos
  # o -y se refere a um auto approve. Já garante o yes de resposta
  #O terraform cria a máquina e o ansible configura
  user_data = <<-EOF
               #! /bin/bash
               sudo apt-get update -y
               sudo apt-get install -y apache2
               sudo systemctl start apache2
               sudo systemctl enable apache2
               sudo bash -c 'echo "<h1>Juan Lira e Terraform: rodando com sucesso</h1>"  > /var/www/html/index.html'
             EOF
  tags = {
    Name = "appJuan"
  }
}