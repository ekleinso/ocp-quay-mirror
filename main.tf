locals  {
  pull_secret = file(var.pull_secret)
  new_pull_secret = {"auths":merge(jsondecode(local.pull_secret).auths, local.quay_auth)}
  password = var.password != "" ? var.password : random_string.generated_password.result
  encoded_password = base64encode("init:${local.password}")
  quay_auth = {"${local.hostname}:8443":{"auth":"${local.encoded_password}","email":"init@${local.hostname}"}}
  hostname = module.local_hostname.data
  bindir = "${var.install_dir}/bin"
  logdir = "${var.install_dir}/logs"
}

# Generate a random string for password if required
resource "random_string" "generated_password" {
  length            = "32"
  special           = "false"
}

resource "local_file" "pull_secret" {
    content  = jsonencode(local.new_pull_secret)
    filename = "${var.install_dir}/pull-secret"
    file_permission = 644
}

module "local_hostname" {
  source = "./localdata"
  command = "echo -n $(hostname -f)"
}

resource "null_resource" "quay_install" {

  triggers = {
    install_dir = var.install_dir
  }

  provisioner "local-exec" {
    command = <<EOF
set -ex

test -d ${self.triggers.install_dir}/runtime || mkdir -p ${self.triggers.install_dir}/runtime
test -d ${self.triggers.install_dir}/installer || mkdir -p ${self.triggers.install_dir}/installer
test -d ${local.logdir} || mkdir -p ${local.logdir}


cd ${self.triggers.install_dir}/installer 
curl -s -L ${var.installer} | tar -xz

./mirror-registry install --quayHostname ${local.hostname} --quayRoot ${self.triggers.install_dir}/runtime --initPassword ${local.password}

EOF
  }

  provisioner "local-exec" {
    when = destroy
    command = <<EOF
set -x

${self.triggers.install_dir}/installer/mirror-registry uninstall --quayRoot ${self.triggers.install_dir}/runtime --autoApprove
rm -rf ${self.triggers.install_dir}/*
EOF
  }
}

resource "null_resource" "mirror_ocp" {

  count = var.mirror_repo && var.binaries_mirror == "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
set -ex

test -d ${local.bindir} || mkdir -p ${local.bindir}

curl -s ${var.binaries_client} | tar -xz -C ${local.bindir}

${local.bindir}/oc adm release mirror -a ${local_file.pull_secret.filename} --to-dir=${var.install_dir}/mirror quay.io/${var.product_repo}/ocp-release:${var.ocp_release}-${var.architecture} >${local.logdir}/ocp_mirror.log 2>&1

EOF
  }
}

resource "null_resource" "unpack_ocp" {

  count = var.mirror_repo && var.binaries_mirror != "" ? 1 : 0

  provisioner "local-exec" {
    command = <<EOF
set -ex

test -d ${var.install_dir} || mkdir -p ${var.install_dir}

curl -s ${var.binaries_mirror} | tar -xz -C ${var.install_dir}

EOF
  }
}

resource "null_resource" "push_ocp" {

  count = var.mirror_repo ? 1 : 0

  depends_on = [null_resource.quay_install, null_resource.mirror_ocp, null_resource.unpack_ocp]

  provisioner "local-exec" {
    working_dir = var.install_dir
    command = <<EOF
set -ex

test -d ${local.bindir} || mkdir -p ${local.bindir}
test -f ${local.bindir}/oc || curl -s ${var.binaries_client} | tar -xz -C ${local.bindir}

${local.bindir}/oc image mirror -a ${local_file.pull_secret.filename} --insecure --from-dir=${var.install_dir}/mirror "file://openshift/release:${var.ocp_release}*" ${local.hostname}:8443/${var.repository} >${local.logdir}/ocp_mirror_push.log 2>&1

${local.bindir}/oc adm release mirror -a ${local_file.pull_secret.filename} --insecure-skip-tls-verify=true --from=quay.io/${var.product_repo}/ocp-release:${var.ocp_release}-${var.architecture} --to=${local.hostname}:8443/${var.repository} --to-release-image=${local.hostname}:8443/${var.repository}:${var.ocp_release}-${var.architecture} --dry-run >${local.logdir}/ocp_adm_release_mirror.log 2>/dev/null

EOF
  }
}

resource "null_resource" "extract_installers" {

  count = var.mirror_repo ? 1 : 0

  depends_on = [null_resource.push_ocp]

  provisioner "local-exec" {
    working_dir = var.install_dir
    command = <<EOF
set -ex

${local.bindir}/oc adm release extract -a ${local_file.pull_secret.filename} --insecure --command=openshift-install --to "${local.bindir}" "${local.hostname}:8443/${var.repository}:${var.ocp_release}-${var.architecture}"

${local.bindir}/oc adm release extract -a ${local_file.pull_secret.filename} --insecure --command=openshift-baremetal-install --to "${local.bindir}" "${local.hostname}:8443/${var.repository}:${var.ocp_release}-${var.architecture}"

EOF
  }
}

data "local_file" "quay_cert" {
  filename = "${var.install_dir}/runtime/quay-config/ssl.cert"

  depends_on = [null_resource.quay_install]
}
