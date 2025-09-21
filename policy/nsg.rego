package terraform.nsg

action_allowed(rc) {
  a := rc.change.actions[_]
  a in {"update","create","replace"}
}

source_is_world(r) {
  s := r.source_address_prefix
  s == "*"  # wildcard
}
source_is_world(r) {
  s := r.source_address_prefix
  s == "0.0.0.0/0"
}

unsafe_rule(r) {
  r.direction == "Inbound"
  r.destination_port_range == "22"
  r.access == "Allow"
  source_is_world(r)
}

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

warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  action_allowed(rc)
  rc.change.before != null
  rc.change.before.tags != rc.change.after.tags
  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
