package terraform.nsg

deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  rc.change.actions[_] == "update"
  rule := rc.change.after.security_rule[_]
  rule.access == "Allow"
  rule.direction == "Inbound"
  rule.destination_port_range == "22"
  rule.source_address_prefix == "*"
  msg := sprintf("❌ NSG %s allows SSH from world: %s", [rc.address, rule.name])
}

warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"
  rc.change.actions[_] == "update"
  rc.change.before.tags != rc.change.after.tags
  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
