terraform {
  backend "s3" {
    bucket         = "poc-mc-vision-terraform-state-azure"
    key            = "azure/terraform.tfstate"
    region         = "ap-northeast-1"
    dynamodb_table = "poc-mc-vision-terraform-locks"
    encrypt        = true
  }
}
