
# ☁️ Cloud Project – Scalable Full-Stack Web Application Deployment on OpenStack with Terraform

## Team Structure

| Name | Matikulation Number | Files | Description |
|------|------|------|------|
| Subham Gaurav | 1564925 | user_data.app.sh.tpl | App-VM user-data template: provisions Node 18 + deps, clones repo, exports DB/JWT/API env vars, then builds the Node API (port 8000) and React UI, logs to /opt/app/*.log. The “.tpl” layer injects live IPs at deploy time, removes hard-coded addresses. |
| Udit Parihar | 1545786 | user_data.db.sh | Wrote DB-node bootstrap script: installs & enables MariaDB, opens remote access, creates registrysystem DB; defines users, patient, medical & survey tables; seeds admin account for initial login. |
| Pritpal Singh | 1563366 | main.tf | Set up Terraform foundation: variables/locals, OpenStack provider auth, keypair handling, VPC network + subnet + router attach, security groups (SSH/HTTP/API), ports, 2 scalable app instances + DB instance, frontend floating IP + outputs. | 
| Muhammad Hamza Butt | 1490406 | main.tf  | Added a new load balancer in front of the API: it listens on HTTP port 8000, shares requests evenly across the app servers, checks each one’s health by calling /api/health, sits behind its own floating IP, and have updated the startup scripts so all API traffic now flows through it. |

---

## 🚀 Project Overview
This project deploys a scalable full-stack web application on OpenStack using Terraform for Infrastructure as Code (IaC). It provisions:

- A **React frontend** (port 3000)
- A **Node.js + Express backend** (port 8000)
- A **MariaDB database** (port 3306)
- An **OpenStack Load Balancer (LBaaS)** to distribute traffic across backend nodes

Everything is automated with cloud-init (via Terraform user_data), and all components are configured with environment variables and GitHub-based source retrieval.

---

## ⚙️ Technologies Used

| Category           | Technology                               |
|--------------------|-------------------------------------------|
| IaC                | Terraform                                 |
| Cloud Provider     | OpenStack (Nova, Neutron, LBaaS)          |
| Backend            | Node.js + Express, REST API + JWT         |
| Frontend           | React.js                                  |
| Database           | MariaDB, auto-initialized with schema     |
| Automation         | user_data.db.sh, user_data.app.sh.tpl scripts      |
| Source Deployment  | GitHub (using personal access token)      |

---

## 📦 Deployment Instructions

1. Unzip the project directory.
2. Open a terminal and navigate into the Terraform directory.
3. Run the following:

```bash
terraform init
terraform apply
```
> ℹ️ **Note:** Must be connected to University's VPN.

4. Confirm to apply. This will provision:
    - N app servers (React + Node.js)
    - 1 MariaDB server
    - 1 load balancer with a floating IP
    - All relevant security groups and IP assignments
    - This will deploy a full fledged application in upto 5 minutes.

---

## 🛠️ Configuration & Secrets

Before running `terraform apply`, you **must** configure several environment-specific variables and replace hardcoded secrets in the codebase. 

### 1. Terraform Variables (`main.tf` & `terraform.tfvars`)
Create a file named `terraform.tfvars` (this file is ignored by `.gitignore`) and provide your GitHub Personal Access Token (used for cloning the repository):

```hcl
github_token = "your-github-personal-access-token"
```

In `main.tf`, you should update the `locals` block with your specific OpenStack credentials and network configuration:
* `auth_url`: Your OpenStack identity endpoint.
* `user_name` & `user_password`: Your OpenStack credentials.
* `tenant_name`: Your OpenStack project/tenant name.
* `floating_net`: The name of the external network providing floating IPs (e.g., `ext_net`).
* `dns_nameservers`: Add your network's DNS nameservers.

### 2. Database & Application Secrets
Currently, some secrets are hardcoded in the baseline provisioning scripts. **For a production environment, you should extract these into Terraform variables.** If you are running this as-is, be aware of the following hardcoded values:

* **MariaDB Password:** Hardcoded in `userdata-db.sh` (Line 19) and `userdata-app.sh.tpl` (Line 30). Change `'abcd@1234'` to a secure password.
* **JWT Secret:** Hardcoded in `userdata-app.sh.tpl` (Line 32). Change `supersecretrandomstring42` to a secure random string for JWT signing.
* **Admin Login:** The initial application administrator login is seeded in `userdata-db.sh` (Lines 197-204) as `administrator@hs-fulda.de` / `Password1234`.

---

## 🌐 Accessing the Application

| Component          | URL / Command                                   | Notes                                     |
|--------------------|-------------------------------------------------|-------------------------------------------|
| Frontend (React)   | `http://<app_instance_floating_ip>:3000`        | Served directly from app instance         |
| Backend API        | `http://<loadbalancer_public_ip>:8000/api/`     | Routed through load balancer              |
| Health Endpoint    | `GET /api/health`                               | Used for health checks by load balancer   |
| Admin Login        | `administrator@hs-fulda.de` / `Password1234`    | Pre-seeded in MariaDB                     |

---

## 📈 Scalability

The number of app instances can be adjusted via the Terraform variable:

```hcl
variable "app_instance_count" {
  default = 2
}
```

To scale up:

```hcl
app_instance_count = 5
```

Re-run `terraform apply` to create 5 app instances. All will be registered with the load balancer automatically.

---

## 🔐 Security & Monitoring

### ✅ Security Group Rules

| Port | Purpose             |
|------|---------------------|
| 22   | SSH access          |
| 80   | HTTP (optional)     |
| 3000 | React frontend      |
| 8000 | Backend API         |
| 3306 | MariaDB (internal)  |

### 📁 Logs Location

| Component         | Path                        |
|-------------------|-----------------------------|
| Backend (Node.js) | /opt/app/backend.log        |
| Frontend (React)  | /opt/app/frontend.log       |

---

## 🧪 Testing & Verification

Run these from your local machine:

```bash
# Frontend (served directly from app instance)
curl http://<app_instance_floating_ip>:3000

# Backend health check (via load balancer)
curl http://<loadbalancer_floating_ip>:8000/api/health
```

---

## 📌 Load Balancer Role & Frontend Access Clarification

| Access Type      | IP Used                      | Port | Why                                              |
|------------------|------------------------------|------|--------------------------------------------------|
| Frontend (React) | `app_instance_0_floating_ip` | `3000` | Frontend is served directly from app instance    |
| Backend (API)    | `loadbalancer_public_ip`     | `8000` | Backend traffic is distributed via load balancer |

> ℹ️ **Note:** The load balancer currently forwards only port **8000** to backend services (Node.js API).  
> Port **3000** (React frontend) is **not** load-balanced.

---


## 🏁 Project Summary

✅ Fully automates provisioning of frontend, backend, database, and load balancer.  
✅ Implements scalability with Terraform variables.  
✅ Uses cloud-init for headless provisioning and service setup.  
✅ Demonstrates good security practices with firewall rules and logging.  
✅ Follows cloud-native design patterns with load balancing and modularity.  