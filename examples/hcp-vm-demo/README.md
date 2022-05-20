# hcp-vm-demo

This example creates all of the Azure and HCP resources necessary for connecting a HCP Consul cluster to a Consul client on Azure VM.

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

**Warning**: This instance, by default, is publicly accessible on port 8080 and 8081, make sure to delete it when done.

#### HashiCups

The web app is accessible at the `hashicups_url` output. Note: it takes several minutes for all dependencies and images to download and start.

#### HCP Consul

The HCP Consul cluster's UI can be accessed via the outputs `consul_url` and `consul_root_token`.

#### Nomad

This example is running on nomad, which can be accessed via the outputs `nomad_url` with the username `nomad` and `consul_root_token`.

#### VM instances

To SSH to the VM/Consul client, write the private key to a file and use it to SSH:

```bash
pem=~/.ssh/hashicups.pem
tf output -raw private_key_openssh > $pem
chmod 400 $pem
ssh -i $pem adminuser@$(tf output -raw vm_client_public_ip)
```
