output "secret_for_db_arn" {
  value = aws_secretsmanager_secret.main.arn
}