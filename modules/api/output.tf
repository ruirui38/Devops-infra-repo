output "ecs_task_execution_role_arn" {
  description = "ECS タスク実行ロールの ARN"
  value       = aws_iam_role.task_exec_role.arn
}

output "ecs_task_role_arn" {
  description = "ECS タスクロールの ARN"
  value       = aws_iam_role.task_role.arn
}
