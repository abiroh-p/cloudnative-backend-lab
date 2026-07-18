# WHY this file exists:
# Terraform needs to know WHICH cloud provider to talk to, and WHICH version
# of that provider's API logic to use. Pinning versions is an industry
# standard — without it, "terraform apply" today could behave differently
# from "terraform apply" next month if the provider releases a breaking change.

terraform {
  required_version = ">= 1.7.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.100"   # "~>" means: allow patch/minor updates, not major
    }
  }

  # INDUSTRY STANDARD NOTE:
  # Right now, Terraform will store its "state" (a JSON file that tracks what
  # it created) on your local disk. That's fine for learning solo.
  # In a real team setting, state lives in a shared remote backend (e.g. an
  # Azure Storage Account) so multiple people don't clobber each other's
  # infrastructure changes. We'll migrate to that in a later stage once
  # you're comfortable with the basics — flagging it now so it's not a
  # surprise later.
  #
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "tfstateXXXXX"
  #   container_name       = "tfstate"
  #   key                  = "cloud-backend-project.tfstate"
  # }
}

provider "azurerm" {
  features {}
}
