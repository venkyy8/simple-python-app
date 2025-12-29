# Custom VPC
# Public subnets
# Internet Gateway + Route Table
# Security Group
# IAM Role for ECS
# ECS Cluster
# ECS Task Definition
# ECS Service (Fargate)

########################################
# 1️⃣ AWS Provider
########################################
provider "aws" {
  region = "us-east-1"
}

########################################
# 2️⃣ VPC
########################################
resource "aws_vpc" "python_app_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "python-sample-app-vpc"
  }
}

########################################
# 3️⃣ Public Subnets
########################################
resource "aws_subnet" "public_subnet_1" {
  vpc_id                  = aws_vpc.python_app_vpc.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "python-sample-app-public-subnet-1"
  }
}

resource "aws_subnet" "public_subnet_2" {
  vpc_id                  = aws_vpc.python_app_vpc.id
  cidr_block              = "10.0.2.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "python-sample-app-public-subnet-2"
  }
}

########################################
# 4️⃣ Internet Gateway
########################################
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.python_app_vpc.id

  tags = {
    Name = "python-sample-app-igw"
  }
}

########################################
# 5️⃣ Route Table + Association
########################################
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.python_app_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "python-sample-app-public-rt"
  }
}

resource "aws_route_table_association" "subnet1_assoc" {
  subnet_id      = aws_subnet.public_subnet_1.id
  route_table_id = aws_route_table.public_rt.id
}

resource "aws_route_table_association" "subnet2_assoc" {
  subnet_id      = aws_subnet.public_subnet_2.id
  route_table_id = aws_route_table.public_rt.id
}

########################################
# 6️⃣ Security Group
########################################
resource "aws_security_group" "ecs_sg" {
  name        = "python-sample-app-sg"
  description = "Allow Flask traffic"
  vpc_id      = aws_vpc.python_app_vpc.id

  ingress {
    from_port   = 5000
    to_port     = 5000
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

########################################
# 7️⃣ IAM Role for ECS Task Execution
########################################
resource "aws_iam_role" "ecs_execution_role" {
  name = "python-sample-app-ecs-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

########################################
# 8️⃣ ECS Cluster
########################################
resource "aws_ecs_cluster" "python_app_cluster" {
  name = "python-sample-app-cluster"
}

########################################
# 9️⃣ ECS Task Definition
########################################
resource "aws_ecs_task_definition" "python_app_task" {
  family                   = "python-sample-app-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "python-sample-app"
      image     = "084251039480.dkr.ecr.us-east-1.amazonaws.com/sample_python_app:5"
      essential = true

      portMappings = [
        {
          containerPort = 5000
          protocol      = "tcp"
        }
      ]
    }
  ])
}

########################################
# 🔟 ECS Service
########################################
resource "aws_ecs_service" "python_app_service" {
  name            = "python-sample-app-service"
  cluster         = aws_ecs_cluster.python_app_cluster.id
  task_definition = aws_ecs_task_definition.python_app_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [
      aws_subnet.public_subnet_1.id,
      aws_subnet.public_subnet_2.id
    ]
    security_groups = [aws_security_group.ecs_sg.id]
    assign_public_ip = true
  }

  depends_on = [
    aws_iam_role_policy_attachment.ecs_execution_policy
  ]
}

########################################
# 1️⃣1️⃣ Outputs
########################################
output "ecs_cluster_name" {
  value = aws_ecs_cluster.python_app_cluster.name
}

output "ecs_service_name" {
  value = aws_ecs_service.python_app_service.name
}

output "task_definition_arn" {
  value = aws_ecs_task_definition.python_app_task.arn
}


