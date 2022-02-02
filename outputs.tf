output "quay-url" {
  value = format("https://%s:8443", local.hostname)
}

output "quay-credentials" {
  value = format("(init, %s)", local.password)
}

output "openshift-install" {
  value = "${local.bindir}/openshift-install"
}

output "openshift-baremetal-install" {
  value = "${local.bindir}/openshift-baremetal-install"
}

output "imageContentSources" {
  value = <<EOF
imageContentSources:
- mirrors:
  - ${local.hostname}:8443/${var.repository}
  source: quay.io/${var.product_repo}/ocp-release
- mirrors:
  - ${local.hostname}:8443/${var.repository}
  source: quay.io/${var.product_repo}/ocp-v4.0-art-dev
EOF
}

output "imageContentSourcePolicy" {
  value = <<EOF
apiVersion: operator.openshift.io/v1alpha1
kind: ImageContentSourcePolicy
metadata:
  name: example
spec:
  repositoryDigestMirrors:
  - mirrors:
    - ${local.hostname}:8443/${var.repository}
    source: quay.io/${var.product_repo}/ocp-release
  - mirrors:
    - ${local.hostname}:8443/${var.repository}
    source: quay.io/${var.product_repo}/ocp-v4.0-art-dev
EOF
}

output "additionalTrustBundle" {
  value = data.local_file.quay_cert.content
}
