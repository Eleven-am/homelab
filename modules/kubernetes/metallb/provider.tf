terraform {
  required_providers {
	helm = {
	  source = "hashicorp/helm"
	  version = "~> 2.13"
	}
  }
}

provider "helm" {
  kubernetes {
	config_path = "~/.kube/config"
  }
}

provider "kubernetes" {
  config_path    = "~/.kube/config"
}
