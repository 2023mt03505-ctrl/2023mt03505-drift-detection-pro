package terraform.rg

# ❌ Resource Group renamed (dangerous drift)
deny[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_resource_group"

  rc.change.before.name != rc.change.after.name
  msg := sprintf("❌ Resource Group name drift detected on %s", [rc.address])
}

# ⚠️ Safe drift → tags modified
warn[msg] {
  some i
  rc := input.resource_changes[i]
  rc.type == "azurerm_resource_group"

  rc.change.actions[_] == "update"
  rc.change.before.tags != rc.change.after.tags

  msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
