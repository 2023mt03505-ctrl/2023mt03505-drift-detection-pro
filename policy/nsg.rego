package terraform.nsg

# ❌ Unsafe drift → SSH open to world
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rule := rc.change.after.security_rule[_]
  rule.destination_port_range == "22"
  rule.access == "Allow"
  rule.direction == "Inbound"
  (rule.source_address_prefix == "0.0.0.0/0" or rule.source_address_prefix == "*")

  msg := sprintf("❌ NSG %s allows SSH from world: %s", [rc.address, rule.name])
}

# ❌ Unsafe drift → RDP open to world
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rule := rc.change.after.security_rule[_]
  rule.destination_port_range == "3389"
  rule.access == "Allow"
  rule.direction == "Inbound"
  (rule.source_address_prefix == "0.0.0.0/0" or rule.source_address_prefix == "*")

  msg := sprintf("❌ NSG %s allows RDP from world: %s", [rc.address, rule.name])
}

# ❌ Unsafe drift → overly permissive ANY→ANY allow
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rule := rc.change.after.security_rule[_]
  rule.access == "Allow"
  rule.direction == "Inbound"
  rule.source_address_prefix == "*"
  rule.destination_port_range == "*"

  msg := sprintf("❌ NSG %s has overly permissive ANY→ANY allow rule: %s", [rc.address, rule.name])
}

# ⚠️ Warn → suspicious priority allow rule
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rule := rc.change.after.security_rule[_]
  rule.access == "Allow"
  rule.priority < 100

  msg := sprintf("⚠️ NSG %s has a high-priority allow rule: %s", [rc.address, rule.name])
}

# ⚠️ Safe drift → only tag update
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rc.change.actions[_] == "update"
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
