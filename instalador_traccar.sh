#!/bin/bash
# Instalador avançado do Traccar
# Autor: Emerson (baseado em melhorias do TonnyBarros)

set -e

echo "=============================="
echo " Iniciando instalação do Traccar "
echo "=============================="

# --------- Variáveis iniciais ---------
DOMAIN=""
DB_TYPE=""
DB_USER=""
DB_PASS=""
DB_NAME="traccar"
TRACCAR_VERSION="5.7"

read -p "Digite o domínio para o Traccar (ex: m7rastreamento.com.br): " DOMAIN
read -p "Escolha o banco de dados (mysql/postgres): " DB_TYPE
read -p "Digite usuário do banco: " DB_USER
read -s -p "Digite senha do banco: " DB_PASS
echo

# --------- Atualização do sistema ---------
apt update && apt upgrade -y
apt install wget unzip curl sudo software-properties-common gnupg2 lsb-release -y

# --------- Instalar Java (OpenJDK 17) ---------
apt install openjdk-17-jre-headless -y

# --------- Instalar banco de dados ---------
if [ "$DB_TYPE" = "mysql" ]; then
    apt install mariadb-server -y
    systemctl enable mariadb --now
    mysql -u root <<EOF
CREATE DATABASE IF NOT EXISTS $DB_NAME;
CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';
FLUSH PRIVILEGES;
EOF
elif [ "$DB_TYPE" = "postgres" ]; then
    apt install postgresql -y
    systemctl enable postgresql --now
    sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
    sudo -u postgres psql -c "CREATE USER $DB_USER WITH PASSWORD '$DB_PASS';"
    sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
else
    echo "Banco de dados inválido."
    exit 1
fi

# --------- Baixar Traccar ---------
wget https://github.com/traccar/traccar/releases/download/v$TRACCAR_VERSION/traccar-linux-x64-$TRACCAR_VERSION.tar.gz -O /tmp/traccar.tar.gz
tar -xvzf /tmp/traccar.tar.gz -C /opt/
mv /opt/traccar-$TRACCAR_VERSION /opt/traccar
chmod +x /opt/traccar/bin/traccar

# --------- Criar arquivo tracker-server.xml ---------
cat >/opt/traccar/conf/tracker-server.xml <<EOL
<?xml version='1.0' encoding='UTF-8'?>
<properties>
    <entry key='database.driver'>$( [ "$DB_TYPE" = "mysql" ] && echo "com.mysql.cj.jdbc.Driver" || echo "org.postgresql.Driver" )</entry>
    <entry key='database.url'>$( [ "$DB_TYPE" = "mysql" ] && echo "jdbc:mysql://localhost/$DB_NAME?serverTimezone=UTC" || echo "jdbc:postgresql://localhost/$DB_NAME" )</entry>
    <entry key='database.user'>$DB_USER</entry>
    <entry key='database.password'>$DB_PASS</entry>
</properties>
EOL

# --------- Criar serviço systemd ---------
cat >/etc/systemd/system/traccar.service <<EOL
[Unit]
Description=Traccar GPS Server
After=network.target

[Service]
User=root
ExecStart=/opt/traccar/bin/traccar
Restart=on-failure
Type=simple

[Install]
WantedBy=multi-user.target
EOL

systemctl daemon-reload
systemctl enable --now traccar

# --------- Instalar Nginx ---------
apt install nginx -y

cat >/etc/nginx/sites-available/traccar <<EOL
server {
    listen 80;
    server_name $DOMAIN www.$DOMAIN;

    location / {
        proxy_pass http://127.0.0.1:8082;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
EOL

ln -sf /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx

# --------- Certbot SSL (opcional) ---------
apt install certbot python3-certbot-nginx -y
certbot --nginx -d $DOMAIN -d www.$DOMAIN --non-interactive --agree-tos -m seu-email@dominio.com || echo "Certificado SSL falhou ou já existe."

# --------- Final ---------
echo "=================================="
echo " Traccar instalado e rodando com sucesso "
echo "Acesse: http://$DOMAIN ou via https se SSL habilitado"
echo "Status do serviço: systemctl status traccar"
echo "=================================="
