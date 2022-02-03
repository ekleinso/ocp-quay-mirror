# ocp-quay-mirror
Configures a quay container repository for the purpose of installing OpenShift in restricted networks using [mirror-registry](https://github.com/quay/mirror-registry).

### Calling ocp-quay-mirror module
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
| installer   | The location of the Quay installation                                             | string | https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-online.tar.gz |
| install_dir    | Location to install Quay files and act as main container storage repository    | string | /opt/podman/quay |
| password   | Password to use for Quay init user. A random string is generated if not set        | string | - |
| ocp_release  | OpenShift release to mirror                                                      | string | 4.9.15 |
| repository | The repository to use in Quay for the OpenShift containers                         | string | ocp4/ocp-v4.9-release |
| product_repo | The OpenShift product repo to mirror                                             | string | openshift-release-dev |
| pull_secret  | The location of the pull-secret file                                             | string | - |
| architecture | The architecture of containers to mirror                                         | string | x86_64 |
| mirror_repo | Mirror the OpenShift repository                                                   | bool | true |

#### operating the terraform
This can function as a module for and end-to-end Terraform based OpenShift restricted network deployment or it can be run directly to deploy a Quay repository to mirror container images for a restricted network installation.

Sizing for **install_dir** will depend on how much you are planning to store in the repository. The OpenShift release for most 4.x versions is 7-10GB if you are planning to mirror the Operator Hub a much large amount of space is required see the table below.

| Operator Catalog          | Approximate size | 
| ------------------------- | ---------------- |
| redhat-operator           |        593G      |
| community-operator        |        130G      |
| certified-operator        |        310G      |
| redhat-marketplace        |         30G      |
| Cloud Pak for Integration |        100G      |

It is possible to reduce the size of the catalogs by only choosing the operators that are required for the work being performed. See [Mirroring Operator catalogs](https://docs.openshift.com/container-platform/4.9/installing/installing-mirroring-installation-images.html#olm-mirror-catalog_installing-mirroring-installation-images) for details.

Please note that the **install_dir** is also used as a scratch space for the installation so it would be best to start with 100GB.

The default settings will download files from the internet to support installing Quay and populating the repository. Here is a sample tfvars file for downloading.
```yaml
binaries_client="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.9/openshift-client-linux.tar.gz"
installer = "https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-online.tar.gz"
install_dir = "/opt/podman/registry"
ocp_release = "4.9.15"
repository = "ocp4/ocp-v4.9-release"
product_repo = "openshift-release-dev"
pull_secret = "/root/pull-secret"
```

It is also possible to provide the installation files locally. This scenario may be required when installing without bastion access to the internet where you might provide the files on removable media. Here is a sample tfvars file using local copies.
```yaml
binaries_mirror="file:///mnt/usbdisk/ocp-mirror.tar.gz"
binaries_client="file:///mnt/usbdisk/openshift-client-linux.tar.gz"
installer = "file:///mnt/usbdisk/mirror-registry-online.tar.gz"
install_dir = "/opt/podman/registry"
ocp_release = "4.9.15"
repository = "ocp4/ocp-v4.9-release"
product_repo = "openshift-release-dev"
pull_secret = "/mnt/usbdisk/pull-secret"
```
In this configuration we added the **binaries_mirror** variable that references an archive of the OpenShift mirror. To create this archive you can run these commands from a system with internet access and copy to your removable media.
```shell
$ oc adm release mirror -a /mnt/usbdisk/pull-secret --to-dir=./mirror quay.io/openshift-release-dev/ocp-release:4.9.15-x86_64
$ tar czf ocp-mirror.tar.gz mirror
```

The Terraform will output the following information.

#### additionalTrustBundle

These are the certificates generated by Quay found in **<install_dir>/runtime/quay-config**. They need to be added to the **additionalTrustBundle** section in the **install-config.yaml** to use this Quay repository.
```
additionalTrustBundle = <<EOT
-----BEGIN CERTIFICATE-----
... Quay crt
-----END CERTIFICATE-----
-----BEGIN CERTIFICATE-----
... CA crt
-----END CERTIFICATE-----
EOT
```

#### imageContentSourcePolicy

To use the new mirrored repository for upgrades, use the following to create an ImageContentSourcePolicy in OpenShift.

```yaml
imageContentSourcePolicy = <<EOT
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - quay-mirror.example.com:8443/ocp4/ocp-v4.9-release
    source: quay.io/openshift-release-dev/ocp-release
  - mirrors:
    - quay-mirror.example.com:8443/ocp4/ocp-v4.9-release
    source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOT
```

#### imageContentSources

To use the new mirrored repository to install, add the following section to the install-config.yaml:

```yaml
imageContentSources = <<EOT
imageContentSources:
- mirrors:
  - quay-mirror.example.com:8443/ocp4/ocp-v4.9-release
  source: quay.io/openshift-release-dev/ocp-release
- mirrors:
  - quay-mirror.example.com:8443/ocp4/ocp-v4.9-release
  source: quay.io/openshift-release-dev/ocp-v4.0-art-dev
EOT
```

#### Installation binaries

The OpenShift installation binaries are extracted and copied to **install_dir**.
```
openshift-baremetal-install = "/opt/podman/registry/bin/openshift-baremetal-install"
openshift-install = "/opt/podman/registry/bin/openshift-install"
```

#### OpenShift pull-secret

The OpenShift pull secret is updated with the Quay repository information and also copied to **install_dir**.
```
pull-secret = {
  "auths" = {
    "quay-mirror.example.com:8443" = {
      "auth" = "aW5pdDoxMjM0NTY3ODkwYWJjZGVm"
      "email" = "init@quay-mirror.example.com"
    }
    "quay.io" = {
      "auth" = "1234567890abcdef="
      "email" = "user@example.com"
    }
    "registry.connect.redhat.com" = {
      "auth" = "1234567890abcdef="
      "email" = "user@example.com"
    }
    "registry.redhat.io" = {
      "auth" = "1234567890abcdef="
      "email" = "user@example.com"
    }
  }
}
```

#### Quay installation specifics

```
quay-credentials = "(init, 1234567890abcdef)"
quay-url = "https://quay-mirror.example.com:8443"
```

When you login to the UI you can see the mirror repository that is created.
![Repository](./images/repositories.png)
As well as the repository tags.
![Repository Tags](./images/tags.png)

#### Mirror other OCP releases

Here are some sample tfvars for mirroring other OpenShift releases.

**4.8**
```yaml
binaries_client="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.8/openshift-client-linux.tar.gz"
installer = "https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-online.tar.gz"
install_dir = "/opt/podman/registry"
ocp_release = "4.8.27"
repository = "ocp4/ocp-v4.8-release"
product_repo = "openshift-release-dev"
pull_secret = "/root/pull-secret"
```

**4.7**
```yaml
binaries_client="https://mirror.openshift.com/pub/openshift-v4/clients/ocp/stable-4.7/openshift-client-linux.tar.gz"
installer = "https://github.com/quay/mirror-registry/releases/download/1.0.0-RC6/mirror-registry-online.tar.gz"
install_dir = "/opt/podman/registry"
ocp_release = "4.7.41"
repository = "ocp4/ocp-v4.7-release"
product_repo = "openshift-release-dev"
pull_secret = "/root/pull-secret"
```

## Mirror Operator Hub

### Prune catalogs 
As stated above mirroring the Operator Hub can consume alot of storage not to mention downloading gigabytes of data. There is a way to prune the catalogs so you only mirror the operators that you are interested in using.  Here is a summary of steps that can be taken to selectively mirror the Operator Hub which was taken from the [Red Hat Documentation](https://docs.openshift.com/container-platform/4.9/installing/installing-mirroring-installation-images.html#olm-mirror-catalog_installing-mirroring-installation-images).

### Tools needed
- podman
- [OpenShift CLI](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.9/openshift-client-linux.tar.gz)
- [OPM cli](https://mirror.openshift.com/pub/openshift-v4/x86_64/clients/ocp/stable-4.9/opm-linux.tar.gz)
- [grpcurl](https://github.com/fullstorydev/grpcurl)

I am going to skip the steps to list the contents of the catalog indexes. You can review the [Red Hat Documentation](https://docs.openshift.com/container-platform/4.9/installing/installing-mirroring-installation-images.html#olm-mirror-catalog_installing-mirroring-installation-images) link for more details on that. Instead I will focus on mirroring the operators I find more commonly used. These are detailed in the table below. 

- redhat-operator-index (New size: ~69G)
  - cluster-logging
  - elasticsearch-operator
  - ocs-operator
  - jaeger-product
  - kiali-ossm
  - local-storage-operator
  - cincinnati-operator
  - openshift-gitops-operator
  - openshift-jenkins-operator
  - openshift-pipelines-operator-rh
  - quay-bridge-operator
  - quay-operator
  - web-terminal
- community-operator-index (New size: ~10G)
  - argocd-operator
  - argocd-operator-helm
  - cert-manager
  - etcd
  - grafana-operator
  - jaeger
  - kiali
  - must-gather-operator
  - nexus-operator-m88i
  - openebs
- certified-operator-index (New size: ~9G)
  - cert-manager-operator
  - gitlab-runner-operator
  - mongodb-enterprise
  - portworx-certified
  - minio-operator
- redhat-marketplace-index (Size: ~26G)
  - Usuall just mirror the whole repo
  
1. Login to registry.redhat.io credentials are found in the pull-secret. Just take the auth field and echo into `base64 -d` there are 2 fields `username:password`

```shell
$ podman login registry.redhat.io
```

2. Prune indexes using selected packages
```shell
$ opm index prune -f registry.redhat.io/redhat/redhat-operator-index:v4.9 \
  -p cluster-logging,elasticsearch-operator,ocs-operator,jaeger-product,kiali-ossm,local-storage-operator,cincinnati-operator,openshift-gitops-operator,openshift-jenkins-operator,openshift-pipelines-operator-rh,quay-bridge-operator,quay-operator,web-terminal \
  -t quay-mirror.example.com:8443/olm-catalog/redhat-operator-index:v4.9
$ opm index prune -f registry.redhat.io/redhat/community-operator-index:v4.9 \
  -p argocd-operator,argocd-operator-helm,cert-manager,etcd,grafana-operator,jaeger,kiali,must-gather-operator,nexus-operator-m88i,openebs \
  -t quay-mirror.example.com:8443/olm-catalog/community-operator-index:v4.9
$ opm index prune -f registry.redhat.io/redhat/certified-operator-index:v4.9 \
  -p cert-manager-operator, gitlab-runner-operator, mongodb-enterprise, portworx-certified, minio-operator \
  -t quay-mirror.example.com:8443/olm-catalog/certified-operator-index:v4.9
# Or just copy the catalog as is
$ podman pull registry.redhat.io/redhat/redhat-marketplace-index:v4.9
$ podman tag registry.redhat.io/redhat/redhat-marketplace-index:v4.9 quay-mirror.example.com:8443/olm-catalog/redhat-marketplace-index:v4.9
```

3. Push to indexes to local mirror repo
```shell
$ podman push --tls-verify=false --authfile /opt/podman/quay/pull-secret quay-mirror.example.com:8443/olm-catalog/redhat-operator-index:v4.9
$ podman push --tls-verify=false --authfile /opt/podman/quay/pull-secret quay-mirror.example.com:8443/olm-catalog/certified-operator-index:v4.9
$ podman push --tls-verify=false --authfile /opt/podman/quay/pull-secret quay-mirror.example.com:8443/olm-catalog/community-operator-index:v4.9
$ podman push --tls-verify=false --authfile /opt/podman/quay/pull-secret quay-mirror.example.com:8443/olm-catalog/redhat-marketplace-index:v4.9
```

4. Mirror operators to local repository
```shell
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/redhat-operator-index:v4.9 \
  quay-mirror.example.com:8443/olm-mirror \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/certified-operator-index:v4.9 \
  quay-mirror.example.com:8443/olm-mirror \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/community-operator-index:v4.9 \
  quay-mirror.example.com:8443/olm-mirror \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/redhat-marketplace-index:v4.9 \
  quay-mirror.example.com:8443/olm-mirror \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
```

5. **(Optional)** Mirror operators to local disk to transport via removable media
```shell
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/redhat-operator-index:v4.9 \
  file:///ocp4 \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/certified-operator-index:v4.9 \
  file:///ocp4 \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/community-operator-index:v4.9 \
  file:///ocp4 \
  -a /opt/podman/quay/pull-secret \
  --insecure --index-filter-by-os='.*'
$ oc adm catalog mirror quay-mirror.example.com:8443/olm-catalog/redhat-marketplace-index:v4.9 \
   file:///ocp4 \
   -a /repository/utils/pull-secret \
   --insecure --index-filter-by-os='.*'
```

6. Upload local images to a registry
```shell
$ oc adm catalog mirror -a /opt/podman/quay/pull-secret --insecure file://ocp4/olm-catalog/redhat-operator-index:v4.9 quay-mirror.example.com:8443/olm-mirror
$ oc adm catalog mirror -a /opt/podman/quay/pull-secret --insecure file://ocp4/olm-catalog/redhat-marketplace-index:v4.9 quay-mirror.example.com:8443/olm-mirror
$ oc adm catalog mirror -a /opt/podman/quay/pull-secret --insecure file://ocp4/olm-catalog/community-operator-index:v4.9 quay-mirror.example.com:8443/olm-mirror
$ oc adm catalog mirror -a /opt/podman/quay/pull-secret --insecure file://ocp4/olm-catalog/certified-operator-index:v4.9 quay-mirror.example.com:8443/olm-mirror
```

7. After the images are mirrored examine the **manifests** folders. They will be named:
```
manifests-redhat-operator-index-*
manifests-redhat-marketplace-index-*
manifests-certified-operator-index-*
manifests-community-operator-index-*
```
There should be a **catalogSource.yaml** and **imageContentSourcePolicy.yaml**. They can be imported into the cluster using `oc apply -f`.
**Example catalogSource.yaml**
```yaml
apiVersion: operators.coreos.com/v1alpha1
kind: CatalogSource
metadata:
  name: redhat-operator-index
  namespace: openshift-marketplace
spec:
  image: quay-mirror.example.com:8443/olm-mirror/olm-catalog-redhat-operator-index:v4.9
  sourceType: grpc
```
**Example imageContentSourcePolicy.yaml**
```yaml
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: redhat-operator-index
spec:
  repositoryDigestMirrors:
  - mirrors:
    - quay-mirror.example.com:8443/olm-mirror/openshift-logging-logging-curator5-rhel8
    source: registry.redhat.io/openshift-logging/logging-curator5-rhel8
  - mirrors:
    - quay-mirror.example.com:8443/olm-mirror/ubi8-ubi-minimal
    source: registry.redhat.io/ubi8/ubi-minimal
  - mirrors:
    - quay-mirror.example.com:8443/olm-mirror/openshift-pipelines-pipelines-cli-tkn-rhel8
    source: registry.redhat.io/openshift-pipelines/pipelines-cli-tkn-rhel8

...Continues for many lines
```
