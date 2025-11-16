package terraform.aws_s3

# Allow drift detection on create/update/replace
action_allowed(rc) {
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}
action_allowed(rc) {
    rc.change.actions[_] == "replace"
}

# ==============================
# ❌ Detect S3 bucket public ACL (aws_s3_bucket)
# ==============================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.after.acl == "public-read"
    msg := sprintf("❌ S3 bucket %s is public (public-read)", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.after.acl == "public-read-write"
    msg := sprintf("❌ S3 bucket %s is public (public-read-write)", [rc.address])
}

# ==============================
# ❌ Detect missing encryption
# ==============================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    not rc.change.after.server_side_encryption_configuration
    msg := sprintf("❌ S3 bucket %s has no encryption enabled", [rc.address])
}

# ==============================
# ❌ Detect missing versioning
# ==============================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.after.versioning[0].status != "Enabled"
    msg := sprintf("❌ S3 bucket %s versioning is not enabled", [rc.address])
}

# ==============================
# ⚠️ Warn on tag-only drift
# ==============================
warn[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.before.tags != rc.change.after.tags
    msg := sprintf("⚠️ Safe drift: Tags changed on %s", [rc.address])
}

