data "template_file" "data_script" {
  template = <<EOF
#!/bin/bash

set -e

# Extract "foo" and "baz" arguments from the input into
# FOO and BAZ shell variables.
# jq will ensure that the values are properly quoted
# and escaped for consumption by the shell.
eval "$(jq -r '@sh "CMD=\(.command)"')"

# Placeholder for whatever data-fetching logic your script implements
STDOUT=`eval $(echo $CMD | base64 -d) | base64 -w0`

# Safely produce a JSON object containing the result value.
# jq will ensure that the value is properly quoted
# and escaped to produce a valid JSON string.
jq -n --arg stdout "$STDOUT" '{"stdout":$stdout}'
EOF
}

resource "local_file" "data_script" {
    content  = data.template_file.data_script.rendered
    filename = "${path.module}/get_data.sh"
    file_permission = 755
}

data "external" "command" {
  program = [local_file.data_script.filename]

  query = {
      command = base64encode(var.command)
  }
}

output "data" {
  value = base64decode(data.external.command.result.stdout)
}


