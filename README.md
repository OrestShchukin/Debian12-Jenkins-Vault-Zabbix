# 🚀 DevOps Test Lab (Vagrant + Docker + Jenkins + Vault + Zabbix)

This project provisions a complete DevOps lab environment using:

- **Vagrant** (Debian 12 VM)
- **Docker & Docker Compose**
- **Jenkins**
- **HashiCorp Vault**
- **Zabbix (Server + Web + Agent)**
- **Nginx Reverse Proxy**

Everything is fully automated via provisioning scripts.

---

# 📦 Architecture Overview


Host (Windows/Linux)
↓
Vagrant VM (Debian 12)
↓
Docker Compose
↓
Jenkins:8080
Vault:8200
Zabbix:8080
↓
Nginx Reverse Proxy
↓
┌───────────────┬───────────────┬───────────────┐
│ jenkins.local │ vault.local │ zabbix.local │
└───────────────┴───────────────┴───────────────┘


---

# ⚙️ Requirements

- Vagrant >= 2.3
- VirtualBox
- Git

---

# 🚀 Quick Start

```bash
git clone <your-repo-url>
cd <repo-folder>

vagrant up

⏱ First run may take a few minutes.

🌐 Access Services

Add to your hosts file:

192.168.56.10 jenkins.local
192.168.56.10 vault.local
192.168.56.10 zabbix.local
🔹 Jenkins
http://jenkins.local

Default credentials:

admin / admin123!
🔹 Vault (Dev mode)
http://vault.local:8200

Token:

root
🔹 Zabbix
http://zabbix.local

Default credentials:

Admin / zabbix
🧠 Features
✅ Full automation
Docker installation
Service provisioning
Zabbix auto-configuration via API
Jenkins auto-setup (no setup wizard)
🔍 Monitoring (Zabbix)

Custom metrics via Zabbix Agent:

Service	Key
Jenkins	service.jenkins
Vault	service.vault
Zabbix Web	service.zabbix_web
Zabbix Server	service.zabbix_server

Each returns:

1 → service is UP
0 → service is DOWN
🔁 Reverse Proxy

All services are exposed via Nginx:

Host-based routing (Host header)
Clean URLs
Single entry point
🛠 Project Structure
.
├── Vagrantfile
├── docker/
│   ├── docker-compose.yml
│   ├── nginx/
│   ├── jenkins/
│   ├── vault/
│   └── zabbix/
├── provision/
│   ├── bootstrap.sh
│   ├── install_packages.sh
│   ├── install_docker.sh
│   ├── prepare_dirs.sh
│   ├── install_zabbix_agent.sh
│   ├── configure_zabbix_agent.sh
│   ├── wait_for_zabbix.sh
│   └── configure_zabbix_api.sh
⚠️ Important Notes
🔹 Line Endings (Windows)

If you see:

/usr/bin/env: ‘bash\r’: No such file or directory

Fix with:

dos2unix provision/*.sh

Or ensure repo uses LF:

*.sh text eol=lf
🔹 Zabbix API Stability

During first vagrant up, Zabbix may not be fully ready.

The provisioning scripts include:

retries
API validation
fallback logic
🔹 Internal vs External Access
Users → via reverse proxy
Automation → direct access (127.0.0.1:8081)

This ensures stability during provisioning.

🧪 Useful Commands
SSH into VM
vagrant ssh
Restart services
cd /opt/devops-test/docker
docker compose restart
Re-run Zabbix setup
sudo /vagrant/provision/configure_zabbix_api.sh
💡 What This Project Demonstrates
Infrastructure provisioning with Vagrant
Container orchestration with Docker Compose
Service automation (Jenkins, Vault, Zabbix)
Monitoring setup via API
Reverse proxy configuration
Resilient provisioning (retry logic, validation)
📌 Future Improvements
HTTPS (Let's Encrypt / self-signed)
Jenkins pipeline examples
Vault secrets integration
Zabbix dashboards & alerts
Terraform instead of Vagrant
👨‍💻 Author

Orest