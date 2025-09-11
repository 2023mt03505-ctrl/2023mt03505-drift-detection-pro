deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rules := rc.change.after.security_rule
  rule := rules[_]

  rule.destination_port_range == "22"
  rule.access == "Allow"
  rule.direction == "Inbound"
  rule.source_address_prefix in {"0.0.0.0/0", "*"}

  msg := sprintf("❌ NSG %s allows SSH from world: %s", [rc.address, rule.name])
}
