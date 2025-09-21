resource "aws_secretsmanager_secret" "youtube_secret" {
  name        = "youtube_secret"
  description = "YouTube Data API v3 key for ${var.project}"
}

resource "aws_secretsmanager_secret_version" "youtube_secret_version" {
  secret_id = aws_secretsmanager_secret.youtube_secret.id
  secret_string = var.yt_api_key
}