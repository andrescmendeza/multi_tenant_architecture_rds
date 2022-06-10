# -----------------------------------------
# Certificate Data
# -----------------------------------------


data "aws_route53_zone" "app" {
  name = var.domain
}

data "aws_acm_certificate" "cert" {
  domain      = "*.${var.domain}"
  types       = ["AMAZON_ISSUED"]
  statuses    = ["ISSUED"]
  most_recent = true
}


# -----------------------------------------
# Public Load Balancer
# -----------------------------------------


resource "aws_alb" "load_balancer" {
  name            = "${terraform.workspace}-load-balancer"
  subnets         = aws_subnet.public.*.id
  security_groups = [aws_security_group.lb-sg.id]
}

# -----------------------------------------
# ALB Listener
# -----------------------------------------
# Create the listener rule to direct all api
# traffic to the correct target group

# Redirect all traffic from the ALB to the target group
resource "aws_alb_listener" "front_end_ssl" {
  load_balancer_arn = aws_alb.load_balancer.id
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = data.aws_acm_certificate.cert.arn

  default_action {
    type = "fixed-response"

    fixed_response {
      content_type = "text/plain"
      message_body = "Not Found"
      status_code  = "404"
    }
  }
}


# Redirect all traffic from the ALB to the target group

resource "aws_alb_listener" "front_end" {
  load_balancer_arn = aws_alb.load_balancer.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"

    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}



# -----------------------------------------
# Application Load Balancer
# -----------------------------------------
# Create the application load balancer

# ALB Security group
# This is the group you need to edit if you want to restrict access to your application
# ALB Security Group: Edit to restrict access to the application
resource "aws_security_group" "lb-sg" {
  name        = "${terraform.workspace}-alb-security-group"
  description = "controls access to the ALB"
  vpc_id      = aws_vpc.vpc.id

  ingress {
    protocol    = "tcp"
    from_port   = var.tcp_port1
    to_port     = var.tcp_port1
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    protocol    = "tcp"
    from_port   = var.tcp_port2
    to_port     = var.tcp_port2
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    protocol    = "-1"
    from_port   = 0
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Environment = terraform.workspace
  }
}

# Set up CloudWatch group and log stream and retain logs for n days
resource "aws_cloudwatch_log_group" "alb_log_group" {
  name              = "${terraform.workspace}-alb-log-sg"
  retention_in_days = var.cloudwatch_log_retention

  tags = {
    Environment = terraform.workspace
  }
}