# DevOps Test Project

## 📌 Overview

This project provides a fully automated DevOps environment deployed using **Vagrant + Docker Compose**.

* 🔐 HashiCorp Vault (secrets management) **(in Dev-mode)**
* 🛠 Jenkins (CI server, preconfigured)
* 📊 Zabbix (monitoring system)
* 🔄 Nginx Reverse Proxy (DNS-based access)
* 🖥 Zabbix Agent (monitoring the VM itself)

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

```text
192.168.56.10 vault.local
192.168.56.10 jenkins.local
192.168.56.10 zabbix.local
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
| Vault   | http://vault.local:8200 | token: `root`     |
| Jenkins | http://jenkins.local    | admin / admin123! |
| Zabbix  | http://zabbix.local     | Admin / zabbix    |

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

External access is handled via Nginx:

| Domain        | Target          |
| ------------- | --------------- |
| jenkins.local | jenkins:8080    |
| zabbix.local  | zabbix-web:8080 |
| vault.local   | vault:8200      |

Zabbix monitors both system metrics and service availability (Jenkins, Vault, Zabbix Server).



---

## ⚙️ Technologies Used

* **Vagrant** – VM provisioning
* **Docker & Docker Compose** – container orchestration
* **Nginx** – reverse proxy
* **Jenkins** – CI/CD server (preconfigured via Groovy)
* **Vault** – secrets management (dev mode)
* **Zabbix** – monitoring system
* **Zabbix Agent 2** – system + service monitoring

---

## 🔄 Automation Features

Everything is configured automatically via provisioning scripts:

### ✔ Infrastructure

* VM creation (Debian 12)
* Docker installation
* Containers deployment

### ✔ Jenkins

* Setup wizard disabled
* Admin user created automatically
* Plugins installed
* Security configured

### ✔ Vault

* Runs in dev mode
* Root token preset

### ✔ Zabbix

* Agent installed and configured
* Host `devops-lab` created via API
* Linux template attached
* Custom items created:

  * `service.jenkins`
  * `service.vault`
  * `service.zabbix_server`
* Triggers configured for service availability

### ✔ Cleanup

* Default `Zabbix server` host removed (not applicable in containerized setup)

---

## 📊 Monitoring

Zabbix monitors:

### System metrics:

* CPU
* RAM
* Disk usage

### Service availability:

* Jenkins
* Vault
* Zabbix Server

Service checks are implemented using **Zabbix Agent UserParameters**:

```ini
service.jenkins
service.vault
service.zabbix_server
```

---

## 🌍 Reverse Proxy

Nginx routes traffic based on domain name:

| Domain        | Target          |
| ------------- | --------------- |
| jenkins.local | jenkins:8080    |
| zabbix.local  | zabbix-web:8080 |
| vault.local   | vault:8200      |

This eliminates the need for manual port usage.

---

## ▶️ Usage

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

* `/opt/devops-test` used as runtime directory (production-like structure)
* `/vagrant` used as source of truth
* Docker Compose network used for internal service communication
* Reverse proxy used instead of direct port exposure
* Zabbix configured via API (fully automated monitoring setup)

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


