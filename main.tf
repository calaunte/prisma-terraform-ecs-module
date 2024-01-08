# Create VPC for ECS cluster
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name            = var.vpc_name
  azs             = var.azs
  cidr            = var.cidr
  public_subnets  = var.public_subnets
  private_subnets = var.private_subnets

  enable_nat_gateway = true
  single_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = var.tags
}

# Creates Ecs cluster
resource "aws_ecs_cluster" "cluster" {
  name = var.cluster_name

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# Create ECS cluster for defenders
resource "aws_ecs_cluster" "defender" {
  name = "pc-cluster-defenders"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# Create ECS Task Definitions
resource "aws_ecs_task_definition" "service" {
  family       = "pc-console"
  network_mode = "bridge"
  container_definitions = jsonencode([
    {
      name              = "twistlock-console"
      image             = "registry-auth.twistlock.com/tw_toetxipkxnuletqvq57fv4eefecyj1qa/twistlock/console:console_30_03_122"
      memoryReservation = 3000
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group: "prisma-console-logs",
          awslogs-region: "us-east-1",
          awslogs-create-group: "true",
          awslogs-stream-prefix: "bu"
        }
      }
      portMappings = [
        {
          containerPort = 8084,
          hostPort      = 8084,
          protocol      = "tcp"
        },
        {
          containerPort = 8083,
          hostPort      = 8083,
          protocol      = "tcp"
        },
        {
          containerPort = 443,
          hostPort      = 443,
          protocol      = "https"
        }
      ]
      essential = true
      command = [
        "/app/server"
      ]
      environment = [
        {
          "name" : "SERVICE",
          "value" : "twistlock"
        },
        {
          "name" : "CONSOLE_CN",
          "value" : ""
        },
        {
          "name" : "CONSOLE_SAN",
          "value" : "IP:<ADD_LB_DNS_NAME>"
        },
        {
          "name" : "HIGH_AVAILABILITY_ENABLED",
          "value" : "false"
        },
        {
          "name" : "KUBERNETES_ENABLED",
          "value" : ""
        },
        {
          "name" : "KERBEROS_ENABLED",
          "value" : "false"
        },
        {
          "name" : "CONFIG_PATH",
          "value" : "/twistlock_console/var/lib/twistlock-config"
        },
        {
          "name" : "LOG_PROD",
          "value" : "true"
        },
        {
          "name" : "DATA_RECOVERY_ENABLED",
          "value" : "true"
        },
        {
          "name" : "COMMUNICATION_PORT",
          "value" : "8084"
        },
        {
          "name" : "MANAGEMENT_PORT_HTTPS",
          "value" : "443"
        },
        {
          "name" : "MANAGEMENT_PORT_HTTP",
          "value" : "8083"
        },
        {
          "name" : "FILESYSTEM_SCAN_ENABLED",
          "value" : "true"
        },
        {
          "name" : "PROCESS_SCAN_ENABLED",
          "value" : "true"
        },
        {
          "name" : "SCAP_ENABLED",
          "value" : ""
        }
      ]
      mountPoints = [
        {
          "sourceVolume" : "syslog-socket",
          "containerPath" : "/dev/log",
          "readOnly" : false
        },
        {
          "sourceVolume" : "twistlock-console",
          "containerPath" : "/var/lib/twistlock/",
          "readOnly" : false
        },
        {
          "sourceVolume" : "twistlock-config-volume",
          "containerPath" : "/var/lib/twistlock/scripts/",
          "readOnly" : false
        },
        {
          "sourceVolume" : "twistlock-backup-volume",
          "containerPath" : "/var/lib/twistlock-backup",
          "readOnly" : false
        }
      ]
      privileged             = true
      readonlyRootFilesystem = true
    }
  ])

  volume {
    name      = "syslog-socket"
    host_path = "/dev/log"
  }

  volume {
    name      = "twistlock-console"
    host_path = "/twistlock_console/var/lib/twistlock"
  }

  volume {
    name      = "twistlock-config-volume"
    host_path = "/twistlock_console/var/lib/twistlock-config"
  }

  volume {
    name      = "twistlock-backup-volume"
    host_path = "/twistlock_console/var/lib/twistlock-backup"
  }

  placement_constraints {
    type       = "memberOf"
    expression = "attribute:purpose == infra"
  }
}

resource "aws_ecs_task_definition" "defender" {
  family       = "pc-defender"
  network_mode = "host"
  requires_compatibilities = ["EC2"]
  pid_mode = "host"
  container_definitions = jsonencode([
    {
      name              = "twistlock_defender"
      memory = 512
      image             = "registry-auth.twistlock.com/tw_toetxipkxnuletqvq57fv4eefecyj1qa/twistlock/defender:defender_30_03_122"
      portMappings = [
        {
          containerPort = 443,
          hostPort      = 443,
          protocol      = "https"
        }
      ]
      volumesFrom = []
      environment = [
        {
          "name" : "DEFENDER_LISTENER_TYPE",
          "value" : "none"
        },
        {
          "name" : "DEFENDER_TYPE",
          "value" : "ecs"
        },
        {
          "name" : "DEFENDER_CLUSTER",
          "value" : ""
        },
        {
          "name" : "DOCKER_CLIENT_ADDRESS",
          "value" : "/var/run/docker.sock"
        },
        {
          "name" : "LOG_PROD",
          "value" : "true"
        },
        {
          "name" : "WS_ADDRESS",
          "value" : "wss://<ADD_LB_DNS_NAME>:8084"
        },
        {
          "name" : "INSTALL_BUNDLE",
          "value" : "<ADD_INSTALL_BUNDLE>"
        },
        {
          "name" : "HOST_CUSTOM_COMPLIANCE_ENABLED",
          "value" : "false"
        }
      ]
      mountPoints = [
        {
          "containerPath": "/var/lib/twistlock",
          "sourceVolume": "data-folder"
        },
        {
          "containerPath": "/var/run",
          "sourceVolume": "docker-sock-folder"
        },
        {
          "readOnly": true,
          "containerPath": "/etc/passwd",
          "sourceVolume": "passwd"
        },
        {
          "containerPath": "/run",
          "sourceVolume": "iptables-lock-folder"
        },
        {
          "containerPath": "/dev/log",
          "sourceVolume": "syslog-socket"
        }
      ]
      privileged             = true
      essential              = true
      readonlyRootFilesystem = true
    }
  ])

  volume {
    name      = "syslog-socket"
    host_path = "/dev/log"
  }

  volume {
    name = "data-folder"
    host_path = "/var/lib/twistlock"
  }

  volume {
    name = "docker-sock-folder"
    host_path = "/var/run"
  }

  volume {
    name = "passwd"
    host_path = "/etc/passwd"
  }

  volume {
    name = "iptables-lock-folder"
    host_path = "/run"
  }
}

# Create ECS Services

resource "aws_ecs_service" "service" {
  name            = "pc-service"
  cluster         = aws_ecs_cluster.cluster.id
  task_definition = aws_ecs_task_definition.service.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    elb_name       = aws_elb.elb.name
    container_name = "twistlock-console"
    container_port = "443"
  }
}

resource "aws_ecs_service" "defender" {
  name            = "pc-defender"
  cluster         = aws_ecs_cluster.defender.id
  task_definition = aws_ecs_task_definition.defender.arn
  desired_count   = 1
  launch_type     = "EC2"
}

# Deploy Prisma Console Capacity Providers
resource "aws_ecs_capacity_provider" "provider" {
  name = "pc-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.prisma.arn
  }
}

resource "aws_ecs_cluster_capacity_providers" "cluster" {
  cluster_name       = aws_ecs_cluster.cluster.name
  capacity_providers = [aws_ecs_capacity_provider.provider.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.provider.name
  }
}

# Deploy Prisma Defender Capacity Providers

resource "aws_ecs_cluster_capacity_providers" "defender" {
  cluster_name       = aws_ecs_cluster.defender.name
  capacity_providers = [aws_ecs_capacity_provider.defender.name]

  default_capacity_provider_strategy {
    base              = 1
    weight            = 100
    capacity_provider = aws_ecs_capacity_provider.defender.name
  }
}
resource "aws_ecs_capacity_provider" "defender" {
  name = "pc-defender-capacity-provider"

  auto_scaling_group_provider {
    auto_scaling_group_arn = aws_autoscaling_group.defender.arn
  }
}

# Allows resources to communicate with the Prisma Console
resource "aws_security_group" "console" {
  name        = var.sg_name
  description = "Allows resources to communicate with the Prisma Console"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8084
    to_port     = 8084
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 8083
    to_port     = 8083
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

# Security group for efs mount target
resource "aws_security_group" "efs_mount_target" {
  name   = "efs_mount_target_sg"
  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Creates efs file system for the Prisma Console
resource "aws_efs_file_system" "efs" {
  creation_token                  = var.efs_name
  throughput_mode                 = "provisioned"
  provisioned_throughput_in_mibps = 100
  tags                            = var.tags
}

# Mounts efs file system 
resource "aws_efs_mount_target" "target" {
  count           = length(module.vpc.public_subnets)
  file_system_id  = aws_efs_file_system.efs.id
  subnet_id       = module.vpc.public_subnets[count.index]
  security_groups = [aws_security_group.efs_mount_target.id]
}

# Launch configuration for instracture node
resource "aws_launch_configuration" "config" {
  name            = var.launch_config_name
  image_id        = var.image_id
  instance_type   = "t2.xlarge"
  key_name        = "prisma"
  security_groups = [aws_security_group.console.id]
  user_data = templatefile("prisma_startup.sh", {
    efs_dns = aws_efs_file_system.efs.dns_name
  })
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.prisma-profile.name

  root_block_device {
    volume_size = 150
  }
}

# Launch configuration for worker nodes

resource "aws_launch_configuration" "defender" {
  name                        = "pc-worker-node"
  image_id                    = var.image_id
  instance_type               = "t2.medium"
  key_name                    = "prisma"
  security_groups             = [aws_security_group.console.id]
  user_data                   = file("prisma_defender.sh")
  associate_public_ip_address = true
  iam_instance_profile        = aws_iam_instance_profile.prisma-profile.name
}

# Autoscaling group for Prisma infrastructure node
resource "aws_autoscaling_group" "prisma" {
  name                 = "pc-infra-autoscaling"
  launch_configuration = aws_launch_configuration.config.name
  vpc_zone_identifier  = module.vpc.public_subnets
  max_size             = 2
  min_size             = 1
  load_balancers       = [aws_elb.elb.name]
}

# Autoscaling group for Prisma Defenders
resource "aws_autoscaling_group" "defender" {
  name                 = "pc-worker-autoscaling"
  launch_configuration = aws_launch_configuration.defender.name
  vpc_zone_identifier  = module.vpc.public_subnets
  max_size             = 3
  min_size             = 1
}
