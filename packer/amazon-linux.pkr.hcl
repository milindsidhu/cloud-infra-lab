packer {
  required_plugins {
    amazon = {
      version = ">= 1.2.0"
      source  = "github.com/hashicorp/amazon"
    }
  }
}

variable "instance_type" {
  type        = string
  description = "EC2 instance type for the build"
  default     = "t3.micro"
}

variable "region" {
  type        = string
  description = "AWS region to build in"
  default     = "ap-south-1"
}

variable "ami_name" {
  type        = string
  description = "Name to give the resulting AMI"
  default     = "my-app"
}

source "amazon-ebs" "app" {
  ami_name      = "${var.ami_name}-{{timestamp}}"
  instance_type = var.instance_type
  region        = var.region

  source_ami_filter {
    filters = {
      name                = "al2023-ami-*-x86_64"
      root-device-type    = "ebs"
      virtualization-type = "hvm"
    }
    owners      = ["amazon"]
    most_recent = true
  }

  ssh_username = "ec2-user"
}

build {
  sources = ["source.amazon-ebs.app"]

  provisioner "shell" {
    inline = [
      "sudo yum update -y",
      "sudo yum install -y nginx",
      "sudo systemctl enable nginx"
    ]
  }
}
