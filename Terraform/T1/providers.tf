terraform {
    required_providers {
        azurerm = {
        source  = "hashicorp/azurerm"
        version = "~> 4.39.0"
        }
    
        aws = {
        source  = "hashicorp/aws"
        version = "~> 6.6.0"
        }

        google = {
        source  = "hashicorp/google"
        version = "~> 7.2.0"
        }
        
    }

}

provider "azurerm" {
  features {}
}

provider "aws" {
  region = "us-east-1"
}

provider "google" {
  project     = "terraform-101-472115"
  region      = "us-central1"
}