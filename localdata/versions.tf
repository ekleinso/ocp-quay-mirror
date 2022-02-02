terraform {
  required_version = ">= 0.13"
  required_providers {
    local = {
      source = "hashicorp/local"
    }
    external = {
      source = "hashicorp/external"
    }
    template = {
      source = "hashicorp/template"
    }
  }
}

