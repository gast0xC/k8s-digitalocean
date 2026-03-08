# k8s-digitalocean

Production-ready Kubernetes infrastructure on DigitalOcean, provisioned with Terraform.

## Live Services

| Service | URL | Description |
|---|---|---|
| Grafana | https://grafana.gast-k8s.me | Metrics & dashboards (Prometheus) |
| Headlamp | https://dashboard.gast-k8s.me | Kubernetes web UI |

---

## Architecture

```
Internet
   │
   ▼
DigitalOcean Load Balancer (public IP: 143.244.221.228)
   │   Automatically provisioned when nginx requests a LoadBalancer Service
   │
   ▼
nginx Ingress Controller (pod inside k8s)
   │   Routes based on hostname:
   │   grafana.gast-k8s.me   → Grafana Service
   │   dashboard.gast-k8s.me → Headlamp Service
   │
   ▼
Your application pods
```

**TLS flow:**
```
nginx receives HTTPS request
  → uses TLS cert stored in a k8s Secret
  → cert was issued by Let's Encrypt via cert-manager
  → cert-manager auto-renews 30 days before expiry
```

---

## Project Structure

```
k8s/
├── versions.tf       # Terraform version + required providers
├── providers.tf      # Provider configuration (credentials) — root only
├── variables.tf      # Input variables
├── outputs.tf        # Outputs (URLs, IP, cluster name)
├── main.tf           # Module wiring — the "table of contents"
└── modules/
    ├── cluster/      # DigitalOcean Kubernetes cluster + node pool
    ├── ingress/      # nginx ingress controller + DigitalOcean DNS domain
    ├── cert-manager/ # cert-manager + Let's Encrypt ClusterIssuer
    ├── monitoring/   # kube-prometheus-stack (Prometheus + Grafana + Alertmanager)
    └── dashboard/    # Headlamp Kubernetes UI
```

**Provider architecture:** Provider *configuration* (credentials, endpoints) lives only in `providers.tf` at the root. Child modules declare `required_providers` only to specify the registry source for non-HashiCorp providers — no credentials, no duplication.

---

## Prerequisites

- [Terraform](https://developer.hashicorp.com/terraform/install) >= 1.5
- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [doctl](https://docs.digitalocean.com/reference/doctl/how-to/install/) (DigitalOcean CLI)
- A DigitalOcean account with API token
- PostgreSQL running for Terraform state backend:
  ```bash
  cd ~/dev/proj1 && docker compose up -d
  ```

---

## Quick Start

```bash
# 1. Set environment variables
source ../.env   # sets TF_VAR_do_token, PG_CONN_STR, TF_VAR_letsencrypt_email

# 2. Initialize
terraform init

# 3. Preview changes
terraform plan

# 4. Apply
terraform apply

# 5. See outputs
terraform output
```

**Configure kubectl:**
```bash
doctl kubernetes cluster kubeconfig save <cluster-id> --access-token $TF_VAR_do_token
kubectl get nodes
```

---

## Kubernetes Fundamentals

### What is Kubernetes?

Kubernetes (k8s) is a container orchestration platform. It answers the question: *"I have Docker containers — how do I run them reliably at scale?"*

Key things Kubernetes handles:
- **Scheduling** — decides which node (server) runs each container
- **Self-healing** — restarts crashed containers, replaces failed nodes
- **Scaling** — adds/removes container instances based on load
- **Networking** — gives each container a stable internal address
- **Rolling updates** — deploy new versions with zero downtime

### Control Plane vs Worker Nodes

```
Control Plane (managed by DigitalOcean)    Worker Nodes (your node pool)
┌──────────────────────────────────┐       ┌──────────────────┐
│  API Server   ← kubectl talks here│       │  kubelet         │
│  etcd         (stores all state)  │◄─────►│  container runtime│
│  Scheduler    (places pods)       │       │  your pods       │
│  Controller   (maintains state)   │       └──────────────────┘
└──────────────────────────────────┘
```

With DOKS (DigitalOcean Kubernetes Service), the control plane is managed for you — you only pay for and manage the worker nodes.

### Core Objects

#### Pod
The smallest deployable unit. A pod runs one or more containers that share network and storage.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: my-app
spec:
  containers:
    - name: app
      image: nginx:latest
      ports:
        - containerPort: 80
```

Pods are **ephemeral** — they die and get replaced. Never rely on a pod's IP or name being stable.

#### Deployment
Manages a set of identical pods. Ensures a specified number of replicas are always running. Handles rolling updates.

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  replicas: 3          # always keep 3 pods running
  selector:
    matchLabels:
      app: my-app
  template:            # pod template
    spec:
      containers:
        - name: app
          image: nginx:1.25
```

#### Service
A stable network endpoint for a set of pods. Pods come and go, but the Service IP stays constant.

```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-app
spec:
  selector:
    app: my-app        # routes to pods with this label
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP      # internal only (use LoadBalancer for external)
```

Types:
- `ClusterIP` — internal cluster only (default)
- `NodePort` — exposes on each node's IP at a static port
- `LoadBalancer` — provisions a cloud load balancer (what nginx ingress uses)

#### Ingress
HTTP routing rules. Maps hostnames/paths to Services. Requires an Ingress Controller (nginx) to actually process the rules.

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
spec:
  rules:
    - host: myapp.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: my-app
                port:
                  number: 80
  tls:
    - hosts:
        - myapp.example.com
      secretName: myapp-tls
```

#### Namespace
Virtual cluster within a cluster. Isolates resources by team/environment/project.

```bash
kubectl get pods -n monitoring      # pods in the monitoring namespace
kubectl get pods --all-namespaces   # pods everywhere
```

#### ConfigMap & Secret
Store configuration outside of container images.

```bash
# ConfigMap — non-sensitive config
kubectl create configmap app-config --from-literal=ENV=production

# Secret — sensitive data (base64 encoded in etcd)
kubectl create secret generic db-creds \
  --from-literal=password=supersecret
```

#### PersistentVolume & PersistentVolumeClaim
Storage that outlives a pod. Like a virtual hard drive attached to your pod.

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: my-data
spec:
  accessModes: [ReadWriteOnce]
  resources:
    requests:
      storage: 10Gi
```

---

## What Each Component Does

### nginx Ingress Controller
A reverse proxy that runs as a pod and processes Ingress resources. When you create an Ingress, nginx automatically updates its config and starts routing traffic. It also handles TLS termination.

### cert-manager
Watches for Ingress resources with the `cert-manager.io/cluster-issuer` annotation. Automatically requests TLS certificates from Let's Encrypt, stores them in Kubernetes Secrets, and renews them before expiry.

### kube-prometheus-stack
- **Prometheus** — scrapes metrics from all pods every 15 seconds using `/metrics` endpoints. Stores time-series data. Query with PromQL.
- **Grafana** — visualises Prometheus data. Ships with pre-built k8s dashboards.
- **Alertmanager** — sends alerts (Slack, email, PagerDuty) when Prometheus rules trigger.
- **kube-state-metrics** — translates k8s object state into Prometheus metrics (pod restarts, deployment health, etc.)
- **node-exporter** — exposes CPU, RAM, disk metrics per node.

### Headlamp
Web UI for Kubernetes. Lets you browse pods, view logs, inspect deployments, check events — all from a browser. Requires a service account token for authentication.

---

## Useful kubectl Commands

```bash
# Cluster overview
kubectl get nodes
kubectl get pods --all-namespaces
kubectl top nodes          # CPU/RAM per node (requires metrics-server)
kubectl top pods -n monitoring

# Inspect a resource
kubectl describe pod <name> -n <namespace>
kubectl describe ingress -n headlamp

# Logs
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> -f     # follow (like tail -f)
kubectl logs <pod-name> -n <namespace> --previous  # crashed pod logs

# Execute into a pod (like docker exec)
kubectl exec -it <pod-name> -n <namespace> -- /bin/sh

# Port forward (access a service locally without ingress)
kubectl port-forward svc/grafana 3000:80 -n monitoring
# Then open http://localhost:3000

# Check TLS certificates
kubectl get certificate -A
kubectl describe certificate grafana-tls -n monitoring

# Watch resources change in real time
kubectl get pods -n monitoring -w

# Get events (useful for debugging)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

---

## Environment Variables

Store these in `~/dev/proj1/.env` (never commit this file):

```bash
export TF_VAR_do_token=<your-digitalocean-token>
export TF_VAR_letsencrypt_email=<your-email>
export PG_CONN_STR=postgres://terraform:password@localhost:5432/terraform_backend?sslmode=disable
```

---

## Terraform State

State is stored in a PostgreSQL database (remote backend). This means:
- Multiple people can collaborate safely (state is not local)
- State is not lost if your laptop dies
- Terraform locks the state during operations to prevent conflicts

```bash
# If you need to inspect or manipulate state directly:
terraform state list                    # all resources in state
terraform state show <resource>         # details of one resource
terraform state mv <old> <new>          # move/rename a resource
terraform import <resource> <id>        # import existing resource into state
```
