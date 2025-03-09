########################
# EC2 Instance
########################

# Get the latest Amazon Linux 2 AMI
data "aws_ami" "amazon-linux-2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# Define EC2 instance
resource "aws_instance" "management" {
  for_each               = { for i, s in var.network.private_subnet_for_management_ids : i => s }
  ami                    = data.aws_ami.amazon-linux-2.id
  instance_type          = "t3.large"
  vpc_security_group_ids = [var.network.security_group_for_management_id]
  subnet_id              = each.value
  root_block_device {
    volume_type = "gp3"
    volume_size = "20"
    encrypted   = true
    tags = {
      Name = "${var.common.env}-ebs-${each.key}"
    }
  }
  iam_instance_profile = aws_iam_instance_profile.management.name
  tags = {
    Name = "${var.common.env}-ec2-${each.key}"
  }
}

# Define IAM instance profile for EC2
resource "aws_iam_instance_profile" "management" {
  name = "${var.common.env}-instance-profile"
  role = aws_iam_role.management.name
}

resource "aws_iam_role" "management" {
  name               = "${var.common.env}-role-for-ec2"
  assume_role_policy = data.aws_iam_policy_document.trust_management.json
}

data "aws_iam_policy_document" "trust_management" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role_policy_attachment" "policy_management" {
  for_each = {
    ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
    ecr = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryFullAccess"
  }
  role       = aws_iam_role.management.name
  policy_arn = each.value
}
