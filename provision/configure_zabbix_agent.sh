#!/usr/bin/env bash
set -euo pipefail

echo "[INFO] Configuring Zabbix Agent 2..."

cat > /etc/zabbix/zabbix_agent2.conf <<'EOF'
PidFile=/run/zabbix/zabbix_agent2.pid
LogFile=/var/log/zabbix/zabbix_agent2.log
LogFileSize=0
Server=127.0.0.1,192.168.56.10,172.17.0.0/16,172.18.0.0/16
ServerActive=127.0.0.1
Hostname=devops-lab
Include=/etc/zabbix/zabbix_agent2.d/*.conf
PluginSocket=/run/zabbix/agent.plugin.sock
ControlSocket=/run/zabbix/agent.sock
Timeout=30
UnsafeUserParameters=1
EOF

cat > /etc/zabbix/zabbix_agent2.d/devops-test.conf <<'EOF'
UserParameter=service.jenkins,curl -kfsS -H 'Host: jenkins.local' https://127.0.0.1/login >/dev/null 2>&1 && echo 1 || echo 0
UserParameter=service.vault,curl -kfsS -H 'Host: vault.local' https://127.0.0.1:8200/v1/sys/health >/dev/null 2>&1 && echo 1 || echo 0
UserParameter=service.zabbix_server,nc -z 127.0.0.1 10051 >/dev/null 2>&1 && echo 1 || echo 0
EOF

systemctl enable zabbix-agent2
systemctl restart zabbix-agent2

echo "[INFO] Zabbix Agent 2 configured."