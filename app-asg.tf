resource "aws_security_group" "app" {
  name = format("%sappsg", var.name)

  vpc_id = module.vpc.vpc_id

  ingress {
    from_port   = var.app_port
    to_port     = var.app_port
    protocol    = "tcp"
    cidr_blocks = concat(module.vpc.public_subnets_cidr_blocks, module.vpc.private_subnets_cidr_blocks)
  }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "tcp"
    cidr_blocks = module.vpc.public_subnets
  }

  egress {
    from_port   = "0"
    to_port     = "65535"
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  lifecycle {
    create_before_destroy = true
  }
  
  tags = {
    Group = var.name
  }
}

resource "aws_launch_configuration" "app" {
  image_id        = var.image
  instance_type   = var.instance_type
  security_groups = [aws_security_group.app.id]
  #TODO REMOVE
  key_name = var.public_key
  name_prefix = "var.nameappvm"

  user_data = data.template_file.app.rendered

  lifecycle {
    create_before_destroy = true
  }
   root_block_device {
       volume_type           = "gp2"
       volume_size           = var.size
       delete_on_termination = "true"
    }
}
data "template_file" "app" {
  template = file("install.sh")
}

resource "aws_autoscaling_group" "app" {
  launch_configuration = aws_launch_configuration.app.id

  vpc_zone_identifier = module.vpc.private_subnets

  load_balancers    = [module.elb_app.this_elb_name]
  health_check_type = "EC2"

  min_size = var.app_autoscale_min_size
  max_size = var.app_autoscale_max_size
  tags = [
{
    key = "Group"
    value = var.name
    propagate_at_launch = true
  },
]

}

variable "app_port" {
  description = "The port on which the application listens for connections"
  default = 3306
}

variable "app_autoscale_min_size" {
  description = "The fewest amount of EC2 instances to start"
  default = 2
}

variable "app_autoscale_max_size" {
  description = "The largest amount of EC2 instances to start"
  default = 3
}
