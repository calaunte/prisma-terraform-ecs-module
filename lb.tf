# Create classic load balancer for Prisma Console
resource "aws_elb" "elb" {
    name = var.elb_name
    availability_zones = var.azs
    security_groups = [aws_security_group.console.id]

    listener {
        instance_port = 443
        instance_protocol = "https"
        lb_port = 443
        lb_protocol = "https"
        ssl_certificate_id = "${aws_acm_certificate.prisma.arn}"
    }

    listener {
        instance_port = 8083
        instance_protocol = "tcp"
        lb_port = 8083
        lb_protocol = "tcp"
    }

    listener {
        instance_port = 8084
        instance_protocol = "tcp"
        lb_port = 8084
        lb_protocol = "tcp"
    }

    health_check {
        healthy_threshold = 10
        unhealthy_threshold = 10
        timeout = 5
        target = "HTTP:8083/api/v1/_ping"
        interval = 30
    }

    tags = {
        Name = "pcs-ecs-lb"
    }
}

resource "aws_lb" "prisma" {
  name               = "prisma-cloud-test"
  internal           = false
  load_balancer_type = "application"
  security_groups = [aws_security_group.console.id]
  subnets            = var.public_subnets

  tags = {
    Environment = "pcs-ecs-lb"
  }
}

resource "aws_lb_target_group" "prisma" {
  name     = "prisma-cloud-test"
  port     = 443
  protocol = "HTTPS"
  vpc_id   = module.vpc.vpc_id

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 5
    target = "/api/v1/_ping"
    interval = 10
    port = 443
    protocol = "HTTPS"
  }
}

resource "aws_lb_listener" "prisma" {
  load_balancer_arn = aws_lb.prisma.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = "${aws_acm_certificate.prisma.arn}"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.prisma.arn
  }
}

# Create ssl certificate for prisma.betterup.co
resource "aws_acm_certificate" "prisma" {
    domain_name = var.domain_name
    validation_method = "DNS"
    tags = var.tags
}