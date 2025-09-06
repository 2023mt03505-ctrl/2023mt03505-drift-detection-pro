package terraform.storage

# Unsafe drift → public container
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_container"
  rc.change.after.container_access_type != "private"
  msg = sprintf("❌ Storage container %s is public! Must be private.", [rc.address])
}

# Safe drift → just tags changed
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_storage_container"
  rc.change.actions[_] == "update"
  rc.change.before.tags != rc.change.after.tags
  msg = sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
