package drift.s3

# INPUT STRUCTURE (from terraform show -json)
# input.resource_changes[name].change.after


##################################################################
## RULE 1: Bucket Versioning must be enabled (FAIL)
##################################################################
deny[msg] {
  some name
  input.resource_changes[name].type == "aws_s3_bucket_versioning"
  versioning := input.resource_changes[name].change.after
  not versioning.enabled
  msg := sprintf("❌ S3 Versioning disabled for bucket: %s", [name])
}


##################################################################
## RULE 2: Bucket encryption must be AES256 or KMS (FAIL)
##################################################################
deny[msg] {
  some name
  input.resource_changes[name].type == "aws_s3_bucket_server_side_encryption_configuration"

  enc := input.resource_changes[name].change.after.rule[0].apply_server_side_encryption_by_default
  not enc.sse_algorithm

  msg := sprintf("❌ Missing default SSE encryption on bucket: %s", [name])
}

deny[msg] {
  some name
  input.resource_changes[name].type == "aws_s3_bucket_server_side_encryption_configuration"

  enc := input.resource_changes[name].change.after.rule[0].apply_server_side_encryption_by_default
  enc.sse_algorithm != "AES256"
  enc.sse_algorithm != "aws:kms"

  msg := sprintf("❌ Invalid encryption algorithm on bucket: %s (must be AES256 or KMS)", [name])
}


##################################################################
## RULE 3: Public Access MUST be blocked (FAIL)
##################################################################
deny[msg] {
  some name
  input.resource_changes[name].type == "aws_s3_bucket_public_access_block"

  pab := input.resource_changes[name].change.after

  pab.block_public_acls != true
  msg := sprintf("❌ block_public_acls=false for bucket: %s", [name])
}

deny[msg] {
  some name
  input.resource_changes[name].type == "aws_s3_bucket_public_access_block"

  pab := input.resource_changes[name].change.after

  pab.block_public_policy != true
  msg := sprintf("❌ block_public_policy=false for bucket: %s", [name])
}


##################################################################
## RULE 4: Tag drift (Only WARNING — Do NOT FAIL)
##################################################################
warning[msg] {
  some name
  input.resource_changes[name].type == "aws_s3_bucket"

  after_tags := input.resource_changes[name].change.after.tags
  before_tags := input.resource_changes[name].change.before.tags

  after_tags != before_tags

  msg := sprintf("⚠️ Warning: S3 bucket tags drifted for %s", [name])
}


##################################################################
## OUTPUT
##################################################################
# Failures
deny_output[msg] {
  msg := deny[_]
}

# Warnings
warn_output[msg] {
  msg := warning[_]
}
