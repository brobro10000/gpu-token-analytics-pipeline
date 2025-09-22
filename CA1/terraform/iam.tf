# Trust policy for EC2
data "aws_iam_policy_document" "ec2_trust" {
  statement {
    actions = ["sts:AssumeRole"]
    principals { type = "Service" identifiers = ["ec2.amazonaws.com"] }
  }
}

# ----- VM2 (Mongo) role: can read both root & app secrets
resource "aws_iam_role" "vm2_role" {
  name               = "${var.project_name}-vm2-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = { Project = var.project_name }
}

data "aws_iam_policy_document" "vm2_secrets_access" {
  statement {
    actions = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [
      aws_secretsmanager_secret.mongo_root.arn,
      aws_secretsmanager_secret.mongo_app.arn
    ]
  }
}

resource "aws_iam_policy" "vm2_secrets_access" {
  name   = "${var.project_name}-vm2-secrets"
  policy = data.aws_iam_policy_document.vm2_secrets_access.json
}

resource "aws_iam_role_policy_attachment" "vm2_attach" {
  role       = aws_iam_role.vm2_role.name
  policy_arn = aws_iam_policy.vm2_secrets_access.arn
}

resource "aws_iam_instance_profile" "vm2_profile" {
  name = "${var.project_name}-vm2-profile"
  role = aws_iam_role.vm2_role.name
}

# ----- VM3 (Processor) role: can read ONLY the app secret
resource "aws_iam_role" "vm3_role" {
  name               = "${var.project_name}-vm3-role"
  assume_role_policy = data.aws_iam_policy_document.ec2_trust.json
  tags               = { Project = var.project_name }
}

data "aws_iam_policy_document" "vm3_secrets_access" {
  statement {
    actions   = ["secretsmanager:GetSecretValue", "secretsmanager:DescribeSecret"]
    resources = [aws_secretsmanager_secret.mongo_app.arn]
  }
}

resource "aws_iam_policy" "vm3_secrets_access" {
  name   = "${var.project_name}-vm3-secrets"
  policy = data.aws_iam_policy_document.vm3_secrets_access.json
}

resource "aws_iam_role_policy_attachment" "vm3_attach" {
  role       = aws_iam_role.vm3_role.name
  policy_arn = aws_iam_policy.vm3_secrets_access.arn
}

resource "aws_iam_instance_profile" "vm3_profile" {
  name = "${var.project_name}-vm3-profile"
  role = aws_iam_role.vm3_role.name
}
