resource "aws_db_instance" "node_goat_db" {
  identifier              = "node-goat-${var.environment}"
  engine                  = "postgres"
  engine_version          = "13.7"
  instance_class          = "db.t3.micro"
  allocated_storage       = 20
  db_name                 = "nodegoat"
  username                = "admin"
  password                = var.db_password
  publicly_accessible     = true
  storage_encrypted       = false
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 0
  multi_az                = false
  vpc_security_group_ids  = [aws_security_group.node_goat_app.id]
}
