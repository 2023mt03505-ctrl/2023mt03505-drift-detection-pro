package terraform.general

# ❌ Location drift
deny[msg] {
  some i
  rc := input.resource_changes[i]

  rc.change.before.location != rc.change.after.location
  msg := sprintf("❌ Resource %s location drift detected (%s → %s)", [rc.address, rc.change.before.location, rc.change.after.location])
}

# ❌ Resource deleted outside Terraform
deny[msg] {
  some i
  rc := input.resource_changes[i]

  rc.change.actions[_] == "delete"
  msg := sprintf("❌ Resource %s deleted outside Terraform", [rc.address])
}
