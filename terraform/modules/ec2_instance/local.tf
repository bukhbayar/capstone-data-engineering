
locals {
  name = "${var.project}-${var.environment}-etl"

  user_data = var.user_data
}