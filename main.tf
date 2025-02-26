provider "aws" {
  region = var.aws_region  # 원하는 리전 설정 (서울 리전)
  profile = "terraform-user"
}

### VPC
resource "aws_vpc" "blog_prd_vpc" {
  cidr_block = var.vpc_cidr

  tags = {
    Name = "blog-prd-vpc"
  }
}

### 서브넷
# 퍼블릭 서브넷
resource "aws_subnet" "public_subnet_1" {
  vpc_id            = aws_vpc.blog_prd_vpc.id
  cidr_block        = var.public_subnet_1_cidr
  map_public_ip_on_launch = true  # 퍼블릭 IP 자동 할당
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "blog-prd-public-subnet-1"
  }
}

# 프라이빗 서브넷
resource "aws_subnet" "private_subnet_1" {
  vpc_id            = aws_vpc.blog_prd_vpc.id
  cidr_block        = var.private_subnet_1_cidr
  availability_zone = var.availability_zones[0]

  tags = {
    Name = "blog-prd-private-subnet-1"
  }
}

### 두 번째 프라이빗 서브넷 추가
resource "aws_subnet" "private_subnet_2" {
  vpc_id            = aws_vpc.blog_prd_vpc.id
  cidr_block        = var.private_subnet_2_cidr
  availability_zone = var.availability_zones[1]  # 다른 가용 영역

  tags = {
    Name = "blog-prd-private-subnet-2"
  }
}


### igw, 라우팅 테이블
# 인터넷 게이트웨이
resource "aws_internet_gateway" "blog_prd_igw" {
  vpc_id = aws_vpc.blog_prd_vpc.id

  tags = {
    Name = "blog-prd-igw"
  }
}

# 라우트 테이블
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.blog_prd_vpc.id

  route {
    cidr_block = "0.0.0.0/0"  # 모든 인터넷 트래픽을 IGW로 보냄
    gateway_id = aws_internet_gateway.blog_prd_igw.id
  }

  tags = {
    Name = "blog-prd-public-route-table"
  }
}

resource "aws_route_table_association" "public_route_table_association" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_route_table.id
}

### EC2
# EC2 키 페어 생성 (이미 있다면 건너뛰기)
resource "aws_key_pair" "blog_key_pair" {
  key_name   = "blog-key-pair"  # 키 페어 이름
  public_key = file("~/.ssh/blog-key-pair.pub")  # 공개 키 파일 경로
}

# 보안 그룹 생성 (SSH와 HTTP 포트 열기)
resource "aws_security_group" "blog_security_group" {
  vpc_id = aws_vpc.blog_prd_vpc.id

#  ingress {
#    from_port   = 20
#    to_port     = 21
#    protocol    = "tcp"
#    cidr_blocks = ["0.0.0.0/0"]  # 모든 IP에서 SSH 접속 허용
#  }

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]  # 내 IP에서 SSH 접속 허용
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP 트래픽 허용
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  # HTTP 트래픽 허용
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]  # 모든 외부 연결 허용
  }

  tags = {
    Name = "blog-prd-security-group"
  }
}

# 퍼블릭 서브넷에 EC2 인스턴스 생성
resource "aws_instance" "blog_instance" {
  ami           = "ami-0b0bfe6dd7d14ae24"  # 최신 Amazon Linux 2023 AMI ID
  instance_type = "t4g.small"
  subnet_id     = aws_subnet.public_subnet_1.id
  key_name      = aws_key_pair.blog_key_pair.key_name

  # 보안 그룹을 vpc_security_group_ids로 지정
  vpc_security_group_ids = [aws_security_group.blog_security_group.id]

  tags = {
    Name = "blog-prd-ec2-instance"
  }
}

# EIP 연결
# Elastic IP 생성
resource "aws_eip" "blog_eip" {
  instance = aws_instance.blog_instance.id

  tags = {
    Name = "blog-prd-eip"
  }
}

# EIP Domain 연결
# Route 53 A 레코드 생성
resource "aws_route53_record" "blog_a_record" {
  zone_id = var.route53_zone_id  # Route 53 Hosted Zone ID
  name    = "blog.lohen.kim"  # 도메인 이름
  type    = "A"
  ttl     = 300
  records = [aws_eip.blog_eip.public_ip]  # EIP 연결
}



### RDS
# RDS Subnet group
resource "aws_db_subnet_group" "blog_db_subnet_group" {
  name       = "blog-db-subnet-group"
  subnet_ids = [aws_subnet.private_subnet_1.id, aws_subnet.private_subnet_2.id]

  tags = {
    Name = "blog-db-subnet-group"
  }
}

# RDS SG
resource "aws_security_group" "blog_db_security_group" {
  vpc_id = aws_vpc.blog_prd_vpc.id

  # MySQL 포트 3306: EC2 인스턴스에서만 접근 허용
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    security_groups = [aws_security_group.blog_security_group.id]  # EC2에서만 접근 허용
  }

  # 아웃바운드 규칙 (기본적으로 모든 트래픽을 허용)
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "blog-db-security-group"
  }
}

# RDS
resource "aws_db_instance" "blog_db" {
  allocated_storage    = 20        # 20GB 스토리지
  storage_type         = "gp3"     # General Purpose SSD (gp3)
  engine               = "mysql"   # MySQL 데이터베이스 엔진
  engine_version       = "8.0"     # MySQL 버전
  instance_class       = "db.t4g.micro"  # db.t4g.micro 인스턴스 타입
  db_subnet_group_name = aws_db_subnet_group.blog_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.blog_db_security_group.id]
  db_name              = var.db_name  # 데이터베이스 이름
  username             = var.db_username  # 관리자 계정
  password             = var.db_password  # 데이터베이스 비밀번호
  multi_az             = false  # 다중 AZ 배포 여부
  publicly_accessible  = false  # 퍼블릭 접근을 비활성화
  skip_final_snapshot  = true   # 최종 스냅샷을 비활성화

  tags = {
    Name = "blog-db-instance"
  }
}

