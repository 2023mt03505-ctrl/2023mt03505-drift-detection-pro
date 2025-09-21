package terraform.storage

# ❌ Deny public blob access
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"

  rc.change.after != null
  rc.change.after.allow_blob_public_access == true

  msg := sprintf("❌ Storage Account %s allows public blob access", [rc.address])
}

# ❌ Enforce HTTPS only
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"

  rc.change.after != null
  rc.change.after.enable_https_traffic_only == false

  msg := sprintf("❌ Storage Account %s has HTTPS traffic disabled", [rc.address])
}

# ❌ Enforce TLS1_2 minimum
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"

  rc.change.after != null
  rc.change.after.min_tls_version != "TLS1_2"

  msg := sprintf("❌ Storage Account %s does not enforce TLS1_2", [rc.address])
}

# ❌ Replication type must exist
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"

  rc.change.after != null
  not rc.change.after.account_replication_type

  msg := sprintf("❌ Storage Account %s missing replication type", [rc.address])
}

# ⚠️ Safe drift → only tags update
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_account"

  rc.change.actions[_] == "update"
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
