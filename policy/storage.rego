package terraform.storage

# Helper: only consider update/create/replace
action_allowed(rc) {
  a := rc.change.actions[_]
  a in {"update", "create", "replace"}
}

# Public blob access checks (safe with object.get)
public_blob_allowed(s) {
  object.get(s, "allow_blob_public_access", false) == true
}
public_blob_allowed(s) {
  object.get(s, "allow_nested_items_to_be_public", false) == true
}
public_blob_allowed(s) {
  object.get(s, "public_network_access_enabled", false) == true
}

# HTTPS disabled checks
https_disabled(s) {
  object.get(s, "enable_https_traffic_only", true) == false
}
https_disabled(s) {
  object.get(s, "https_traffic_only_enabled", true) == false
}

# TLS checks
tls_invalid(s) {
  v := object.get(s, "min_tls_version", "TLS1_2")
  v != "TLS1_2"
}

# ---- Policies ----

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)
  rc.change.before != null
  public_blob_allowed(rc.change.before)

  msg := sprintf("❌ Storage Account %s allows public blob access (before drift)", [rc.address])
}

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)
  rc.change.after != null
  public_blob_allowed(rc.change.after)

  msg := sprintf("❌ Storage Account %s will allow public blob access (after drift)", [rc.address])
}

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)
  rc.change.before != null
  https_disabled(rc.change.before)

  msg := sprintf("❌ Storage Account %s has HTTPS disabled (before drift)", [rc.address])
}

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)
  rc.change.after != null
  https_disabled(rc.change.after)

  msg := sprintf("❌ Storage Account %s will have HTTPS disabled (after drift)", [rc.address])
}

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)
  rc.change.before != null
  tls_invalid(rc.change.before)

  msg := sprintf("❌ Storage Account %s has non-TLS1_2 (before drift)", [rc.address])
}

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "azurerm_storage_account"
  action_allowed(rc)
  rc.change.after != null
  tls_invalid(rc.change.after)

  msg := sprintf("❌ Storage Account %s will have non-TLS1_2 (after drift)", [rc.address])
}
