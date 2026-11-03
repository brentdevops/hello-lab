# OPS-240: managed Postgres (RDS). Only the app server can reach it.

# ---------- firewall: who can reach the database ----------
resource "aws_security_group" "db" {
  name        = "hello-lab-db"
  description = "hello-lab RDS: postgres from the app node only"
  vpc_id      = data.aws_vpc.default.id
}

resource "aws_vpc_security_group_ingress_rule" "db_from_node" {
  security_group_id            = aws_security_group.db.id
  description                  = "postgres from the app node"
  referenced_security_group_id = aws_security_group.node.id
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
}

# ---------- the database ----------
resource "aws_db_instance" "app" {
  identifier     = "hello-lab-db"
  engine         = "postgres"
  engine_version = "16"
  instance_class = "db.t4g.micro"

  allocated_storage = 20
  storage_type      = "gp3"
  storage_encrypted = true

  username                    = "postgres"
  manage_master_user_password = true

  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  backup_retention_period = 1
  skip_final_snapshot     = true
  deletion_protection     = false
  apply_immediately       = true
}

# ---------- what the app needs to connect ----------
output "db_address" {
  value = aws_db_instance.app.address
}

output "db_secret_arn" {
  value = aws_db_instance.app.master_user_secret[0].secret_arn
}
