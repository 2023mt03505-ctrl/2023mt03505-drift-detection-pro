package terraform.aws_sg

# Allow drift detection on create/update
action_allowed(rc) {
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}

# ==============================
# ❌ Detect insecure SSH / RDP inbound
# ==============================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_security_group"
    action_allowed(rc)

    rule := rc.change.after.ingress[_]
    rule.from_port == 22
    rule.cidr_blocks[_] == "0.0.0.0/0"

    msg := sprintf("❌ AWS SG %s allows SSH (22) from anywhere", [rc.address])
}

deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_security_group"
    action_allowed(rc)

    rule := rc.change.after.ingress[_]
    rule.from_port == 3389
    rule.cidr_blocks[_] == "0.0.0.0/0"

    msg := sprintf("❌ AWS SG %s allows RDP (3389) from anywhere", [rc.address])
}

# ==============================
# ❌ Detect IPv6 public access
# ==============================
deny[msg] {
    rc := input.resource_changes[_]
    rc.type == "aws_security_group"
    action_allowed(rc)

    rule := rc.change.after.ingress[_]
    rule.ipv6_cidr_blocks[_] == "::/0"

    msg := sprintf("❌ AWS SG %s allows public IPv6 access (::/0)", [rc.address])
}
