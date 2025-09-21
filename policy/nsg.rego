package terraform.nsg

# ❌ Unsafe drift: SSH open to world (0.0.0.0/0 or *)
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    rc.change.after != null

    rules := rc.change.after.security_rule
    rule := rules[_]

    # Defensive checks
    rule.access == "Allow"
    rule.direction == "Inbound"
    rule.destination_port_range == "22"

    src := rule.source_address_prefix
    src == "*"  # wildcard
    msg := sprintf("❌ NSG %s allows SSH from world: %s", [rc.address, rule.name])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    rc.change.after != null

    rules := rc.change.after.security_rule
    rule := rules[_]

    rule.access == "Allow"
    rule.direction == "Inbound"
    rule.destination_port_range == "22"

    src := rule.source_address_prefix
    src == "0.0.0.0/0"  # explicit
    msg := sprintf("❌ NSG %s allows SSH from world: %s", [rc.address, rule.name])
}

# ⚠️ Safe drift: tag changes
warn[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    rc.change.after != null

    rc.change.actions[_] == "update"
    rc.change.before.tags != rc.change.after.tags
    msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
