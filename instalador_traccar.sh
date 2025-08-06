#!/bin/bash

# Instalador Traccar - Suporte a IP ou Domínio
# Baseado em: https://www.traccar.org/optimization/
# Funciona no Ubuntu 20.04/22.04/24.04

set -e

clear

echo ""
echo "████████╗██████╗  █████╗  ██████╗ ██████╗ █████╗ ██████╗ "
echo "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗"
echo "   ██║   ██████╔╝███████║██║     ██║     ███████║██████╔╝"
echo "   ██║   ██╔══██╗██╔══██║██║     ██║     ██╔══██║██╔══██╗"
echo "   ██║   ██║  ██║██║  ██║╚██████╗╚██████╗██║  ██║██║  ██║"
echo "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚═════╝ ╚═╝  ╚═╝"
echo ""
echo "          Instalador Traccar - v3.1 (Suporte a IP)"
echo ""

read -p "Pressione ENTER para continuar..."

# ================== VARIÁVEIS ==================

TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')
TOTAL_MEMORY_MB=$((TOTAL_MEMORY_KB / 1024))

LATEST_VERSION=""
DB_TYPE=""
DB_NAME=""
DB_USER=""
DB_PASS=""
DOMAIN=""
MEMORY_PERCENT="60"
USE_IP_ONLY=false

# Detectar IP público
SERVER_IP=$(curl -s https://api.ipify.org || echo "127.0.0.1")

# ================== ENTRADA DE DADOS ==================

read -p "Versão do Traccar (ex: 6.6, deixe em branco para a mais recente): " input_version
LATEST_VERSION="${input_version}"

while [[ -z "$DB_TYPE" ]]; do
    read -p "Banco de dados (mysql/postgresql) [padrão: mysql]: " db_input
    DB_TYPE="${db_input:-mysql}"
done

while [[ -z "$DB_NAME" ]]; do
    read -p "Nome do banco de dados [padrão: traccar]: " db_name_input
    DB_NAME="${db_name_input:-traccar}"
done

while [[ -z "$DB_USER" ]]; do
    read -p "Usuário do banco [padrão: traccar]: " db_user_input
    DB_USER="${db_user_input:-traccar}"
done

while [[ -z "$DB_PASS" ]]; do
    read -sp "Senha do banco: " DB_PASS
    echo ""
done

read -p "Domínio (ex: rastreamento.dominio.com) ou deixe em branco para usar IP ($SERVER_IP): " domain_input
DOMAIN="${domain_input:-$SERVER_IP}"

if [[ "$DOMAIN" == "$SERVER_IP" ]]; then
    USE_IP_ONLY=true
    echo "Modo IP ativado: $SERVER_IP"
else
    USE_IP_ONLY=false
    echo "Modo domínio: $DOMAIN"
fi

read -p "Porcentagem de memória para Java (padrão: 60%): " mem_input
MEMORY_PERCENT="${mem_input:-60}"

# ================== INSTALAÇÃO DE DEPENDÊNCIAS ==================

echo "Atualizando sistema..."
sudo apt update && sudo apt upgrade -y

echo "Instalando dependências..."
sudo apt install -y unzip openjdk-17-jre nginx curl

if [[ "$DB_TYPE" == "mysql" ]]; then
    sudo apt install -y mysql-server
elif [[ "$DB_TYPE" == "postgresql" ]]; then
    sudo apt install -y postgresql postgresql-contrib
else
    echo "Banco inválido. Use 'mysql' ou 'postgresql'."
    exit 1
fi

# ================== CONFIGURAR BANCO DE DADOS ==================

if [[ "$DB_TYPE" == "mysql" ]]; then
    sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
    sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
    sudo mysql -e "FLUSH PRIVILEGES;"
    sudo systemctl enable mysql
    sudo systemctl start mysql
elif [[ "$DB_TYPE" == "postgresql" ]]; then
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    sudo systemctl enable postgresql
    sudo systemctl start postgresql
fi

# ================== BAIXAR E INSTALAR TRACCAR ==================

if [[ -z "$LATEST_VERSION" ]]; then
    echo "Buscando última versão do Traccar..."
    LATEST_VERSION=$(curl -s https://api.github.com/repos/traccar/traccar/releases/latest | grep tag_name | head -1 | awk -F '"' '{print $4}')
fi

echo "Baixando Traccar $LATEST_VERSION..."
wget -q "https://github.com/traccar/traccar/releases/download/$LATEST_VERSION/traccar-linux-64-${LATEST_VERSION#v}.zip"
unzip -q "traccar-linux-64-${LATEST_VERSION#v}.zip"
sudo ./traccar.run

# ================== CONFIGURAR TRACCAR.XML ==================

DB_DRIVER=""
DB_URL=""
if [[ "$DB_TYPE" == "mysql" ]]; then
    DB_DRIVER="com.mysql.cj.jdbc.Driver"
    DB_URL="jdbc:mysql://localhost:3306/$DB_NAME?allowPublicKeyRetrieval=true&amp;serverTimezone=UTC&amp;useSSL=false&amp;allowMultiQueries=true&amp;autoReconnect=true&amp;useUnicode=yes&amp;characterEncoding=UTF-8&amp;sessionVariables=sql_mode=''"
elif [[ "$DB_TYPE" == "postgresql" ]]; then
    DB_DRIVER="org.postgresql.Driver"
    DB_URL="jdbc:postgresql://localhost:5432/$DB_NAME"
fi

WEB_PROTOCOL="http"
if [[ "$USE_IP_ONLY" == "false" ]]; then
    WEB_PROTOCOL="https"
fi

sudo tee /opt/traccar/conf/traccar.xml > /dev/null <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
    <entry key='database.driver'>$DB_DRIVER</entry>
    <entry key='database.url'>$DB_URL</entry>
    <entry key='database.user'>$DB_USER</entry>
    <entry key='database.password'>$DB_PASS</entry>
    <entry key='web.port'>8082</entry>
    <entry key='web.url'>$WEB_PROTOCOL://$DOMAIN</entry>
    <entry key='logger.level'>info</entry>
    <entry key='logger.file'>/opt/traccar/logs/tracker-server.log</entry>
    <entry key='processing.copyAttributes.enable'>true</entry>
    <entry key='processing.copyAttributes'>power,ignition,battery,blocked,driverUniqueId</entry>
    <entry key='distance.enable'>true</entry>
</properties>
EOL

# ================== CONFIGURAR NGINX ==================

sudo tee /etc/nginx/sites-available/traccar > /dev/null <<EOL
server {
    listen 80;
    server_name $DOMAIN;
    location / {
        proxy_pass http://localhost:8082;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    location /api/socket {
        proxy_pass http://localhost:8082/api/socket;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOL

sudo ln -sf /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t && sudo systemctl enable nginx && sudo systemctl restart nginx

# ================== CONFIGURAR SSL (só se for domínio) ==================

if [[ "$USE_IP_ONLY" == "false" ]]; then
    echo "Instalando Certbot e configurando SSL..."
    sudo apt install -y certbot python3-certbot-nginx
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect || echo "⚠️ Falha no SSL. Acesso será HTTP."
fi

# ================== OTIMIZAÇÕES DE SISTEMA (DOCS TRACCAR.ORG) ==================

echo "Aplicando otimizações de sistema..."

# 1. Limites de arquivos abertos
echo "* soft nofile 50000" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 50000" | sudo tee -a /etc/security/limits.conf

# 2. Aumentar limite de conexões
echo "vm.max_map_count = 250000" | sudo tee -a /etc/sysctl.conf
echo "fs.file-max = 250000" | sudo tee -a /etc/sysctl.conf
echo "net.ipv4.ip_local_port_range = 1024 65535" | sudo tee -a /etc/sysctl.conf

# 3. Timeout de conexão no Traccar (recomendado: 300s)
sudo sed -i '/<\/properties>/i \    <entry key='\''server.timeout'\'\>300<\/entry>' /opt/traccar/conf/traccar.xml

# ================== MEMÓRIA JAVA ==================

MAX_MEMORY_MB=$((TOTAL_MEMORY_MB * MEMORY_PERCENT / 100))
echo "Configurando Java com -Xmx${MAX_MEMORY_MB}m"
sudo sed -i "s|ExecStart=/opt/traccar/jre/bin/java -jar tracker-server.jar conf/traccar.xml|ExecStart=/opt/traccar/jre/bin/java -Xmx${MAX_MEMORY_MB}m -jar tracker-server.jar conf/traccar.xml|" /etc/systemd/system/traccar.service

sudo systemctl daemon-reload

# ================== COMANDOS AMIGÁVEIS ==================

sudo tee /usr/local/bin/iniciar-traccar > /dev/null <<'EOF'
#!/bin/bash
sudo systemctl start traccar
EOF

sudo tee /usr/local/bin/parar-traccar > /dev/null <<'EOF'
#!/bin/bash
sudo systemctl stop traccar
EOF

sudo tee /usr/local/bin/status-traccar > /dev/null <<'EOF'
#!/bin/bash
sudo systemctl status traccar
EOF

sudo tee /usr/local/bin/reiniciar-traccar > /dev/null <<'EOF'
#!/bin/bash
sudo systemctl restart traccar
EOF

sudo tee /usr/local/bin/log-traccar > /dev/null <<'EOF'
#!/bin/bash
sudo tail -f /opt/traccar/logs/tracker-server.log
EOF

sudo chmod +x /usr/local/bin/iniciar-traccar /usr/local/bin/parar-traccar /usr/local/bin/status-traccar /usr/local/bin/reiniciar-traccar /usr/local/bin/log-traccar

# ================== FINALIZAR ==================

sudo systemctl enable traccar
sudo systemctl start traccar

echo ""
echo "✅ Instalação concluída!"
echo ""
if [[ "$USE_IP_ONLY" == "true" ]]; then
    echo "Acesse o Traccar via: http://$SERVER_IP"
else
    echo "Acesse o Traccar via: https://$DOMAIN"
fi
echo ""
echo "Login: admin"
echo "Senha: admin"
echo ""
echo "Use os comandos amigáveis: iniciar-traccar, parar-traccar, status-traccar, log-traccar, reiniciar-traccar"
echo ""
echo "⚠️ Reinicie o servidor para aplicar todas as otimizações de sistema (recomendado)."
