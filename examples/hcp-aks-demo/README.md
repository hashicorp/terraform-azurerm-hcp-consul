# hcp-aks-demo

This Terraform example stands up a full deployment of a HCP Consul cluster connected to an Azure AKS cluster.

### Prerequisites

1. Create a HCP Service Key and set the required environment variables

```
export HCP_CLIENT_ID=...
export HCP_CLIENT_SECRET=...
```

2. Log into Azure via the Azure CLI, and set the correct subscription. More details can be found on the [Azure Terraform provider documentation](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/azure_cli).

```
az login
az account set --subscription="SUBSCRIPTION_ID"
```

The user must be assigned a [role granting authorization to create Service Principals](https://docs.microsoft.com/en-us/graph/api/serviceprincipal-post-serviceprincipals?view=graph-rest-1.0&tabs=http#permissions). For example: `Cloud Application Administrator` or `Application Administrator`.

### Deployment

1. Initialize and apply the Terraform configuration

```
terraform init && terraform apply
```

### Accessing the Deployment

#### HashiCups

The web app is accessible from the output `hashicups_url`:

```bash
open $(terraform output -raw hashicups_url)
```

#### HCP Consul

The HCP Consul cluster's UI can be accessed via the outputs `consul_url` and `consul_root_token`:

```bash
echo "token: $(terraform output -raw consul_root_token)"
open $(terraform output -raw consul_url)
```

#### AKS Cluster

The AKS cluster can be accessed via `kubectl` and the config in the `kube_config_raw` output. For example:

```bash
conf=~/hashicups_cluster.conf
terraform output -raw kube_config_raw > $conf
export KUBECONFIG=$conf

kubectl get pods
```
