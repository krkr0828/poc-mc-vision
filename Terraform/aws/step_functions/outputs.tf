output "state_machine_arn" {
  description = "ARN of the Step Functions multi-model pipeline"
  value       = aws_sfn_state_machine.this.arn
}

output "state_machine_name" {
  description = "Name of the state machine"
  value       = aws_sfn_state_machine.this.name
}
