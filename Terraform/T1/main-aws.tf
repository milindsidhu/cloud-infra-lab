# # # aws terraform code

# # Get your current public IP dynamically
# data "http" "my_ip" {
#   url = "https://checkip.amazonaws.com/"
# }

# # Trim newline and append /32
# locals {
#   my_ip_cidr = "${chomp(data.http.my_ip.response_body)}/32"
# }

# # Create VPC
# resource "aws_vpc" "main" {
#   cidr_block           = "10.0.0.0/24"
#   enable_dns_support   = true
#   enable_dns_hostnames = true

#   tags = { Name = "main-vpc" }
# }

# # Create subnet
# resource "aws_subnet" "public" {
#   vpc_id                  = aws_vpc.main.id
#   cidr_block              = "10.0.1.0/24"
#   map_public_ip_on_launch = true
#   availability_zone       = "us-east-1a"

#   tags = { Name = "public-subnet" }
# }

# # Internet Gateway
# resource "aws_internet_gateway" "gw" {
#   vpc_id = aws_vpc.main.id

#   tags = { Name = "main-igw" }
# }

# # Route table
# resource "aws_route_table" "public" {
#   vpc_id = aws_vpc.main.id

#   route {
#     cidr_block = "0.0.0.0/0"
#     gateway_id = aws_internet_gateway.gw.id
#   }

#   tags = { Name = "public-rt" }
# }

# # Associate subnet with route table
# resource "aws_route_table_association" "a" {
#   subnet_id      = aws_subnet.public.id
#   route_table_id = aws_route_table.public.id
# }

# # Security group allowing SSH only from your IP
# resource "aws_security_group" "ssh_only" {
#   name        = "ssh-only"
#   description = "Allow SSH from my IP"
#   vpc_id      = aws_vpc.main.id

#   ingress {
#     from_port   = 22
#     to_port     = 22
#     protocol    = "tcp"
#     cidr_blocks = [local.my_ip_cidr]
#   }

#   egress {
#     from_port   = 0
#     to_port     = 0
#     protocol    = "-1"
#     cidr_blocks = ["0.0.0.0/0"]
#   }

#   tags = { Name = "ssh-only-sg" }
# }

# # Key Pair (use your existing public key)
# resource "aws_key_pair" "example" {
#   key_name   = "my-key"
#   public_key = file("~/.ssh/id_rsa.pub")
# }

# # EC2 Instance
# resource "aws_instance" "example" {
#   ami           = "ami-0c55b159cbfafe1f0" # Amazon Linux 2 in us-east-1 (update for your region)
#   instance_type = "t2.micro"
#   subnet_id     = aws_subnet.public.id
#   key_name      = aws_key_pair.example.key_name

#   vpc_security_group_ids = [aws_security_group.ssh_only.id]

#   tags = { Name = "restricted-ec2" }
# }

# output "instance_public_ip" {
#   value = aws_instance.example.public_ip
# }
