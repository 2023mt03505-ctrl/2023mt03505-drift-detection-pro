###########################################
# 🔹 AWS Provider + Resources
###########################################
#provider "aws" {
  #region = var.aws_region
#}




###########################################
# 🔹 Variables
###########################################
variable "aws_region" {
  description = "AWS region to deploy"
  type        = string
  default     = "ap-south-1"
}

variable "region_index" {
  description = "Index to differentiate resources (like 0, 1)"
  type        = number
  default     = 0
}


variable "vpc_id" {
  description = "Existing VPC ID to attach security group"
  type        = string
}

###########################################
# 🔹 AWS S3 Storage (like Azure Storage Account)
###########################################
resource "aws_s3_bucket" "storage" {
  bucket        = "st2023mt03505-${var.region_index}"
  force_destroy = true

  # Block all public access
  acl = "private"

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    Project = "MTechDrift"
    Environment = "Test"
  }
}

###########################################
# 🔹 AWS Security Group (like Azure NSG)
###########################################
resource "aws_security_group" "secure_sg" {
  name        = "secure-sg"
  description = "Secure SG with restricted SSH"
  vpc_id      = var.vpc_id

  # Only allow internal SSH (adjust CIDR as needed)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project = "MTechDrift"
    Environment = "Test"
  }
}

###########################################
# 🔹 Outputs
###########################################
output "aws_s3_bucket_name" {
  value = aws_s3_bucket.storage.bucket
}

output "aws_security_group_name" {
  value = aws_security_group.secure_sg.name
}
