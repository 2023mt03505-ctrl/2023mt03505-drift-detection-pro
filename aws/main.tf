###########################################
# 🔹 AWS Provider (keep in provider.tf)
###########################################
# provider "aws" {
#   region = var.aws_region
# }

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
# 🔹 AWS S3 Bucket (Fixed — ACL removed)
###########################################
resource "aws_s3_bucket" "storage" {
  bucket        = "st2023mt03505-${var.region_index}"
  force_destroy = true

  # ❌ REMOVE ACL — bucket has ACLs disabled (BucketOwnerEnforced)
  # acl = "private"

  tags = {
    Project     = "MTechDrift"
    Environment = "Test"
  }
}

# 🔹 Apply AES-256 SSE using new recommended resource
resource "aws_s3_bucket_server_side_encryption_configuration" "sse" {
  bucket = aws_s3_bucket.storage.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

###########################################
# 🔹 AWS Security Group
###########################################
resource "aws_security_group" "secure_sg" {
  name        = "secure-sg"
  description = "Secure SG with restricted SSH"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]   # fixed from 0.0.0.0/0
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = "MTechDrift"
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
