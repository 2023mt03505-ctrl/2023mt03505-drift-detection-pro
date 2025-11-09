package terraform.aws_sg

# Helper: analyze relevant actions
action_allowed(rc) {
    rc.change.actions[_] == "update"
}
action_allowed(rc) {
    rc.change.actions[_] == "create"
}

# Deny insecure inbound SSH or RDP from anywhere
deny[msg] {
    some i
    rc := input.resource_changes[i]
    rc.type == "aws_security_group"
    action_allowed(rc)
    some j
    rule := rc.change.after.ingress[j]
    rule.from_port == 22
    rule.cidr_blocks[_] == "0.0.0.0/0"
    msg := sprintf("❌ AWS SG %s allows SSH from anywhere", [rc.address])
}
