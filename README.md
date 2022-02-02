# terraform-module-ocp-quay
Configures a quay container repository for the purpose of installing OpenShift in restricted networks using [mirror-registry](https://github.com/quay/mirror-registry).

### Calling nfs-client module
```terraform
module "quay" {
  source = "github.com/ekleinso/terraform-modules-ocp.git//quay?ref=1.1"

  depends_on = []

  binaries_client = "https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.9/openshift-client-linux.tar.gz"
  installer = "https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-online.tar.gz"
  install_dir = "/opt/podman/quay"
  password = "passw0rd"
  ocp_release = "4.9.15"
  repository = "ocp4/ocp-v4.9-release"
  pull_secret = "/tmp/pull-secret"
}
```

#### terraform variables

| Variable                         | Description                                                  | Type   | Default |
| -------------------------------- | ------------------------------------------------------------ | ------ | ------- |
| binaries_client                  | The location of the OpenShift client                         | string | https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.9/openshift-client-linux.tar.gz |
| binaries_mirror     | The location of a pre-downloaded OpenShift mirror repository              | string | - |
| installer   | The location of the Quay installation                                             | string | https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-offline.tar.gz |
| install_dir    | Location to install Quay files and act as main container storage repository    | string | /opt/podman/quay |
| password   | Password to use for Quay init user. A random string is generated if not set        | string | - |
| ocp_release  | OpenShift release to mirror                                                      | string | 4.9.15 |
| repository | The repository to use in Quay for the OpenShift containers                         | string | ocp4/ocp-v4.9-release |
| product_repo | The OpenShift product repo to mirror                                             | string | openshift-release-dev |
| pull_secret  | The location of the pull-secret file                                             | string | - |
| architecture | The architecture of containers to mirror                                         | string | x86_64 |

#### operating the terraform
This can function as a module or it can be run directly to deploy a Quay mirror repository.
