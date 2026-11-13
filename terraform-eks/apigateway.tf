# --------------------------------------------------
# API GATEWAY (HTTP API já existente) -> BACKEND NO EKS
#
# Caminho da requisição:
#   Cliente -> API Gateway (HTTP API, stage $default)
#           -> VPC Link (ENIs nas subnets privadas)
#           -> NLB interno :8080
#           -> NodePort do backend-service nos nós do EKS
#           -> pods do backend :8080
#
# A API em si (o3l1ibqnmb) foi criada fora do Terraform: aqui só criamos o
# VPC Link, a integração e a rota $default dentro dela. O stage $default já
# tem auto-deploy, então a rota entra no ar sem um deployment manual.
# --------------------------------------------------

data "aws_apigatewayv2_api" "backend" {
  api_id = var.api_gateway_id
}

# 1. NLB interno (sem acesso pela internet) nas subnets privadas
resource "aws_lb" "backend_internal" {
  name               = "${var.cluster_name}-backend-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets            = module.vpc.private_subnets

  enable_cross_zone_load_balancing = true
}

# 2. Target group apontando para o NodePort do backend nos nós do EKS
resource "aws_lb_target_group" "backend" {
  name        = "${var.cluster_name}-backend-tg"
  port        = var.backend_node_port
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = module.vpc.vpc_id

  deregistration_delay = 30

  health_check {
    protocol            = "TCP"
    port                = "traffic-port"
    interval            = 10
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "backend" {
  load_balancer_arn = aws_lb.backend_internal.arn
  port              = 8080
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Registra automaticamente os nós do node group (inclusive os que o
# autoscaling criar depois) no target group
resource "aws_autoscaling_attachment" "backend_nodes" {
  autoscaling_group_name = module.eks.eks_managed_node_groups_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.backend.arn
}

# Os nós precisam aceitar o NodePort vindo de dentro da VPC
# (health check do NLB e tráfego do VPC Link, que preserva o IP de origem)
resource "aws_vpc_security_group_ingress_rule" "nodes_backend_nodeport" {
  security_group_id = module.eks.node_security_group_id
  description       = "NodePort do backend via NLB interno / API Gateway"
  ip_protocol       = "tcp"
  from_port         = var.backend_node_port
  to_port           = var.backend_node_port
  cidr_ipv4         = var.vpc_cidr
}

# 3. VPC Link: por onde o API Gateway entra na VPC
resource "aws_security_group" "apigw_vpc_link" {
  name        = "${var.cluster_name}-apigw-vpc-link"
  description = "ENIs do VPC Link do API Gateway"
  vpc_id      = module.vpc.vpc_id
}

resource "aws_vpc_security_group_egress_rule" "apigw_vpc_link_to_nlb" {
  security_group_id = aws_security_group.apigw_vpc_link.id
  description       = "VPC Link para o NLB interno do backend"
  ip_protocol       = "tcp"
  from_port         = 8080
  to_port           = 8080
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_apigatewayv2_vpc_link" "backend" {
  name               = "${var.cluster_name}-backend-vpc-link"
  subnet_ids         = module.vpc.private_subnets
  security_group_ids = [aws_security_group.apigw_vpc_link.id]
}

# 4. Integrações + rotas: o backend fica sob o prefixo /kipper
#
#   https://<api>/kipper/api/products  ->  backend: /api/products
#   https://<api>/kipper               ->  backend: /
#
# O backend não usa o prefixo /kipper, então a integração reescreve o caminho
# (overwrite:path) removendo o prefixo antes de encaminhar.

# Para /kipper/{proxy+}: encaminha só o que vem depois de /kipper
resource "aws_apigatewayv2_integration" "backend" {
  api_id                 = data.aws_apigatewayv2_api.backend.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.backend.id
  integration_uri        = aws_lb_listener.backend.arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = merge(local.backend_forward_headers, {
    "overwrite:path" = "/$request.path.proxy"
  })
}

# Para /kipper exato: encaminha para a raiz do backend
resource "aws_apigatewayv2_integration" "backend_root" {
  api_id                 = data.aws_apigatewayv2_api.backend.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.backend.id
  integration_uri        = aws_lb_listener.backend.arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = merge(local.backend_forward_headers, {
    "overwrite:path" = "/"
  })
}

# Rota "ANY /kipper": se ela já tiver sido criada pelo console, informe o ID em
# api_gateway_kipper_route_id para o Terraform importá-la e ligá-la à integração.
# Só importa se o ID for informado. Após um destroy a rota deixa de existir;
# deixe a variável vazia ("") e o Terraform a cria do zero.
import {
  for_each = var.api_gateway_kipper_route_id == "" ? toset([]) : toset([var.api_gateway_kipper_route_id])
  to       = aws_apigatewayv2_route.backend_kipper
  id       = "${var.api_gateway_id}/${each.value}"
}

resource "aws_apigatewayv2_route" "backend_kipper" {
  api_id    = data.aws_apigatewayv2_api.backend.id
  route_key = "ANY /kipper"
  target    = "integrations/${aws_apigatewayv2_integration.backend_root.id}"
}

# Todos os caminhos abaixo de /kipper (inclusive OPTIONS do CORS, que
# continua sendo respondido pelo Spring)
resource "aws_apigatewayv2_route" "backend_proxy" {
  api_id    = data.aws_apigatewayv2_api.backend.id
  route_key = "ANY /kipper/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.backend.id}"
}

locals {
  backend_base_path = "/kipper"

  # URL pública do backend (com o prefixo /kipper)
  backend_public_url = "${data.aws_apigatewayv2_api.backend.api_endpoint}${local.backend_base_path}"

  # Cabeçalhos que contam ao Spring como é a URL pública, para ele gerar links
  # corretos (Swagger, redirects do OAuth2):
  # - X-Forwarded-Prefix: o caminho removido (/kipper), lido pelo
  #   ForwardedHeaderFilter (SERVER_FORWARD_HEADERS_STRATEGY=framework)
  # - X-Kipper-Proto: o esquema https. O API Gateway não deixa sobrescrever o
  #   X-Forwarded-Proto (cabeçalho reservado), então usamos um nome próprio,
  #   lido pelo Tomcat (SERVER_TOMCAT_REMOTEIP_PROTOCOL_HEADER no configmap)
  backend_forward_headers = {
    "overwrite:header.X-Forwarded-Prefix" = local.backend_base_path
    "overwrite:header.X-Kipper-Proto"    = "https"
  }
}
