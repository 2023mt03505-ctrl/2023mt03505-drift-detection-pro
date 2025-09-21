package terraform.nsg

# ❌ Unsafe drift → SSH open to world (0.0.0.0/0 or *)
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  # Only check resources with after state (ignore destroyed)
  rc.change.after != null
  rules := rc.change.after.security_rule
  rule := rules[_]

  rule.access == "Allow"
  rule.direction == "Inbound"
  rule.destination_port_range == "22"

  # Match any world-wide source
  src := rule.source_address_prefix
  src == "*"  # or "0.0.0.0/0"

  msg := sprintf("❌ NSG %s allows SSH from world: %s", [rc.address, rule.name])
}

# ⚠️ Safe drift → only tags update
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_network_security_group"

  rc.change.actions[_] == "update"
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
