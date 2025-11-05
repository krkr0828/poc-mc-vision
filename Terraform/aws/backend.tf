terraform {
  backend "s3" {
    bucket         = "poc-mc-vision-terraform-state-aws"
    key            = "aws/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "poc-mc-vision-terraform-locks"
    encrypt        = true
  }
}
