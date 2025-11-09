package terraform.aws_general

# ❌ Region drift
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.change.before.region != rc.change.after.region
    msg := sprintf("❌ Resource %s region drift detected (%s → %s)", [rc.address, rc.change.before.region, rc.change.after.region])
}

# ❌ Resource deleted outside Terraform
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.change.actions[_] == "delete"
    msg := sprintf("❌ Resource %s deleted outside Terraform", [rc.address])
}

# ⚠️ Tag drift (safe)
warn[msg] {
    some i
    rc := input.resource_changes[i]
    rc.change.before.tags != rc.change.after.tags
    msg := sprintf("⚠️ Safe drift: Tags modified on %s", [rc.address])
}
