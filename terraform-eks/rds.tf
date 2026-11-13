# --------------------------------------------------
# BANCO DE DADOS: RDS MySQL (substitui o MySQL em host.minikube.internal:3310)
# --------------------------------------------------

# 1. Senha gerada automaticamente (fica apenas no state do Terraform)
resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%^&*()-_=+" # RDS não aceita / @ " e espaço
}

# 2. Subnets privadas onde o RDS pode ser alocado
resource "aws_db_subnet_group" "mysql" {
  name       = "${var.cluster_name}-mysql"
  subnet_ids = module.vpc.private_subnets
}

# 3. Firewall: apenas os nós do EKS acessam a porta 3306
resource "aws_security_group" "rds" {
  name        = "${var.cluster_name}-rds"
  description = "Acesso MySQL a partir dos nos do EKS"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_nodes" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = module.eks.node_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL a partir dos nos do EKS"
}

resource "aws_vpc_security_group_ingress_rule" "rds_from_cluster" {
  security_group_id            = aws_security_group.rds.id
  referenced_security_group_id = module.eks.cluster_primary_security_group_id
  ip_protocol                  = "tcp"
  from_port                    = 3306
  to_port                      = 3306
  description                  = "MySQL a partir do SG primario do cluster"
}

# 4. Parâmetros: o MySQL 8.4 do RDS exige SSL por padrão, mas a URL JDBC
#    do backend usa useSSL=false — então liberamos conexões sem TLS.
resource "aws_db_parameter_group" "mysql" {
  name   = "${var.cluster_name}-mysql84"
  family = "mysql8.4"

  parameter {
    name  = "require_secure_transport"
    value = "0"
  }
}

# 5. Instância MySQL
resource "aws_db_instance" "mysql" {
  identifier     = "${var.cluster_name}-mysql"
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  allocated_storage = var.db_allocated_storage
  storage_type      = "gp3"
  storage_encrypted = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 3306

  db_subnet_group_name   = aws_db_subnet_group.mysql.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  parameter_group_name   = aws_db_parameter_group.mysql.name
  publicly_accessible    = false

  # Ambiente de TCC: destroy rápido, sem snapshot final
  skip_final_snapshot     = true
  deletion_protection     = false
  backup_retention_period = 1
  apply_immediately       = true
}
