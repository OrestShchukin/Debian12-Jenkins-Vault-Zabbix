# DevOps Test Project

## 📌 Overview

This project provides a fully automated DevOps environment deployed using **Vagrant + Docker Compose**.

* HashiCorp Vault (secrets management) **(in Dev-mode)**
* Jenkins (CI server, preconfigured)
* Zabbix (monitoring system)
* Nginx Reverse Proxy (DNS-based access)
* Zabbix Agent (monitoring the VM itself)

All components are automatically configured.

## ⚙️ Setup
### 1. Install Oracle Virtual-Box and Vagrant
* **Virtual-Box**: You can visit https://www.virtualbox.org/ to get the latest version for your PC
* **Vagrant**: You can visit https://developer.hashicorp.com/vagrant/install to install teh latest version of vagrant for your PC
### 2. Clone this repository
```bash
git clone https://github.com/OrestShchukin/Debian12-Jenkins-Vault-Zabbix.git
```
### 3. Configure "hosts" file

Add the following entries on your host machine:

```dns
192.168.56.10 vault.local jenkins.local zabbix.local
```

**Hint**: "hosts" file locations on different OS:
* **Windows 11:** `C:\Windows\System32\drivers\etc\hosts`
* **Linux:** `/etc/hosts`
* **macOS:** `/private/etc/hosts`


### 4. Start the environment
Open the terminal inside the cloned directory and run the command:
```bash
vagrant up
```

---

## 🌐 Services:

After configuration process you should be able to access the services via this URLs and be able to authenticate using provided credentials:

| Service | URL                     | Credentials       |
| ------- | ----------------------- | ----------------- |
| Vault   | https://vault.local:8200 | token: `root`     |
| Jenkins | https://jenkins.local    | admin / admin123! |
| Zabbix  | https://zabbix.local     | Admin / zabbix    |

---

## 🏗 Architecture

The environment runs inside a Vagrant VM (Debian 12) at `192.168.56.10`.

All services are deployed via Docker Compose and connected through an internal Docker network.

| Component     | Role                                 |
| ------------- | ------------------------------------ |
| Nginx         | Reverse proxy (domain-based routing) |
| Jenkins       | CI/CD server                         |
| Vault         | Secrets management                   |
| Zabbix Server | Monitoring backend                   |
| Zabbix Web    | Monitoring UI                        |
| PostgreSQL    | Zabbix database                      |
| Zabbix Agent  | Monitors VM and services             |



### External access is handled via Nginx:

| Domain        | Target          |
| ------------- | --------------- |
| jenkins.local | jenkins:8080    |
| zabbix.local  | zabbix-web:8080 |
| vault.local   | vault:8200      |

Nginx routes traffic based on domain name. This eliminates the need for manual port usage.


---

## 🧪 Usage Examples

### Jenkins (CI Example)

1. Open: https://jenkins.local  
2. Login with provided credentials  
3. Click **"New Item"**  
4. Enter name: `test-job`  
5. Select **Freestyle project** → OK  
6. Scroll to **Build Steps** → Add build step → **Execute shell**  
7. Add command:

```bash
echo "Hello from Jenkins"
```
8. Click Save
9. Click Build Now
10. Open the build → Console Output

This verifies that Jenkins is working and able to execute jobs.

---
### Vault (Secrets Management Example - Dev Mode)

Vault runs in Dev Mode:

- No unsealing required  
- Root token is predefined (`root`)  
- Data is stored in memory (not persistent)  
- **Not suitable for production**  

Create a secret via UI:

1. Open https://vault.local:8200  
2. Select "Token" authentication  
3. Enter token: root  
4. Click "Sign in"  
5. Go to "Secrets" → "secret/"  
6. Click "Create secret"  
7. Enter:
   - Path: myapp  
   - Key: password  
   - Value: 123456  
8. Click "Save"  

Verify the secret:

- Open secret/myapp  
- Confirm the stored key/value  

Expected result: the secret is created and visible in Vault UI.

---
### Zabbix (Monitoring Example)

1. Open https://zabbix.local  
2. Login with credentials  
3. Navigate to:

Monitoring → Hosts → devops-lab

4. Check:

- "Latest Data":
  - CPU, RAM, Disk metrics  
  - Docker container metrics  
- "Problems":
  - Service failures (if any)  

What is monitored:

- VM system metrics (CPU, memory, disk)  
- Docker containers (auto-discovery)  
- Service availability:
  - Jenkins  
  - Vault  
  - Zabbix Server  


## ⚙️ Technologies Used

* **Vagrant** – VM provisioning
* **Docker & Docker Compose** – container orchestration
* **Nginx** – reverse proxy
* **Jenkins** – CI/CD server (preconfigured via Groovy)
* **Vault** – secrets management (dev mode)
* **Zabbix** – monitoring system
* **Zabbix Agent 2** – system + service monitoring





---

## ▶️ Environment Commands

### Start environment

```bash
vagrant up
```

### Re-run provisioning

```bash
vagrant provision
```

### Destroy environment

```bash
vagrant destroy -f
```

---

## 🧠 Design Decisions

- `/opt/devops-stack` used as runtime directory (production-like structure)
- `/vagrant` used as source of truth
- Docker Compose network used for internal service communication
- Reverse proxy used instead of direct port exposure
- Zabbix configured via API (fully automated monitoring setup)
- Zabbix Agent 2 Docker plugin used for container-level monitoring (auto-discovery of containers)
- Self-signed TLS certificates used to provide HTTPS access to services

---

## ⚠️ Notes

* Vault runs in **dev mode** (not for production)
* Jenkins data is persisted via Docker volume
* Zabbix database runs in PostgreSQL container
* Reverse proxy is required for proper service access

---

## 🎯 Result

After deployment, the system provides:

* Fully automated infrastructure
* Working CI server (Jenkins)
* Secret management (Vault)
* Monitoring system (Zabbix)
* Clean DNS-based access via reverse proxy

No manual UI configuration is required.


