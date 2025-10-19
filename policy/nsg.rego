package terraform.nsg

# Return true if change should be analyzed
action_allowed(rc) {
  rc.change.actions[_] == "update"
} else {
  rc.change.actions[_] == "create"
} else {
  rc.change.actions[_] == "replace"
} else {
  not rc.change.actions
  rc.change.before != rc.change.after
}

# Check if world access is allowed
source_is_world(r) {
  r.source_address_prefix == "*"
} else {
  r.source_address_prefix == "0.0.0.0/0"
}

# Detect unsafe SSH rule
unsafe_rule(r) {
  r.direction == "Inbound"
  r.destination_port_range == "22"
  r.access == "Allow"
  source_is_world(r)
}

# Deny for unsafe SSH rules
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.after != null
  some j
  rule := rc.change.after.security_rule[j]
  unsafe_rule(rule)

  msg := sprintf("❌ NSG %s insecure SSH rule: %s", [rc.address, rule.name])
}

# Warn for tag drifts (safe)
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags changed on %s", [rc.address])
}
