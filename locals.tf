resource "random_string" "suffix" {
  length  = 5
  special = false
  upper   = false
  numeric = true
}

locals {
  suffix     = random_string.suffix.result
  rg_name    = "${var.name_prefix}-sandbox-rg"
  apim_name  = "${var.name_prefix}-apim-${local.suffix}"
  aoai_name  = "${var.name_prefix}-aoai-${local.suffix}"
  cs_name    = "${var.name_prefix}-cs-${local.suffix}"
  law_name   = "${var.name_prefix}-law-${local.suffix}"
  ai_name    = "${var.name_prefix}-appi-${local.suffix}"
  redis_name = "${var.name_prefix}-redis-${local.suffix}"
  apic_name  = "${var.name_prefix}-apic-${local.suffix}"

  # Per-API governance limits for the sandbox.
  default_tpm   = 2000
  default_quota = 2000000
}
