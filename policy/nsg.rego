package terraform.nsg

# Helper: only consider update/create/replace
action_allowed(rc) {
  a := rc.change.actions[_]
  a in {"update", "create", "replace"}
}

# Source 0.0.0.0/0 or *
source_is_world(r) {
  r.source_address_prefix == "*"
}
source_is_world(r) {
  r.source_address_prefix == "0.0.0.0/0"
}

# Insecure SSH rule
unsafe_rule(r) {
  r.direction == "Inbound"
  r.destination_port_range == "22"
  r.access == "Allow"
  source_is_world(r)
}

# Detect insecure rules before drift
deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.before != null

  rule := rc.change.before.security_rule[_]
  unsafe_rule(rule)

  msg := sprintf("❌ NSG %s has insecure SSH rule (before drift): %s", [rc.address, rule.name])
}

# Detect insecure rules after drift
deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.after != null

  rule := rc.change.after.security_rule[_]
  unsafe_rule(rule)

  msg := sprintf("❌ NSG %s will have insecure SSH rule (after drift): %s", [rc.address, rule.name])
}

# Safe drift: tag modifications
warn[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.before != null
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
