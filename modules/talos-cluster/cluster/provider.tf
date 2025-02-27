terraform {
  required_providers {
	helm = {
	  source  = "hashicorp/helm"
	  version = "~> 2.13.2"
	}
	talos = {
	  source  = "siderolabs/talos"
	  version = "~> 0.5.0"
	}
  }
}

provider "helm" {
  kubernetes {
	config_path = "~/.kube/config"
  }
}
