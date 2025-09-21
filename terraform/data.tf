# Look up an existing secret named "youtube_secret"
data "aws_secretsmanager_secret" "yt" {
  name = "youtube_secret"
}

# Read its latest value
data "aws_secretsmanager_secret_version" "yt_latest" {
  secret_id = data.aws_secretsmanager_secret.yt.id
}
