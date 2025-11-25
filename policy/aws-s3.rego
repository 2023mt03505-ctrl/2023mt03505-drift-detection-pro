package terraform.aws_s3

# ==========================
# Allow drift detection only for modify actions
# ==========================
action_allowed(rc) {
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "replace"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}

# ==========================
# ❌ UNSAFE DRIFT — Bucket ACL becomes public
# ==========================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.after.acl == "public-read"
    msg := sprintf("❌ UNSAFE DRIFT: S3 bucket %s is public (public-read)", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.after.acl == "public-read-write"
    msg := sprintf("❌ UNSAFE DRIFT: S3 bucket %s is public (public-read-write)", [rc.address])
}

# ==========================
# ❌ UNSAFE DRIFT — Missing encryption
# ==========================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    not rc.change.after.server_side_encryption_configuration
    msg := sprintf("❌ UNSAFE DRIFT: S3 bucket %s has no encryption enabled", [rc.address])
}

# ==========================
# ❌ UNSAFE DRIFT — Versioning OFF
# ==========================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    # versioning must exist AND must be Enabled
    rc.change.after.versioning[0].status != "Enabled"
    msg := sprintf("❌ UNSAFE DRIFT: Versioning is not enabled on %s", [rc.address])
}

# ==========================
# ⚠ SAFE DRIFT — Only Tags changed
# ==========================
warn[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    before := rc.change.before.tags
    after  := rc.change.after.tags

    before != after
    msg := sprintf("⚠ SAFE DRIFT: Tag changes detected on %s", [rc.address])
}
