terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.62.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

resource "aws_security_group" "terraform-sg" {
  name = "terraform-sg"

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "web-server" {
  ami                   = "ami-07d3a50bd29811cd1"
  instance_type         = "t2.micro"
  user_data             = file("ec2-user-data.sh")
  vpc_security_group_ids = [aws_security_group.terraform-sg.id]

  tags = {
    Name = "web-server"
  }
}