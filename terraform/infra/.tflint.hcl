config {
  format = "compact"
  plugin_dir = "~/.tflint.d/plugins"

  module = true
  force = false
  disabled_by_default = false

  varfile = ["terraform.tfvars"]
}

rule "terraform_unused_declarations" {
  enabled = false
}

plugin "opa" {
  enabled = true
  version = "0.2.0"
  source  = "github.com/terraform-linters/tflint-ruleset-opa"
}

plugin "terraform" {
    enabled = true
    version = "0.2.2"
    source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}