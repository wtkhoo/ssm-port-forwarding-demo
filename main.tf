variable "name" {
  description = "Prefix name for resources"
  type        = string
  default     = "ssm-demo"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "10.0.0.0/16"
  validation {
    condition     = can(regex("^(([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])\\.){3}([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])(\\/(1[6-9]|2[0-8]))$", var.vpc_cidr))
    error_message = "CIDR block parameter must be in the form x.x.x.x/16-28"
  }
}

data "aws_availability_zones" "az" {
  state = "available"
}

data "aws_ssm_parameter" "aml_latest_ami" {
  name = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

data "aws_ssm_parameter" "win_latest_ami" {
  name = "/aws/service/ami-windows-latest/Windows_Server-2022-English-Full-Base"
}

# ------------
# Barebone VPC
# ------------
resource "aws_vpc" "demo" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

# Private subnets
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 1)
  availability_zone = element(data.aws_availability_zones.az.names, 0)

  tags = {
    Name = "${var.name}-private-subnet-a"
  }
}

resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.demo.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, 2)
  availability_zone = element(data.aws_availability_zones.az.names, 1)

  tags = {
    Name = "${var.name}-private-subnet-b"
  }
}

# Route table and associations
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.demo.id

  tags = {
    Name = "${var.name}-private-rt"
  }
}

resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private.id
}

resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private.id
}

# Security group for EC2
resource "aws_security_group" "ec2" {
  description = "Security group for demo EC2 workloads"
  name        = "${var.name}-ec2"
  vpc_id      = aws_vpc.demo.id 
  egress      = [{
    cidr_blocks      = []
    description      = "HTTPS rule for VPC endpoints SG chaining"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = [aws_security_group.vpce.id]
    self             = false
    to_port          = 443
  },{
    cidr_blocks      = []
    description      = "MySQL rule for RDS instance SG chaining"
    from_port        = 3306
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = [aws_security_group.rds.id]
    self             = false
    to_port          = 3306
  }]
  ingress     = []
}

# Security group for RDS
resource "aws_security_group" "rds" {
  description = "Security group for demo RDS MySQL"
  name        = "${var.name}-rds"
  vpc_id      = aws_vpc.demo.id 
  egress      = []
  ingress     = [{
    cidr_blocks      = [var.vpc_cidr]
    description      = "Allow incoming traffic from VPC CIDR"
    from_port        = 3306
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 3306
  }]
}

# Security group for VPC endpoints
resource "aws_security_group" "vpce" {
  description = "Security group for demo VPC endpoints"
  name        = "${var.name}-vpce"
  vpc_id      = aws_vpc.demo.id
  egress      = []
  ingress     = [{
    cidr_blocks      = [var.vpc_cidr]
    description      = "Allow incoming HTTPS traffic from VPC CIDR"
    from_port        = 443
    ipv6_cidr_blocks = []
    prefix_list_ids  = []
    protocol         = "tcp"
    security_groups  = []
    self             = false
    to_port          = 443
  }]

}

# AWS SSM VPC interface endpoints (ssm, ssmmessages, ssm_ec2messages)
resource "aws_vpc_endpoint" "ssm" {
  ip_address_type      = "ipv4"
  private_dns_enabled  = true
  security_group_ids   = [aws_security_group.vpce.id]
  service_name         = "com.amazonaws.ap-southeast-2.ssm"
  subnet_ids           = [aws_subnet.private_a.id]
  vpc_endpoint_type    = "Interface"
  vpc_id               = aws_vpc.demo.id
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  tags = {
    Name = "ssm-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssm_ec2messages" {
  ip_address_type      = "ipv4"
  private_dns_enabled  = true
  security_group_ids   = [aws_security_group.vpce.id]
  service_name         = "com.amazonaws.ap-southeast-2.ec2messages"
  subnet_ids           = [aws_subnet.private_a.id]
  vpc_endpoint_type    = "Interface"
  vpc_id               = aws_vpc.demo.id
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  tags = {
    Name = "ssm-ec2messages-vpc-endpoint"
  }
}

resource "aws_vpc_endpoint" "ssmmessages" {
  ip_address_type      = "ipv4"
  private_dns_enabled  = true
  security_group_ids   = [aws_security_group.vpce.id]
  service_name         = "com.amazonaws.ap-southeast-2.ssmmessages"
  subnet_ids           = [aws_subnet.private_a.id]
  vpc_endpoint_type    = "Interface"
  vpc_id               = aws_vpc.demo.id
  dns_options {
    dns_record_ip_type = "ipv4"
  }
  tags = {
    Name = "ssmmessages-vpc-endpoint"
  }
}

# --------------------
# IAM role and profile
# --------------------
resource "aws_iam_role" "ec2_ssm_role" {
  name                 = "${var.name}-role"
  assume_role_policy   = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })

  managed_policy_arns = [
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
  ]
}

resource "aws_iam_instance_profile" "ssm_demo" {
  name = "${var.name}-profile"
  role = aws_iam_role.ec2_ssm_role.name
}

# ------------
# EC2 for demo
# ------------
# EC2 Linux
resource "aws_instance" "ssm_demo_linux" {
  ami                    = data.aws_ssm_parameter.aml_latest_ami.value
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm_demo.name
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # In real world, you don't want to set user password in user data block
  user_data = base64encode(
    <<-EOF
      #!/bin/bash
      #yum install -y https://s3.amazonaws.com/ec2-downloads-windows/SSMAgent/latest/linux_amd64/amazon-ssm-agent.rpm
      useradd ssm-demo
      echo "Password123" | passwd ssm-demo --stdin
      sed -E -i 's|^#?(PasswordAuthentication)\s.*|\1 yes|' /etc/ssh/sshd_config
      systemctl restart sshd
    EOF
  )

  tags = {
    Name = "${var.name}-linux"
  }
}

# EC2 Windows
resource "aws_instance" "ssm_demo_windows" {
  ami                    = data.aws_ssm_parameter.win_latest_ami.value
  instance_type          = "t3.micro"
  iam_instance_profile   = aws_iam_instance_profile.ssm_demo.name
  subnet_id              = aws_subnet.private_a.id
  vpc_security_group_ids = [aws_security_group.ec2.id]

  # In real world, you don't want to set user password in user data block
  user_data = base64encode(
  <<-EOF
    <powershell>
    net user Administrator Password123
    </powershell>
  EOF
  )

  tags = {
    Name = "${var.name}-windows"
  }
}

# ---------
# RDS MySQL
# ---------
resource "aws_db_instance" "ssm_demo_mysql" {
  allocated_storage      = 10
  db_name                = "demodb"
  identifier             = "${var.name}-mysql"
  engine                 = "mysql"
  engine_version         = "8.0.35"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = "Password123"
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true
  multi_az               = false
  vpc_security_group_ids = [aws_security_group.rds.id]
  db_subnet_group_name   = aws_db_subnet_group.ssm_demo_mysql.name

  tags = {
    Name = "${var.name}-mysql"
  }
}

# DB subnet group
resource "aws_db_subnet_group" "ssm_demo_mysql" {
  name = "${var.name}-db-subnet-group"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]

  tags = {
    Name = "${var.name}-db-subnet"
  }
}

# -------
# Outputs
# -------
output "ec2_linux_instance_id" {
  description = "The instance ID of the Linux demo instance"
  value       = aws_instance.ssm_demo_linux.id
}

output "ec2_windows_instance_id" {
  description = "The instance ID of the Windows demo instance"
  value       = aws_instance.ssm_demo_windows.id
}

output "rds_mysql_address" {
  description = "The address of the MySQL RDS demo instance"
  value       = aws_db_instance.ssm_demo_mysql.address
}