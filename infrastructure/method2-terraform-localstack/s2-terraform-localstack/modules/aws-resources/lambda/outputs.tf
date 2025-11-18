output "lambda_function_arn" {
  description = "ARN of the chat handler Lambda function"
  value       = aws_lambda_function.chat_handler.arn
}

output "lambda_function_name" {
  description = "Name of the chat handler Lambda function"
  value       = aws_lambda_function.chat_handler.function_name
}

output "lambda_function_invoke_arn" {
  description = "Invoke ARN for API Gateway integration"
  value       = aws_lambda_function.chat_handler.invoke_arn
}

output "lambda_role_arn" {
  description = "ARN of the Lambda execution role"
  value       = aws_iam_role.lambda_exec.arn
}

output "lambda_log_group" {
  description = "CloudWatch log group for Lambda"
  value       = aws_cloudwatch_log_group.lambda_chat.name
}
