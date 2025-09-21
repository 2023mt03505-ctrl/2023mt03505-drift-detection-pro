package terraform.nsg

deny[msg] {
  input.resource_changes[i].type == "azurerm_network_security_group"
  a := input.resource_changes[i].actions[_]
  a in ["update", "create", "replace"]

  some rule
  rule := input.resource_changes[i].change.after.security_rule[_]
  rule.destination_port_range == "22"
  rule.access == "Allow"
  msg := sprintf("❌ Unsafe drift: NSG allows SSH from world on port %v", [rule.destination_port_range])
}
