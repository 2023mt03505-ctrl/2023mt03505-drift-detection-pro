package terraform.storage

deny[msg] {
  input.resource_changes[i].type == "azurerm_storage_container"
  a := input.resource_changes[i].actions[_]
  a in ["update", "create", "replace"]

  input.resource_changes[i].change.after.container_access_type == "container"
  msg := "❌ Unsafe drift: Storage container exposed with 'container' access (public)."
}
