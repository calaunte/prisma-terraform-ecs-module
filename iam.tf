data "aws_iam_policy_document" "inline-policy" {
    statement {
        effect = "Allow"
        actions = [
            "ecs:DeregisterTaskDefinition",
            "ecs:Poll",
            "ecs:StartTask",
            "ecs:SubmitTaskStateChange",
            "ecs:DescribeClusters",
            "ecs:StartTelemetrySession",
            "ecs:ListClusters",
            "ecs:RegisterTaskDefinition",
            "ecs:RegisterContainerInstance",
            "ecs:DeregisterContainerInstance",
            "ecs:DiscoverPollEndpoint"
        ]
        resources = ["*"]
    }

    statement {
        effect = "Allow"
        actions = [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
        ]
        resources = ["arn:aws:logs:us-east-1:531144910802:log-group:prisma-console-logs:*"]
    }

    statement {
        effect = "Allow" 
        actions = [
                "ecr:BatchCheckLayerAvailability",
                "ecr:BatchGetImage",
                "ecr:DescribeImages",
                "ecr:DescribeRepositories",
                "ecr:GetAuthorizationToken",
                "ecr:GetDownloadUrlForLayer",
                "ecr:GetRepositoryPolicy",
                "ecr:ListImages"
        ]
        resources = ["*"]
    }

    statement {
        effect = "Allow"
        actions = [
            "elasticfilesystem:ClientMount",
            "elasticfilesystem:ClientWrite",
            "elasticfilesystem:ClientRootAccess",
            "elasticfilesystem:DescribeMountTargets",
        ]
        resources = [
            aws_efs_file_system.efs.arn,
            "arn:aws:elasticfilesystem:*:*:mount-target/*"
        ]
    }
}

data "aws_iam_policy_document" "instance-assume-role-policy" {
    statement {
      actions = ["sts:AssumeRole"]

      principals {
        type = "Service"
        identifiers = ["ec2.amazonaws.com"]
      }
    }
}

resource "aws_iam_role" "instance" {
    name = "pcp-ecsInstanceRole"
    assume_role_policy = data.aws_iam_policy_document.instance-assume-role-policy.json

    inline_policy {
      name = "ecs-inline-policy"
      policy = data.aws_iam_policy_document.inline-policy.json
    }
}

resource "aws_iam_instance_profile" "prisma-profile" {
    name = "pc-ecs-profile"
    role = aws_iam_role.instance.name

    tags = var.tags
}