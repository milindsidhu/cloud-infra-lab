terraform {
  backend "local" {
    path = "/Users/dex/workspace/tf-statefile/terraform.state"
  }

  # Uncomment and configure one of the following backends as needed

  # AZURE Backend
  # backend "azurerm" {
  #   resource_group_name  = "myResourceGroup"
  #   storage_account_name = "mystorageaccount"
  #   container_name       = "tfstate"
  #   key                  = "prod.terraform.tfstate"  
  # }

  # AWS Backend
  # backend "s3" {
  #   bucket         = "my-terraform-state-bucket"
  #   key            = "path/to/my/key"
  #   region         = "us-west-2"
  #   dynamodb_table = "my-lock-table"
  #   encrypt        = true
  # }

  # GCP Backend
  # backend "gcs" {
  #   bucket      = "my-terraform-state-bucket"
  #   prefix      = "path/to/my/prefix"
  #   credentials = "/path/to/credentials.json"   
  # }

}
