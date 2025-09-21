package terraform.nsg

# Returns true if the resource change is an update/create/replace
action_allowed(rc) {
    rc.change.actions[_] == "update"
} 
action_allowed(rc) {
    rc.change.actions[_] == "create"
}
action_allowed(rc) {
    rc.change.actions[_] == "replace"
}

# Returns true if the rule source allows world access
source_is_world(r) {
    r.source_address_prefix == "*"
}
source_is_world(r) {
    r.source_address_prefix == "0.0.0.0/0"
}

# Detect unsafe SSH rule
unsafe_rule(r) {
    r.direction == "Inbound"
    r.destination_port_range == "22"
    r.access == "Allow"
    source_is_world(r)
}

# Deny rules based on existing state
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    action_allowed(rc)

    rc.change.before != null
    some j
    rule := rc.change.before.security_rule[j]
    unsafe_rule(rule)

    msg := sprintf("❌ NSG %s has insecure SSH rule (before): %s", [rc.address, rule.name])
}

# Deny rules based on planned state
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    action_allowed(rc)

    rc.change.after != null
    some j
    rule := rc.change.after.security_rule[j]
    unsafe_rule(rule)

    msg := sprintf("❌ NSG %s will have insecure SSH rule (after): %s", [rc.address, rule.name])
}

# Warn for safe drift (tags change)
warn[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_network_security_group"
    action_allowed(rc)

    rc.change.before != null
    rc.change.after != null
    rc.change.before.tags != rc.change.after.tags

    msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
