package terraform.aws_s3

# -----------------------------
# Helper: Determine if a resource change should be analyzed
# -----------------------------
action_allowed(rc) {
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}
action_allowed(rc) {
    rc.change.actions[_] == "replace"
}
action_allowed(rc) {
    not rc.change.actions
    rc.change.before != rc.change.after
}

# -----------------------------
# Deny S3 Bucket Public Access
# -----------------------------
deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket_public_access_block"
    action_allowed(rc)

    pab := rc.change.after
    pab.block_public_acls == false
    msg := sprintf("❌ S3 Bucket Public Access Block disabled (block_public_acls) for %s", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket_public_access_block"
    action_allowed(rc)

    pab := rc.change.after
    pab.block_public_policy == false
    msg := sprintf("❌ S3 Bucket Public Access Block disabled (block_public_policy) for %s", [rc.address])
}

# Split ACL checks into two rules to fix parse error
deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket_acl"
    action_allowed(rc)

    rc.change.after.acl == "public-read"
    msg := sprintf("❌ S3 Bucket ACL allows public access (%s)", [rc.address])
}

deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket_acl"
    action_allowed(rc)

    rc.change.after.acl == "public-read-write"
    msg := sprintf("❌ S3 Bucket ACL allows public access (%s)", [rc.address])
}

# -----------------------------
# Deny if Encryption is not enabled
# -----------------------------
deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket_server_side_encryption_configuration"
    action_allowed(rc)

    encryption := rc.change.after.rule.apply_server_side_encryption_by_default
    not encryption.sse_algorithm
    msg := sprintf("❌ S3 Bucket %s has no server-side encryption", [rc.address])
}

# -----------------------------
# Deny if Versioning is not enabled
# -----------------------------
deny[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket_versioning"
    action_allowed(rc)

    rc.change.after.status != "Enabled"
    msg := sprintf("❌ S3 Bucket %s versioning is not enabled", [rc.address])
}

# -----------------------------
# Warn on tag-only drift
# -----------------------------
warn[msg] {
    some i
    rc := input.resource_changes[i]

    rc.type == "aws_s3_bucket"
    action_allowed(rc)

    rc.change.before.tags != rc.change.after.tags
    msg := sprintf("⚠️ Safe drift: Tags changed on %s", [rc.address])
}
