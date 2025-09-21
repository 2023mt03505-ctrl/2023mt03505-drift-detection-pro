package terraform.nsg

# Check if action is update, create, or replace
action_allowed(rc) {
  some a
  a := rc.change.actions[_]
  a in ["update", "create", "replace"]
}

# Detect if source is world
source_is_world(r) {
  r.source_address_prefix == "*"
}
source_is_world(r) {
  r.source_address_prefix == "0.0.0.0/0"
}

# Unsafe SSH inbound rule
unsafe_rule(r) {
  r.direction == "Inbound"
  r.destination_port_range == "22"
  r.access == "Allow"
  source_is_world(r)
}

# Deny if insecure rule exists BEFORE drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)

  rc.change.before != null
  rule := rc.change.before.security_rule[_]
  unsafe_rule(rule)

  msg := sprintf("❌ NSG %s has insecure SSH rule (before): %s", [rc.address, rule.name])
}

# Deny if insecure rule exists AFTER drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)

  rc.change.after != null
  rule := rc.change.after.security_rule[_]
  unsafe_rule(rule)

  msg := sprintf("❌ NSG %s will have insecure SSH rule (after): %s", [rc.address, rule.name])
}

# Warn on safe drift (tags only)
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.before != null
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
