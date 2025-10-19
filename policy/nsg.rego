package terraform.nsg

# -----------------------------
# Helper: Determine if a resource change should be analyzed
# -----------------------------
action_allowed(rc) {
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}
action_allowed(rc) {
    rc.change.actions[_] == "replace"
}
action_allowed(rc) {
    not rc.change.actions
    rc.change.before != rc.change.after
}

# -----------------------------
# Deny insecure NSG rules (SSH, RDP, wide CIDR)
# -----------------------------
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    action_allowed(rc)

    some j
    rule := rc.change.after.security_rule[j]

    # Deny inbound SSH from anywhere
    rule.direction == "Inbound"
    rule.protocol == "Tcp"
    rule.destination_port_range == "22"
    rule.access == "Allow"
    rule.source_address_prefix == "*"

    msg := sprintf("❌ NSG %s rule %s allows SSH from anywhere", [rc.address, rule.name])
}

# Add more NSG rules here as needed, e.g., RDP, CIDR ranges
