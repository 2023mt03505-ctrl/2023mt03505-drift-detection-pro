package terraform.storage

# Returns true if the resource change should be analyzed
action_allowed(rc) {
    # Normal plan changes
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}
action_allowed(rc) {
    rc.change.actions[_] == "replace"
}
action_allowed(rc) {
    # Drift-only plan (no actions array but before/after differ)
    not rc.change.actions
    rc.change.before != rc.change.after
}


# Detect public blob access
public_blob_allowed(s) {
    s.allow_blob_public_access == true
}
public_blob_allowed(s) {
    s.allow_nested_items_to_be_public == true
}
public_blob_allowed(s) {
    s.public_network_access_enabled == true
}

# Detect HTTPS disabled
https_disabled(s) {
    s.enable_https_traffic_only == false
}
https_disabled(s) {
    s.https_traffic_only_enabled == false
}

# Detect invalid TLS version
tls_invalid(s) {
    v := s.min_tls_version
    v != "TLS1_2"
}

# Deny unsafe storage rules
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)

    rc.change.before != null
    public_blob_allowed(rc.change.before)

    msg := sprintf("❌ Storage Account %s allows public blob access (before)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)

    rc.change.after != null
    public_blob_allowed(rc.change.after)

    msg := sprintf("❌ Storage Account %s will allow public blob access (after)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)

    rc.change.before != null
    https_disabled(rc.change.before)

    msg := sprintf("❌ Storage Account %s has HTTPS disabled (before)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)

    rc.change.after != null
    https_disabled(rc.change.after)

    msg := sprintf("❌ Storage Account %s will have HTTPS disabled (after)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)

    rc.change.before != null
    tls_invalid(rc.change.before)

    msg := sprintf("❌ Storage Account %s has non-TLS1_2 (before)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)

    rc.change.after != null
    tls_invalid(rc.change.after)

    msg := sprintf("❌ Storage Account %s will have non-TLS1_2 (after)", [rc.address])
}
