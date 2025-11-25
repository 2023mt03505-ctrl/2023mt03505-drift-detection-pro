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

# Helpers: safe access to before/after objects (avoid errors if missing)
before(rc) = b {
    b := rc.change.before
}
after(rc) = a {
    a := rc.change.after
}

# Utility: compare tags safely (works if tags are null/missing)
tags_changed(rc) {
    b := before(rc)
    a := after(rc)
    # normalize missing tags to empty object
    bt := b.tags
    at := a.tags
    bt == null
    bt = {}
    not bt
    false
} {
    false
}
tags_changed(rc) {
    b := before(rc)
    a := after(rc)
    bt := default({}, b.tags)
    at := default({}, a.tags)
    bt != at
}

# --------------------------
# ❌ DENY: Tag changes are treated as UNSAFE (user requested)
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_s3_bucket"
    action_allowed(rc)
    # detect tag differences (including creation / update)
    (rc.change.before.tags != rc.change.after.tags)
    msg := sprintf("❌ Unsafe drift: Tags modified for %s — before=%v after=%v", [rc.address, rc.change.before.tags, rc.change.after.tags])
}

# --------------------------
# ❌ DENY: Public ACL via aws_s3_bucket.acl or aws_s3_bucket_acl
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket"
    a := after(rc)
    a.acl == "public-read"
    msg := sprintf("❌ S3 bucket %s is public (acl=public-read)", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket"
    a := after(rc)
    a.acl == "public-read-write"
    msg := sprintf("❌ S3 bucket %s is public (acl=public-read-write)", [rc.address])
}

# If ACL is managed via separate resource
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_acl"
    a := after(rc)
    a.acl == "public-read"
    msg := sprintf("❌ S3 ACL resource %s sets public-read on %s", [rc.address, a.bucket])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_acl"
    a := after(rc)
    a.acl == "public-read-write"
    msg := sprintf("❌ S3 ACL resource %s sets public-read-write on %s", [rc.address, a.bucket])
}

# catch grants with AllUsers / AuthenticatedUsers in aws_s3_bucket grant list
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket"
    a := after(rc)
    grant := a.grant[_]
    grant.uri == "http://acs.amazonaws.com/groups/global/AllUsers"
    msg := sprintf("❌ S3 bucket %s has a grant to AllUsers (public access via ACL grant)", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket"
    a := after(rc)
    grant := a.grant[_]
    grant.uri == "http://acs.amazonaws.com/groups/global/AuthenticatedUsers"
    msg := sprintf("❌ S3 bucket %s has a grant to AuthenticatedUsers (potential public access)", [rc.address])
}

# --------------------------
# ❌ DENY: Public access block disabled (should be true)
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_public_access_block"
    a := after(rc)
    # If any of these protective flags are false -> deny
    (a.block_public_acls == false) ||
    (a.ignore_public_acls == false) ||
    (a.block_public_policy == false) ||
    (a.restrict_public_buckets == false)
    msg := sprintf("❌ S3 Public Access Block misconfigured for %s (one or more protections disabled)", [rc.address])
}

# --------------------------
# ❌ DENY: Missing or incorrect server-side encryption
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)

    # Case A: encryption is tracked under aws_s3_bucket_server_side_encryption_configuration
    rc.type == "aws_s3_bucket_server_side_encryption_configuration"
    a := after(rc)

    not a.rule
    msg := sprintf("❌ Encryption removed for %s (server_side_encryption_configuration missing)", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)

    rc.type == "aws_s3_bucket_server_side_encryption_configuration"
    a := after(rc)

    # algorithm changed or missing
    algo := a.rule[0].apply_server_side_encryption_by_default.sse_algorithm
    not algo
    msg := sprintf("❌ Encryption algorithm missing for %s", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)

    rc.type == "aws_s3_bucket_server_side_encryption_configuration"
    a := after(rc)

    algo := a.rule[0].apply_server_side_encryption_by_default.sse_algorithm
    # Enforce AES256 or AWS KMS (you may list allowed algos here)
    not (algo == "AES256" || startswith(algo, "aws:kms"))
    msg := sprintf("❌ Unexpected encryption algorithm for %s: %v", [rc.address, algo])
}

# Also check aws_s3_bucket top-level server_side_encryption_configuration if present
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket"
    a := after(rc)
    not a.server_side_encryption_configuration
    msg := sprintf("❌ S3 bucket %s has no server_side_encryption_configuration block", [rc.address])
}

# --------------------------
# ❌ DENY: Missing or disabled versioning
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_versioning"
    a := after(rc)

    # status is expected to be "Enabled"
    not a.versioning_configuration
    msg := sprintf("❌ Versioning removed for %s", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_versioning"
    a := after(rc)
    a.versioning_configuration.status != "Enabled"
    msg := sprintf("❌ Versioning not enabled for %s (status=%v)", [rc.address, a.versioning_configuration.status])
}

# Also check inline versioning block on aws_s3_bucket (some configs use that)
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket"
    a := after(rc)
    # if versioning array exists, check first element's status
    a.versioning != null
    status := a.versioning[0].status
    status != "Enabled"
    msg := sprintf("❌ S3 bucket %s versioning is not Enabled (status=%v)", [rc.address, status])
}

# --------------------------
# ❌ DENY: Public bucket policy / policy allowing "*" principal or public statements
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_policy"
    a := after(rc)
    policy := a.policy
    # quick heuristic: public principal or "Allow" to "*"
    contains(policy, "\"Principal\": \"*\"")
    msg := sprintf("❌ Bucket policy for %s contains public principal '*'", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_policy"
    a := after(rc)
    policy := a.policy
    contains(policy, "\"Principal\": {\"AWS\": \"*\"}")
    msg := sprintf("❌ Bucket policy for %s contains public principal AWS:*", [rc.address])
}

# --------------------------
# ❌ DENY: Server access logging disabled (recommended in production)
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    # If there's an explicit aws_s3_bucket_logging resource it should be enabled;
    # if logging is removed from aws_s3_bucket, deny as well.
    rc.type == "aws_s3_bucket"
    a := after(rc)
    # if logging block missing or target_bucket empty -> deny
    (a.logging == null) || (a.logging[0].target_bucket == "" )
    msg := sprintf("❌ Server access logging is not configured for %s", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_logging"
    a := after(rc)
    not a.target_bucket
    msg := sprintf("❌ aws_s3_bucket_logging for %s has no target_bucket configured", [rc.address])
}

# --------------------------
# ❌ DENY: Ownership controls not enforcing bucket owner (recommended)
# --------------------------
deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_ownership_controls"
    a := after(rc)
    not a.rule
    msg := sprintf("❌ Ownership controls missing for %s", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    action_allowed(rc)
    rc.type == "aws_s3_bucket_ownership_controls"
    a := after(rc)
    a.rule[0].object_ownership != "BucketOwnerEnforced"
    msg := sprintf("❌ Ownership controls for %s not set to BucketOwnerEnforced", [rc.address])
}

# --------------------------
# Default: no warnings (all assertions modeled as deny)
# --------------------------
# If you want warnings instead of denies for lower-risk items, add warn rules here.

