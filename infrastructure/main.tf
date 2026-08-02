# ==========================================
# 1. PROVIDER VE BÖLGE AYARLARI
# ==========================================
provider "aws" {
  region = "eu-central-1" # Frankfurt bölgesi (İsteğine göre değiştirebilirsin)
}

# ==========================================
# 2. AĞ (VPC VE SUBNETLER)
# ==========================================
resource "aws_vpc" "main_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = { Name = "todo-app-vpc" }
}

# ALB ve NAT için Public Subnet 1
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "eu-central-1a"
  map_public_ip_on_launch = true
  tags = { Name = "todo-public-subnet-1" }
}

# ALB'nin Yüksek Erişilebilirliği için Public Subnet 2 (Farklı AZ)
resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "eu-central-1b"
  map_public_ip_on_launch = true
  tags = { Name = "todo-public-subnet-2" }
}

# EC2 (Docker) için Private Subnet
resource "aws_subnet" "private_subnet" {
  vpc_id            = aws_vpc.main_vpc.id
  cidr_block        = "10.0.3.0/24"
  availability_zone = "eu-central-1a"
  tags = { Name = "todo-private-subnet" }
}

# ==========================================
# 3. İNTERNET ÇIKIŞLARI (IGW VE NAT GATEWAY)
# ==========================================
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = { Name = "todo-igw" }
}

# NAT Gateway için Sabit IP (Elastic IP)
resource "aws_eip" "nat_eip" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat_gw" {
  allocation_id = aws_eip.nat_eip.id
  subnet_id     = aws_subnet.public_subnet_1.id
  depends_on    = [aws_internet_gateway.igw]
  tags = { Name = "todo-nat-gw" }
}

# ==========================================
# 4. YÖNLENDİRME TABLOLARI (ROUTE TABLES)
# ==========================================
# Public Route Table (İnternete IGW üzerinden çıkar)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}
resource "aws_route_table_association" "pub_sub_1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}
resource "aws_route_table_association" "pub_sub_2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

# Private Route Table (İnternete NAT Gateway üzerinden çıkar)
resource "aws_route_table" "private_rt" {
  vpc_id = aws_vpc.main_vpc.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw.id
  }
}
resource "aws_route_table_association" "priv_sub_assoc" {
  subnet_id      = aws_subnet.private_subnet.id
  route_table_id = aws_route_table.private_rt.id
}

# ==========================================
# 5. GÜVENLİK GRUPLARI (SECURITY GROUPS)
# ==========================================
# ALB Güvenlik Grubu (Dünyaya Açık)
resource "aws_security_group" "alb_sg" {
  name        = "todo-alb-sg"
  description = "ALB icin HTTP erisimi"
  vpc_id      = aws_vpc.main_vpc.id

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

# EC2 Güvenlik Grubu (Sadece ALB'den Gelen Trafiğe Açık)
resource "aws_security_group" "ec2_sg" {
  name        = "todo-ec2-sg"
  description = "EC2 icin sadece ALB den gelen erisim"
  vpc_id      = aws_vpc.main_vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id] # Kusursuz güvenlik izolasyonu!
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"] # Docker imajları ve API testleri için dışarı çıkış şart
  }
}

# ==========================================
# 6. SSM BAĞLANTISI İÇİN IAM ROLLERİ
# ==========================================
resource "aws_iam_role" "ssm_role" {
  name = "todo_ec2_ssm_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{ Action = "sts:AssumeRole", Effect = "Allow", Principal = { Service = "ec2.amazonaws.com" } }]
  })
}
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ssm_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}
resource "aws_iam_instance_profile" "ssm_profile" {
  name = "todo_ec2_ssm_profile"
  role = aws_iam_role.ssm_role.name
}

# ==========================================
# 7. EC2 SUNUCUSU VE DOCKER COMPOSE
# ==========================================
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "docker_host" {
  ami                  = data.aws_ami.amazon_linux_2.id
  instance_type        = "t3.medium"
  subnet_id            = aws_subnet.private_subnet.id
  security_groups      = [aws_security_group.ec2_sg.id]
  iam_instance_profile = aws_iam_instance_profile.ssm_profile.name

  tags = { Name = "todo-docker-host" }

  credit_specification {
    cpu_credits = "unlimited"
  }

  user_data = <<-EOF
    #!/bin/bash
    # Docker ve gerekli araçların kurulumu
    yum update -y
    amazon-linux-extras install docker -y
    service docker start
    usermod -a -G docker ec2-user
    chkconfig docker on

    # docker-compose kurulumu
    curl -L "https://github.com/docker/compose/releases/download/v2.24.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose

    # Proje klasörünü oluştur ve içine gir
    mkdir -p /home/ec2-user/todoapp
    cd /home/ec2-user/todoapp

    # Yeni hafif PostgreSQL tabanlı docker-compose.yml dosyasını oluştur
    cat << 'EOM' > docker-compose.yml
    version: '3.8'
    services:
      db:
        image: postgres:15-alpine
        container_name: todo_db
        environment:
          - POSTGRES_USER=postgres
          - POSTGRES_PASSWORD=A123456a*1
          - POSTGRES_DB=tododb
        networks:
          - backend-network

      api:
        image: hasiptektas/todo-app-aws-api
        container_name: todo_api
        environment:
          - DB_HOST=db
          - DB_PORT=5432
          - DB_USER=postgres
          - DB_PASS=A123456a*1
          - DB_NAME=tododb
        networks:
          - frontend-network
          - backend-network
        depends_on:
          - db

      frontend:
        image: hasiptektas/todo-app-aws-web
        container_name: todo_web
        ports:
          - "80:80"
        networks:
          - frontend-network
        depends_on:
          - api

    networks:
      frontend-network:
        driver: bridge
      backend-network:
        driver: bridge
    EOM

    # Sistemi ayağa kaldır
    /usr/local/bin/docker-compose up -d
  EOF
}

# ==========================================
# 8. APPLICATION LOAD BALANCER (ALB)
# ==========================================
resource "aws_lb" "todo_alb" {
  name               = "todo-app-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}

resource "aws_lb_target_group" "todo_tg" {
  name     = "todo-app-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main_vpc.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    interval            = 30
  }
}

resource "aws_lb_target_group_attachment" "todo_tg_attachment" {
  target_group_arn = aws_lb_target_group.todo_tg.arn
  target_id        = aws_instance.docker_host.id
  port             = 80
}

resource "aws_lb_listener" "http_listener" {
  load_balancer_arn = aws_lb.todo_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.todo_tg.arn
  }
}

# ==========================================
# 9. ÇIKTI (ÖDEVİN VİTRİNİ)
# ==========================================
output "uygulama_linki" {
  description = "Tarayıcıya kopyalanacak ALB DNS adresi"
  value       = "http://${aws_lb.todo_alb.dns_name}"
}