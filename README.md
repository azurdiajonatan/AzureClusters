# AKS Project — Deploy a Kubernetes Cluster on Azure with Terraform

This project provisions an Azure Kubernetes Service (AKS) cluster using Terraform and deploys a custom web app into it. The whole thing — from zero to a live website running in the cloud — takes about 15 minutes once you have the prerequisites in place.

The app itself is a simple nginx container serving a custom HTML page. Nothing fancy, but it proves the point: infrastructure as code works, and once you have the cluster up you can swap in any containerized app you want.

---

## What gets built

- A **Resource Group** in Azure to hold everything together
- An **AKS cluster** with 1 node (Standard_D2s_v7, eastus region)
- A **Kubernetes Deployment** running 2 nginx pods
- A **ConfigMap** that injects a custom HTML page into those pods
- A **LoadBalancer Service** that exposes the app to the internet with a public IP

---

## Prerequisites

You need four tools installed before anything else:

```bash
az --version        # Azure CLI
terraform --version # Terraform
kubectl version --client # Kubernetes CLI
git --version       # Git
```

If any of those aren't installed yet:
- [Azure CLI](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli)
- [Terraform](https://developer.hashicorp.com/terraform/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Git](https://git-scm.com/downloads)

You also need an **Azure account** with active credit. The free tier ($200 new account credit or $100 Azure for Students) is more than enough to run this project.

---

## Project structure

```
aks-project/
├── README.md
├── checklist.md
├── .gitignore
├── terraform/
│   ├── main.tf          # core infrastructure definition
│   ├── variables.tf     # all configurable parameters
│   └── outputs.tf       # values shown after apply
└── manifests/
    ├── configmap.yaml   # custom HTML page
    ├── deployment.yaml  # nginx pods configuration
    └── service.yaml     # LoadBalancer service
```

---

## Step 1 — Log in to Azure

First thing, authenticate with your Azure account:

```bash
az login
```

This opens the browser and asks you to sign in. Once done, verify it worked:

```bash
az account show
```

You should see your subscription name, `"state": "Enabled"` and `"isDefault": true`. If you have multiple subscriptions, set the right one:

```bash
az account set --subscription "<your-subscription-name-or-id>"
```

---

## Step 2 — Create the Resource Group

The Resource Group is the container in Azure where all the project resources will live. Create it before anything else since the service principal (next step) needs it as a scope:

```bash
az group create --name rg-aks-project-test --location eastus
```

You should get back a JSON object with `"provisioningState": "Succeeded"`. That means the RG is ready.

> **Why eastus?** Good availability of VM sizes and well-documented for AKS projects. Feel free to change it in `variables.tf` if you prefer a different region — just make sure to create the RG in that same region.

---

## Step 3 — Create the Service Principal

Terraform needs an identity to authenticate with Azure. Instead of using your personal account, you create a **service principal** — think of it as a dedicated app account with limited permissions.

The key part here is the **scope**: we limit it to just the Resource Group, not the entire subscription. That way if the credentials ever get leaked, the damage is contained.

```bash
az ad sp create-for-rbac \
  --name "sp-aks-terraform" \
  --role "Contributor" \
  --scopes "/subscriptions/<your-subscription-id>/resourceGroups/rg-aks-project-test"
```

> **Find your subscription ID:** `az account show --query id -o tsv`

This returns a JSON like:

```json
{
  "appId": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "displayName": "sp-aks-terraform",
  "password": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx",
  "tenant": "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
}
```

**Save this output somewhere safe** — the `password` is only shown once and cannot be retrieved later.

---

## Step 4 — Generate SSH Keys

AKS node pools require an SSH public key in their configuration. Generate a dedicated key pair for this project:

```bash
ssh-keygen -t rsa -b 4096 -f "$HOME/.ssh/aks_project_key" -C "aks-project"
```

Press Enter twice when asked for a passphrase (leave it empty for simplicity).

This creates two files:
- `~/.ssh/aks_project_key` — private key, never share this or commit it to Git
- `~/.ssh/aks_project_key.pub` — public key, referenced by Terraform in `variables.tf`

---

## Step 5 — Set Environment Variables

Terraform reads the service principal credentials from environment variables automatically. Set them in your terminal session using the values from Step 3:

**On Mac/Linux:**
```bash
export ARM_CLIENT_ID="<appId>"
export ARM_CLIENT_SECRET="<password>"
export ARM_TENANT_ID="<tenant>"
export ARM_SUBSCRIPTION_ID="<your-subscription-id>"
```

**On Windows (PowerShell):**
```powershell
$env:ARM_CLIENT_ID="<appId>"
$env:ARM_CLIENT_SECRET="<password>"
$env:ARM_TENANT_ID="<tenant>"
$env:ARM_SUBSCRIPTION_ID="<your-subscription-id>"
```

Verify they are set:
```bash
echo $ARM_CLIENT_ID        # Mac/Linux
echo $env:ARM_CLIENT_ID    # Windows PowerShell
```

> **Heads up:** these variables only live for the current terminal session. If you close the terminal and come back later, you will need to set them again before running any Terraform commands.

---

## Step 6 — Run Terraform

Navigate to the terraform folder and initialize the project:

```bash
cd aks-project/terraform
terraform init
```

This downloads the Azure provider. You should see `Terraform has been successfully initialized!` at the end.

Run a plan to preview what will be created — nothing happens in Azure yet:

```bash
terraform plan
```

You should see `Plan: 1 to add, 0 to change, 0 to destroy.` If anything looks off, this is the time to fix it before spending any cloud credit.

When you are ready, apply it:

```bash
terraform apply
```

Type `yes` when prompted. The cluster takes **4 to 10 minutes** to come up — Azure is provisioning the control plane, node pool, and virtual network in the background.

When it finishes you will see:

```
Apply complete! Resources: 1 added, 0 changed, 0 destroyed.

Outputs:
cluster_name   = "aks-cluster-project-test"
location       = "eastus"
resource_group = "rg-aks-project-test"
kube_config    = <sensitive>
```

---

## Step 7 — Connect kubectl to the cluster

Download the cluster credentials and merge them into your local kubectl config:

```bash
az aks get-credentials \
  --resource-group rg-aks-project-test \
  --name aks-cluster-project-test
```

Verify the cluster is responding:

```bash
kubectl get nodes
```

You should see your node listed with `STATUS: Ready`. That means the cluster is up and ready to receive workloads.

---

## Step 8 — Deploy the application

Navigate to the manifests folder and apply all three files in order:

```bash
cd ../manifests

kubectl apply -f configmap.yaml
kubectl apply -f deployment.yaml
kubectl apply -f service.yaml
```

The ConfigMap holds the custom HTML page. The Deployment creates 2 nginx pods and mounts that HTML into them. The Service creates an Azure Load Balancer with a public IP.

Watch the service until the external IP appears:

```bash
kubectl get svc -w
```

The `EXTERNAL-IP` column will show `<pending>` at first — Azure is provisioning the load balancer. In about 1 to 2 minutes a real IP address shows up. Once it does, open it in your browser:

```
http://<external-ip>
```

You should see the custom project page. The app is live.

---

## Tearing it down

**Always destroy the cluster when you are done working for the day.** A running AKS node burns cloud credit even when you are not using it.

```bash
cd aks-project/terraform
terraform destroy
```

Type `yes` when prompted. This destroys the AKS cluster and everything Terraform created inside the Resource Group. Your local code, the `.tf` files, the manifests, and the SSH keys are untouched.

> **The Resource Group itself is not destroyed** since it was created manually with `az group create`, not by Terraform. If you want to clean that up too: `az group delete --name rg-aks-project-test --yes`

---

## Coming back after a destroy

The whole point of infrastructure as code is that recreating everything takes minutes. Next session:

1. Set the environment variables again (Step 5)
2. Run `terraform apply` from the terraform folder
3. Run `az aks get-credentials` once the cluster is up
4. Run `kubectl apply -f` for the three manifests
5. Wait for the external IP and open the browser

That's it — same cluster, same config, back in about 5 minutes.

---

## Known issues

**403 Forbidden on terraform plan**
Terraform tries to register all Azure Resource Providers automatically at the subscription level, but the service principal only has permissions on the Resource Group. The fix is already applied in `main.tf` via `skip_provider_registration = true`. If you hit this anyway, manually register the needed providers:

```bash
az provider register --namespace Microsoft.ContainerService
az provider register --namespace Microsoft.Network
az provider register --namespace Microsoft.Compute
az provider register --namespace Microsoft.Storage
```

**VM size not available**
Free and student Azure subscriptions have quota restrictions per region. If the apply fails saying `Standard_D2s_v7 is not allowed`, check the error message — Azure returns the full list of available sizes. Update `vm_size` in `variables.tf` to one from that list and run `terraform apply` again.

**Environment variables not set**
If Terraform returns an authentication error, your environment variables probably got cleared when you closed the terminal. Set them again from Step 5 and retry.

---

## What would change in production

This setup is intentionally minimal — it is designed to work cleanly and stay within free tier limits. A real production environment would add:

- **Remote Terraform state** stored in an Azure Storage Account with locking, so the whole team shares one source of truth
- **Managed Identity** instead of a service principal, which removes the need to manage credentials entirely
- **Multi-zone node pool** with at least 3 nodes spread across availability zones for high availability
- **Network policies and RBAC** to control what pods can talk to what, and who can do what in the cluster
- **Azure Monitor and Container Insights** for centralized metrics and logs

Each of these adds reliability but also cost. A production-grade setup can easily run $300–500/month depending on the configuration — which is why the minimum viable setup used here is the right call for a learning project.

---

## Useful commands

```bash
# Check cluster status
kubectl get nodes
kubectl get pods
kubectl get svc

# Force pod restart after updating the ConfigMap
kubectl rollout restart deployment nginx-deployment

# Check what Terraform manages
terraform show

# Destroy everything
terraform destroy
```