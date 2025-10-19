package terraform.storage

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
# Storage Account Checks
# -----------------------------
public_blob_allowed(s) {
    s.allow_blob_public_access == true
}
public_blob_allowed(s) {
    s.allow_nested_items_to_be_public == true
}
public_blob_allowed(s) {
    s.public_network_access_enabled == true
}

https_disabled(s) {
    s.enable_https_traffic_only == false
}
https_disabled(s) {
    s.https_traffic_only_enabled == false
}

tls_invalid(s) {
    s.min_tls_version != "TLS1_2"
}

# -----------------------------
# Storage Container Checks
# -----------------------------
container_not_private(s) {
    s.container_access_type != "private"
}

# -----------------------------
# Deny unsafe configurations (Storage Account + Container)
# -----------------------------
deny[msg] {
    some i
    rc := input.resource_changes[i]

    # Storage Account checks
    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    s := rc.change.after
    public_blob_allowed(s)
    msg := sprintf("❌ Storage Account %s allows public access", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    s := rc.change.after
    https_disabled(s)
    msg := sprintf("❌ Storage Account %s HTTPS disabled", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    s := rc.change.after
    tls_invalid(s)
    msg := sprintf("❌ Storage Account %s TLS version invalid", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]

    # Storage Container checks
    rc.type == "azurerm_storage_container"
    action_allowed(rc)
    s := rc.change.after
    container_not_private(s)
    msg := sprintf("❌ Storage Container %s is not private", [rc.address])
}

# -----------------------------
# Warn for safe tag drifts
# -----------------------------
warn[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "azurerm_storage_account"
    action_allowed(rc)
    rc.change.before.tags != rc.change.after.tags
    msg := sprintf("⚠️ Safe drift: Tags changed on %s", [rc.address])
}
