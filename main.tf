resource "aws_ecs_cluster" "this" {
  name = var.name
  tags = var.tags
}

module "fargate_security_group" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "3.10.0"
  name        = "${var.name}-fargate"
  description = "Fargate SG"
  vpc_id      = var.vpc_id
  ingress_with_source_security_group_id = [
    # All from public LB
    {
      rule                     = "all-all"
      source_security_group_id = module.public_load_balancer_sg.this_security_group_id
    },
    # All from private LB
    {
      rule                     = "all-all"
      source_security_group_id = module.private_load_balancer_sg.this_security_group_id
    },
  ]
  ingress_with_self = [
    {
      rule = "all-all"
    },
  ]
  tags = var.tags
}

module "private_load_balancer_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "3.10.0"
  name        = "${var.name}-public-lb"
  description = "Private Load Balancer SG"
  vpc_id      = var.vpc_id
  ingress_with_source_security_group_id = [
    # All from public LB
    {
      rule                     = "all-all"
      source_security_group_id = module.fargate_security_group.this_security_group_id
    },
  ]
  tags = var.tags

}


module "private_load_balancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "${var.name}-public-lb"

  load_balancer_type = "application"

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  vpc_id          = var.vpc_id
  subnets         = var.private_subnets
  security_groups = [module.private_load_balancer_sg.this_security_group_id]
  idle_timeout    = var.idle_timeout
  internal        = true
  //ip_address_type = var.ip_address_type

  access_logs = {
    bucket = var.log_bucket_name
  }

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
  tags = var.tags

}

module "public_load_balancer_sg" {
  source      = "terraform-aws-modules/security-group/aws"
  version     = "3.10.0"
  name        = "${var.name}-public-lb"
  description = "Public Load Balancer SG"
  vpc_id      = var.vpc_id
  ingress_with_cidr_blocks = [
    {
      from_port   = 1
      to_port     = 65535
      protocol    = "tcp"
      description = "All TCP Ports"
      cidr_blocks = "0.0.0.0/0"
    },
  ]
  tags = var.tags

}

module "public_load_balancer" {
  source  = "terraform-aws-modules/alb/aws"
  version = "~> 5.0"

  name = "${var.name}-public-lb"

  load_balancer_type = "application"

  enable_cross_zone_load_balancing = var.enable_cross_zone_load_balancing

  vpc_id          = var.vpc_id
  subnets         = var.public_subnets
  security_groups = [module.public_load_balancer_sg.this_security_group_id]
  idle_timeout    = var.idle_timeout
  internal        = false
  //ip_address_type = var.ip_address_type

  access_logs = {
    bucket = var.log_bucket_name
  }

  target_groups = [
    {
      name_prefix      = "pref-"
      backend_protocol = "HTTP"
      backend_port     = 80
      target_type      = "instance"
    }
  ]

  http_tcp_listeners = [
    {
      port               = 80
      protocol           = "HTTP"
      target_group_index = 0
    }
  ]
  tags = var.tags

}


data "aws_iam_policy_document" "ecs_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_role_policy" {
  name = "ecs_role_policy"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
              "ec2:AttachNetworkInterface",
              "ec2:CreateNetworkInterface",
              "ec2:CreateNetworkInterfacePermission",
              "ec2:DeleteNetworkInterface",
              "ec2:DeleteNetworkInterfacePermission",
              "ec2:Describe*",
              "ec2:DetachNetworkInterface",
              "elasticloadbalancing:DeregisterInstancesFromLoadBalancer",
              "elasticloadbalancing:DeregisterTargets",
              "elasticloadbalancing:Describe*",
              "elasticloadbalancing:RegisterInstancesWithLoadBalancer",
              "elasticloadbalancing:RegisterTargets"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "ecs_role" {
  name_prefix = "ecs_role"
  # path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.ecs_assume_role_policy.json
  tags               = var.tags

}

data "aws_iam_policy_document" "ecs_task_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy" "ecs_task_role_policy" {
  name = "ecs_role_policy"
  role = aws_iam_role.ecs_role.id

  policy = <<-EOF
  {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Action": [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        "Effect": "Allow",
        "Resource": "*"
      }
    ]
  }
  EOF
}

resource "aws_iam_role" "ecs_task_role" {
  name_prefix = "ecs_task_role"
  # path               = "/system/"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role_policy.json
  tags               = var.tags
}

