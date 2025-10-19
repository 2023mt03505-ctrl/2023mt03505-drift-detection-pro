package terraform.storage

# Determine if a resource change should be analyzed
action_allowed(rc) {
    rc.change.actions[_] == "update"
} else {
    rc.change.actions[_] == "create"
} else {
    rc.change.actions[_] == "replace"
} else {
    not rc.change.actions
    rc.change.before != rc.change.after
}

# Detect public access
public_blob_allowed(s) {
    s.allow_blob_public_access == true
} else {
    s.allow_nested_items_to_be_public == true
} else {
    s.public_network_access_enabled == true
}

# Enforce HTTPS
https_disabled(s) {
    s.enable_https_traffic_only == false
} else {
    s.https_traffic_only_enabled == false
}

# Enforce TLS >= 1.2
tls_invalid(s) {
    v := s.min_tls_version
    v != "TLS1_2"
}

# ❌ Deny unsafe configurations (public access, HTTPS disabled, weak TLS)
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    s := rc.change.after

    # Combine all unsafe checks in one line (no else)
    public_blob_allowed(s) 
    msg := sprintf("❌ Storage %s unsafe config (public/blob/https/tls)", [rc.address])
} 

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    s := rc.change.after
    https_disabled(s)
    msg := sprintf("❌ Storage %s unsafe config (public/blob/https/tls)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    s := rc.change.after
    tls_invalid(s)
    msg := sprintf("❌ Storage %s unsafe config (public/blob/https/tls)", [rc.address])
}

# ⚠️ Warn for safe tag drifts
warn[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    rc.change.before.tags != rc.change.after.tags
    msg := sprintf("⚠️ Safe drift: Tags changed on %s", [rc.address])
}
