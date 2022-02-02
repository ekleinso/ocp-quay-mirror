variable "binaries_client" {
  description = "URL where to download openshift client"
  default     = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.9/openshift-client-linux.tar.gz"
}

variable "binaries_mirror" {
  description = "URL location of existing ocp mirror for example: file:///repository/ocp/4.9/ocp-mirror.tar.gz or http://webserver:8080/ocp/4.9/ocp-mirror.tar.gz"
  default     = ""
}

variable "installer" {
  type = string
  default = "https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-offline.tar.gz" 
}

variable "install_dir" {
  type = string
  default = "/opt/podman/quay"
}

variable "password" {
  type = string
  default = "" 
}

variable "ocp_release" {
  type = string
  description = "4.9.15" 
}


variable "repository" {
  type = string
  default  = "ocp4/ocp-v4.9-release"
}

variable "product_repo" { 
  type = string
  default = "openshift-release-dev"
}

variable "pull_secret" {
  type  = string
  description = "Location of pull-secret json"
}

variable "architecture" {
  type  = string
  default = "x86_64"
}

