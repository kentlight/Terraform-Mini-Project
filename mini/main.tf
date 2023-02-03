# VPC

resource "aws_vpc" "Bond_vpc" {
    cidr_block           = "10.0.0.0/16"
    enable_dns_hostnames = true
    tags = {
      Name = "Bond_vpc"
      }
}


# Internet Gateway

  resource "aws_internet_gateway" "Bond_internet_gateway" {
    vpc_id = aws_vpc.Bond_vpc.id
    tags ={
        Name = "Bond_internet_gateway"
    }
  }


  # Public Route Table

  resource "aws_route_table" "Bond-route-table-public" {
    vpc_id = aws_vpc.Bond_vpc.id

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = aws_internet_gateway.Bond_internet_gateway.id
    }

    tags = {
        Name = "Bond-route-table-public"
    }
  }

# Associate public subnet 1 with public route table

resource "aws_route_table_association" "Bond-public-subnet1-association" {
    subnet_id      = aws_subnet.Bond-public-subnet1.id
    route_table_id = aws_route_table.Bond-route-table-public.id
}


# Associate public subnet 2 with public route table

resource "aws_route_table_association" "Bond-public-subnet2-association" {
    subnet_id      = aws_subnet.Bond-public-subnet2.id
    route_table_id = aws_route_table.Bond-route-table-public.id
}




# Public Subnet-1

resource "aws_subnet" "Bond-public-subnet1" {
    vpc_id                  = aws_vpc.Bond_vpc.id
    cidr_block              = "10.0.1.0/24"
    map_public_ip_on_launch = true
    availability_zone       = "eu-west-2a"
    tags = {
        Name = "Bond-public-subnet1"
    }
}

# Public Subnet-2

resource "aws_subnet" "Bond-public-subnet2" {
    vpc_id                  = aws_vpc.Bond_vpc.id
    cidr_block              = "10.0.2.0/24"
    map_public_ip_on_launch = true
    availability_zone       = "eu-west-2b"
    tags = {
        Name = "Bond-public-subnet2"
    }
}

# Network ACL

resource "aws_network_acl" "Bond-network-acl" {
    vpc_id    = aws_vpc.Bond_vpc.id
    subnet_ids = [aws_subnet.Bond-public-subnet1.id, aws_subnet.Bond-public-subnet2.id]

 ingress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  egress {
    rule_no    = 100
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
}



# Security group for the load balanceer

resource "aws_security_group" "Bond-load_balancer_sg"  {
    name        = "Bond-load-balancer-sg"
    description = "Security group for the load balancer"
    vpc_id      = aws_vpc.Bond_vpc.id


 ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


# Security Group to allow port 22, 80 and 443

resource "aws_security_group" "Bond-security-grp-rule" {
  name        = "allow_ssh_http_https"
  description = "Allow SSH, HTTP and HTTPS inbound traffic for public instances"
  vpc_id      = aws_vpc.Bond_vpc.id
  

 ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.Bond-load_balancer_sg.id]
  }


 ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    security_groups = [aws_security_group.Bond-load_balancer_sg.id]
  }

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
   
  }

  tags = {
    Name = "Bond-security-grp-rule"
  }
}


#  instance 1

resource "aws_instance" "Bond1" {
  ami             = "ami-0dafa2e497e84663c"
  instance_type   = "t2.micro"
  key_name        = "testing_instance"
  security_groups = [aws_security_group.Bond-security-grp-rule.id]
  subnet_id       = aws_subnet.Bond-public-subnet1.id
  availability_zone = "eu-west-2a"

  tags = {
    Name   = "Bond-1"
    source = "terraform"
  }
}

# instance 2

 resource "aws_instance" "Bond2" {
  ami             = "ami-0dafa2e497e84663c"
  instance_type   = "t2.micro"
  key_name        = "testing_instance"
  security_groups = [aws_security_group.Bond-security-grp-rule.id]
  subnet_id       = aws_subnet.Bond-public-subnet2.id
  availability_zone = "eu-west-2b"
  

  tags = {
    Name   = "Bond-2"
    source = "terraform"
  }
}


# instance 3

resource "aws_instance" "Bond3" {
  ami             = "ami-0dafa2e497e84663c"
  instance_type   = "t2.micro"
  key_name        = "testing_instance"
  security_groups = [aws_security_group.Bond-security-grp-rule.id]
  subnet_id       = aws_subnet.Bond-public-subnet1.id
  availability_zone = "eu-west-2a"

  

  tags = {
    Name   = "Bond-3"
    source = "terraform"
  }
}

 
# To store the IP addresses of the instances

resource "local_file" "Ip_address" {
  filename = "/root/bob/host-inventory"
  content  = <<EOT
${aws_instance.Bond1.public_ip}
${aws_instance.Bond2.public_ip}
${aws_instance.Bond3.public_ip}
  EOT
}


# Application Load Balancer

resource "aws_lb" "Bond-load-balancer" {
  name               = "Bond-load-balancer"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.Bond-load_balancer_sg.id]
  subnets            = [aws_subnet.Bond-public-subnet1.id, aws_subnet.Bond-public-subnet2.id]
  enable_deletion_protection = false
  depends_on                 = [aws_instance.Bond1, aws_instance.Bond2, aws_instance.Bond3]
}



# The target group

resource "aws_lb_target_group" "Bond-target-group" {
  name     = "Bond-target-group"
  target_type = "instance"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.Bond_vpc.id

  health_check {
    path                = "/"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 15
    timeout             = 3
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}


# The listener

resource "aws_lb_listener" "Bond-listener" {
  load_balancer_arn = aws_lb.Bond-load-balancer.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Bond-target-group.arn
  }
}


# The listener rule

resource "aws_lb_listener_rule" "Bond-listener-rule" {
  listener_arn = aws_lb_listener.Bond-listener.arn
  priority     = 1

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.Bond-target-group.arn
  }

  condition {
    path_pattern {
      values = ["/"]
    }
  }
}




# Attaching the target group to the load balancer

resource "aws_lb_target_group_attachment" "Bond-target-group-attachment1" {
  target_group_arn = aws_lb_target_group.Bond-target-group.arn
  target_id        = aws_instance.Bond1.id
  port             = 80

}
 
resource "aws_lb_target_group_attachment" "Bond-target-group-attachment2" {
  target_group_arn = aws_lb_target_group.Bond-target-group.arn
  target_id        = aws_instance.Bond2.id
  port             = 80
}

resource "aws_lb_target_group_attachment" "Bond-target-group-attachment3" {
  target_group_arn = aws_lb_target_group.Bond-target-group.arn
  target_id        = aws_instance.Bond3.id
  port             = 80 
  
  }













































