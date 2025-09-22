# Generate strong passwords
resource "random_password" "mongo_root" {
  length  = 24
  special = true
}

resource "random_password" "mongo_app" {
  length  = 24
  special = true
}

# Root/admin secret (used by Mongo init on VM2)
resource "aws_secretsmanager_secret" "mongo_root" {
  name = "${var.project_name}/mongo-root"
  tags = { Project = var.project_name }
}

resource "aws_secretsmanager_secret_version" "mongo_root_v" {
  secret_id     = aws_secretsmanager_secret.mongo_root.id
  secret_string = jsonencode({
    username = "root"
    password = random_password.mongo_root.result
    db       = "admin"
  })
}

# App user secret (used by VM2 to create user, and by VM3 to connect)
resource "aws_secretsmanager_secret" "mongo_app" {
  name = "${var.project_name}/mongo-app"
  tags = { Project = var.project_name }
}

resource "aws_secretsmanager_secret_version" "mongo_app_v" {
  secret_id     = aws_secretsmanager_secret.mongo_app.id
  secret_string = jsonencode({
    username = "app"
    password = random_password.mongo_app.result
    db       = "ca1"
    authDb   = "admin"
  })
}

output "secret_arns" {
  value = {
    mongo_root = aws_secretsmanager_secret.mongo_root.arn
    mongo_app  = aws_secretsmanager_secret.mongo_app.arn
  }
}
