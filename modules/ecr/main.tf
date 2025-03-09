########################
# ECR
########################

# Define ECR repository for frontend app
resource "aws_ecr_repository" "frontend" {
  name                 = "${var.common.env}-frontend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  encryption_configuration {
    encryption_type = "KMS"
  }
}

# Define ECR repository for backend app
resource "aws_ecr_repository" "backend" {
  name                 = "${var.common.env}-backend"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = false
  }
  encryption_configuration {
    encryption_type = "KMS"
  }
}