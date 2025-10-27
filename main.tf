# ---------- Fetch latest Amazon Linux 2023 AMI via SSM Parameter (region-aware) ----------
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# ---------- Network ----------
resource "aws_vpc" "vpc" {
  cidr_block = "10.10.0.0/16"
  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id
  tags   = { Name = "${var.project}-igw" }
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = "10.10.1.0/24"
  map_public_ip_on_launch = true
  availability_zone       = "${var.aws_region}a"
  tags = { Name = "${var.project}-public-subnet" }
}

resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-public-rt" }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# ---------- Security Group (allow HTTP & ICMP for testing) ----------
resource "aws_security_group" "web_sg" {
  name   = "${var.project}-web-sg"
  vpc_id = aws_vpc.vpc.id

  description = "Allow HTTP (80) and ICMP and ephemeral egress"

  ingress {
    description      = "http"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
  }

  ingress {
    description = "icmp from anywhere (ping)"
    from_port   = -1
    to_port     = -1
    protocol    = "icmp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-web-sg" }
}

# ---------- EC2 Instance (uses AMI from SSM parameter) ----------
resource "aws_instance" "web" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = "t3.micro"
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]
  associate_public_ip_address = true
  tags = { Name = "${var.project}-web" }

  # user_data installs nginx and writes a small page including instance-id
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y nginx
              systemctl enable --now nginx
              echo "<h1>Terraform POC: ${var.project}</h1><p>Instance: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)</p>" > /usr/share/nginx/html/index.html
              EOF

  # small root block device to avoid large storage
  root_block_device {
    volume_size = 8
    volume_type = "gp3"
  }
}

# ---------- Outputs ----------
output "instance_id" {
  value = aws_instance.web.id
}

output "public_ip" {
  value = aws_instance.web.public_ip
}

output "ami_used" {
  value = data.aws_ssm_parameter.al2023_ami.value
  sensitive = true
  description = "AMI ID fetched from SSM parameter"
}
