# --------------------------------------------------
# API GATEWAY (HTTP API já existente) -> FRONTEND NO EKS
#
# Mesmo caminho do backend (ver apigateway.tf), reaproveitando o VPC Link e o
# NLB interno, com um listener próprio na porta 80:
#   Cliente -> API Gateway do frontend (stage $default, prefixo /kipper)
#           -> VPC Link -> NLB interno :80
#           -> NodePort do frontend-service nos nós do EKS
#           -> pods do frontend (nginx) :80
#
# A imagem do frontend precisa ser buildada com PUBLIC_URL=/kipper para que o
# React gere links de assets e rotas com o prefixo (ver kipper-frontend).
# --------------------------------------------------

data "aws_apigatewayv2_api" "frontend" {
  api_id = var.frontend_api_gateway_id
}

# 1. Target group + listener :80 no NLB interno
resource "aws_lb_target_group" "frontend" {
  name        = "${var.cluster_name}-frontend-tg"
  port        = var.frontend_node_port
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

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.backend_internal.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_autoscaling_attachment" "frontend_nodes" {
  autoscaling_group_name = module.eks.eks_managed_node_groups_autoscaling_group_names[0]
  lb_target_group_arn    = aws_lb_target_group.frontend.arn
}

resource "aws_vpc_security_group_ingress_rule" "nodes_frontend_nodeport" {
  security_group_id = module.eks.node_security_group_id
  description       = "NodePort do frontend via NLB interno / API Gateway"
  ip_protocol       = "tcp"
  from_port         = var.frontend_node_port
  to_port           = var.frontend_node_port
  cidr_ipv4         = var.vpc_cidr
}

resource "aws_vpc_security_group_egress_rule" "apigw_vpc_link_to_nlb_frontend" {
  security_group_id = aws_security_group.apigw_vpc_link.id
  description       = "VPC Link para o NLB interno do frontend"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = var.vpc_cidr
}

# 2. Integrações: remove o prefixo /kipper antes de chegar ao nginx
#   https://<api>/kipper/static/js/main.js -> nginx: /static/js/main.js
#   https://<api>/kipper                   -> nginx: /
resource "aws_apigatewayv2_integration" "frontend" {
  api_id                 = data.aws_apigatewayv2_api.frontend.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.backend.id
  integration_uri        = aws_lb_listener.frontend.arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = {
    "overwrite:path" = "/$request.path.proxy"
  }
}

resource "aws_apigatewayv2_integration" "frontend_root" {
  api_id                 = data.aws_apigatewayv2_api.frontend.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.backend.id
  integration_uri        = aws_lb_listener.frontend.arn
  payload_format_version = "1.0"
  timeout_milliseconds   = 30000

  request_parameters = {
    "overwrite:path" = "/"
  }
}

# 3. Rotas: "ANY /kipper" + subcaminhos
# Só importa se o ID for informado (vazio = Terraform cria a rota)
import {
  for_each = var.frontend_api_gateway_kipper_route_id == "" ? toset([]) : toset([var.frontend_api_gateway_kipper_route_id])
  to       = aws_apigatewayv2_route.frontend_kipper
  id       = "${var.frontend_api_gateway_id}/${each.value}"
}

resource "aws_apigatewayv2_route" "frontend_kipper" {
  api_id    = data.aws_apigatewayv2_api.frontend.id
  route_key = "ANY /kipper"
  target    = "integrations/${aws_apigatewayv2_integration.frontend_root.id}"
}

resource "aws_apigatewayv2_route" "frontend_proxy" {
  api_id    = data.aws_apigatewayv2_api.frontend.id
  route_key = "ANY /kipper/{proxy+}"
  target    = "integrations/${aws_apigatewayv2_integration.frontend.id}"
}

locals {
  frontend_base_path = "/kipper"

  # URL pública do frontend (com o prefixo /kipper)
  frontend_public_url = "${data.aws_apigatewayv2_api.frontend.api_endpoint}${local.frontend_base_path}"

  # Redirect do OAuth2 após o login: o informado no tfvars ou a página do frontend
  frontend_oauth2_redirect_uri = coalesce(var.frontend_oauth2_redirect_uri, "${local.frontend_public_url}/oauth2/redirect")
}
