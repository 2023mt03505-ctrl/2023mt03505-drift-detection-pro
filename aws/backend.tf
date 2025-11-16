terraform {
  backend "s3" {
    bucket         = "st2023mt03505-tfstate-mtechproj"
    key            = "terraform.tfstate"
    region         = "ap-south-1"
    dynamodb_table = "st2023mt03505-tf-lock-mtechproj"
    encrypt        = true
  }
}
