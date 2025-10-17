package main

deny[msg] {
  input.resource_changes[_].change.actions[_] == "update"
  msg = "⚠️ Potential unsafe drift detected in resource update."
}
