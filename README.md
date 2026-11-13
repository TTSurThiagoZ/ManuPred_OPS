# ManuPred_OPS


# kipper — Terraform EKS (AWS)

Versão AWS do ambiente em [`../terraform`](../terraform) (Minikube). O Terraform cria
a infraestrutura (VPC, EKS, RDS) e, como no projeto anterior, chama **scripts bash**
que aplicam **manifestos YAML** com `kubectl` — tudo com um único `terraform apply`.

## O que muda em relação ao Minikube

| Minikube (`terraform/`)                          | AWS (`terraform-eks/`)                                    |
|--------------------------------------------------|-----------------------------------------------------------|
| `minikube_cluster`                               | VPC + EKS com node group gerenciado (`vpc.tf`, `eks.tf`)  |
| `cpus` / `memory` / `nodes`                      | `node_instance_types` / `node_desired_size`               |
| CNI flannel                                      | Addon `vpc-cni`                                           |
| Addon `metrics-server`                           | Helm release `metrics-server`                             |
| MySQL na máquina (`host.minikube.internal:3310`) | RDS MySQL 8.4 em subnet privada (`rds.tf`)                |
| `minikube -p <cluster> kubectl --`               | `kubectl` com kubeconfig do `aws eks update-kubeconfig`   |
| `deploy.sh` + `envsubst` + YAMLs                 | `scripts/*.sh` + `envsubst` + YAMLs (mesmo modelo)        |
| `port-forward` 8080 / 3000                       | API Gateway → VPC Link → NLB interno → `NodePort`         |
| `taskkill kubectl` no destroy                    | `namespace.sh delete` (remove os Load Balancers)          |

## Estrutura

```
terraform-eks/
├── providers.tf          # aws, helm, random, null, local
├── variables.tf
├── vpc.tf                # VPC, subnets públicas/privadas, NAT
├── eks.tf                # EKS, node group, addons, metrics-server
├── rds.tf                # RDS MySQL, security group, senha
├── apigateway.tf         # VPC Link, NLB interno e rotas /kipper do backend
├── apigateway-frontend.tf # rotas /kipper do frontend (mesmo NLB/VPC Link)
├── k8s-deploy.tf         # null_resource que chamam os scripts
├── outputs.tf
└── scripts/
    ├── common.sh         # kubeconfig, função k(), espera de Load Balancer
    ├── namespace.sh      # apply | delete do namespace
    ├── deploy-frontend.sh
    ├── deploy-backend.sh
    └── k8s/
        ├── namespace.yaml
        ├── backend/{configmap,secret,deployment}.yaml
        └── frontend/deployment.yaml
```

Ordem do deploy: `namespace` → `frontend` → `backend` (o backend usa a URL do
frontend no redirect do OAuth2).

## API Gateway

Backend e frontend não têm mais Load Balancer público. A entrada é pelos HTTP APIs
que já existem (`api_gateway_id` e `frontend_api_gateway_id`), sob o prefixo `/kipper`:

- Backend: `https://<api-backend>/kipper/...` → backend recebe o caminho sem `/kipper`
- Frontend: `https://<api-frontend>/kipper/...` → nginx recebe o caminho sem `/kipper`

As URLs aparecem nos outputs `backend_api_url` e `frontend_url`. A imagem do frontend
precisa ser buildada com `PUBLIC_URL=/kipper` e `REACT_APP_API_URL=<backend_api_url>`.

Se a rota `ANY /kipper` já tiver sido criada pelo console, informe o ID dela em
`api_gateway_kipper_route_id` / `frontend_api_gateway_kipper_route_id` para o Terraform
importá-la; vazio (padrão) = o Terraform cria a rota. Depois de um `destroy`, volte
para vazio.

## Pré-requisitos

- Terraform >= 1.5
- **AWS CLI v2** (os scripts usam `aws eks update-kubeconfig`)
- `kubectl`
- Git Bash no Windows (com `envsubst`, `base64`, `sha256sum` — já vêm no Git for Windows).
  No Linux/Mac use `bash_path = "bash"` no tfvars.
- Credenciais AWS configuradas (`AWS_PROFILE` ou `AWS_ACCESS_KEY_ID`/`AWS_SECRET_ACCESS_KEY`)
  — **as mesmas** para o Terraform e o AWS CLI, pois só quem criou o cluster é admin dele.
- `serviceAccountKey.json` do Firebase nesta pasta

## Como usar

```bash
cd terraform-eks
cp terraform.tfvars.example terraform.tfvars   # ajuste os valores
terraform init
terraform plan -out tfplan.out
terraform apply tfplan.out                       # ~15–20 min (EKS + RDS)
```

As URLs do backend e do frontend aparecem no final do log do `apply`. Depois:

```bash
kubectl --kubeconfig .kube/config -n kipper get pods,svc,hpa
```

### Redeploy

Os scripts rodam de novo automaticamente quando muda um YAML, um script, a imagem,
o banco ou um segredo. Para forçar (ex.: nova imagem `:latest` no Docker Hub):

```bash
terraform apply -replace=null_resource.k8s_backend_deploy
terraform apply -replace=null_resource.k8s_frontend_deploy
```

### Frontend apontando para o backend na AWS

O React embute `REACT_APP_*` na imagem no `docker build`. O `deploy-backend.sh`
imprime ao final o comando de build com `REACT_APP_API_URL` já preenchido
(adicione também os `--build-arg REACT_APP_FIREBASE_*`). Depois do push:

```bash
kubectl --kubeconfig .kube/config -n kipper rollout restart deployment/frontend-deployment
```

> Se usar login com Google, cadastre `<url-do-frontend>/oauth2/redirect` no console
> do Google e informe `google_client_id`/`google_client_secret` no tfvars.

## Segredos

- A senha do RDS é gerada pelo Terraform (`terraform output -raw db_password`).
- O Terraform grava os segredos em base64 em `.deploy-secrets.env` (ignorado pelo git),
  que o `deploy-backend.sh` lê — assim o log do `local-exec` não fica oculto.
- Google OAuth / JWT vão para o Secret `backend-optional-secret`, criado só com as
  chaves informadas.

## Custos (estimativa us-east-1)

| Recurso                  | ~US$/hora |
|--------------------------|-----------|
| Control plane EKS        | 0,10      |
| 2× t3.medium             | 0,08      |
| NAT Gateway              | 0,045 + tráfego |
| RDS db.t4g.micro         | 0,016     |
| 2× Classic Load Balancer | 0,05      |
| **Total**                | **~0,30/h (~US$ 220/mês ligado 24h)** |

Para o TCC: `apply` → demonstrar → `destroy`.

## Destruir tudo

```bash
terraform destroy
```

O `namespace.sh delete` roda primeiro e apaga os Load Balancers criados pelo
Kubernetes (senão a VPC não pode ser removida). O RDS está com
`skip_final_snapshot = true` — **os dados do banco são apagados**.
