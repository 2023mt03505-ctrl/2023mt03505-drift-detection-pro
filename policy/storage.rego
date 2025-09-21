package terraform.storage

# Check if action is update, create, or replace
action_allowed(rc) {
  some a
  a := rc.change.actions[_]
  a in ["update", "create", "replace"]
}

# Public access checks
public_blob_allowed(s) {
  s.allow_blob_public_access == true
}
public_blob_allowed(s) {
  s.allow_nested_items_to_be_public == true
}
public_blob_allowed(s) {
  s.public_network_access_enabled == true
}

# HTTPS checks
https_disabled(s) {
  s.enable_https_traffic_only == false
}
https_disabled(s) {
  s.https_traffic_only_enabled == false
}

# TLS version checks
tls_invalid(s) {
  v := s.min_tls_version
  v != "TLS1_2"
}

# ❌ Public blob access before drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)

  rc.change.before != null
  public_blob_allowed(rc.change.before)

  msg := sprintf("❌ Storage Account %s allows public blob access (before)", [rc.address])
}

# ❌ Public blob access after drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)

  rc.change.after != null
  public_blob_allowed(rc.change.after)

  msg := sprintf("❌ Storage Account %s will allow public blob access (after)", [rc.address])
}

# ❌ HTTPS disabled before drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)

  rc.change.before != null
  https_disabled(rc.change.before)

  msg := sprintf("❌ Storage Account %s has HTTPS disabled (before)", [rc.address])
}

# ❌ HTTPS disabled after drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)

  rc.change.after != null
  https_disabled(rc.change.after)

  msg := sprintf("❌ Storage Account %s will have HTTPS disabled (after)", [rc.address])
}

# ❌ Invalid TLS version before drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)

  rc.change.before != null
  tls_invalid(rc.change.before)

  msg := sprintf("❌ Storage Account %s has non-TLS1_2 (before)", [rc.address])
}

# ❌ Invalid TLS version after drift
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)

  rc.change.after != null
  tls_invalid(rc.change.after)

  msg := sprintf("❌ Storage Account %s will have non-TLS1_2 (after)", [rc.address])
}
