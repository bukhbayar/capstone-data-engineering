resource "aws_iam_role" "role" {
  name = "${var.role_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "profile" {
  name = "${var.role_name}-profile"
  role = aws_iam_role.role.name
}

resource "aws_iam_role_policy" "s3_logs_rw" {
  name   = "airflow-s3-logs-rw"
  role   = aws_iam_role.role.id
  policy = jsonencode({
    Version="2012-10-17",
    Statement=[{
      Effect="Allow",
      Action=["s3:*"],
      Resource=[
        "arn:aws:s3:::${var.airflow_logs_bucket}",
        "arn:aws:s3:::${var.airflow_logs_bucket}/*"
      ]
    }]
  })
}