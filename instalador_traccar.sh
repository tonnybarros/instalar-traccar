#!/bin/bash

# Instalador automático do Traccar com MySQL e SSL via Nginx

clear

echo ""
echo "████████╗██████╗  █████╗  ██████╗ ██████╗ █████╗ ██████╗ "
echo "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗"
echo "   ██║   ██████╔╝███████║██║     ██║     ███████║██████╔╝ "
echo "   ██║   ██╔══██╗██╔══██║██║     ██║     ██╔══██║██╔══██╗"
echo "   ██║   ██║  ██║██║  ██║╚██████╗╚██████╗██║  ██║██║  ██║"
echo "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚═════╝ ╚═╝  ╚═╝ v1.0"
echo ""
echo "Instalador do Traccar - Última versão disponível"
echo "Suporte: tectonny@gmail.com"
read -p "Para iniciar tecle ENTER"

# Solicitação prévia de dados
read -p "Digite o nome do banco de dados para o Traccar: " DB_NAME
read -p "Digite o usuário MySQL que será criado para o Traccar: " DB_USER
read -sp "Digite a senha para o usuário MySQL: " DB_PASS
echo ""
read -p "Digite seu domínio (ex: rastreamento.meudominio.com): " DOMAIN

# Atualizar sistema
sudo apt update && sudo apt upgrade -y

# Instalando dependências
echo "Instalando dependências..."
sudo apt install unzip openjdk-17-jre mysql-server nginx certbot python3-certbot-nginx curl -y

# Configuração do MySQL
echo "Configurando MySQL..."
sudo mysql -e "CREATE DATABASE $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
sudo mysql -e "CREATE USER '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
sudo mysql -e "FLUSH PRIVILEGES;"

# Detectar e baixar última versão do Traccar
echo "Detectando e baixando a última versão do Traccar..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/traccar/traccar/releases/latest | grep tag_name | awk -F '"' '{print $4}')
wget https://github.com/traccar/traccar/releases/download/$LATEST_VERSION/traccar-linux-64-${LATEST_VERSION:1}.zip
unzip traccar-linux-64-${LATEST_VERSION:1}.zip
sudo ./traccar.run

# Baixar driver MySQL
echo "Baixando driver MySQL..."
sudo wget -P /opt/traccar/lib https://repo1.maven.org/maven2/com/mysql/mysql-connector-j/8.3.0/mysql-connector-j-8.3.0.jar

# Configurar banco de dados no Traccar
echo "Configurando conexão com o banco de dados no Traccar..."
sudo tee /opt/traccar/conf/traccar.xml > /dev/null <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
    <entry key='database.driver'>com.mysql.cj.jdbc.Driver</entry>
    <entry key='database.url'>jdbc:mysql://localhost:3306/$DB_NAME?serverTimezone=UTC&amp;useSSL=false&amp;allowPublicKeyRetrieval=true</entry>
    <entry key='database.user'>$DB_USER</entry>
    <entry key='database.password'>$DB_PASS</entry>
</properties>
EOL

# Configurar domínio e SSL com Nginx
echo "Configurando domínio e SSL com Nginx..."
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
}
EOL
sudo ln -s /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl restart nginx

# SSL automático via Certbot
sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect

# Criando o serviço systemd
echo "Criando o serviço do Traccar..."
sudo tee /etc/systemd/system/traccar.service > /dev/null <<EOL
[Unit]
Description=Traccar GPS Tracking System
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/traccar
ExecStart=/usr/bin/java -jar tracker-server.jar conf/traccar.xml
SuccessExitStatus=143

[Install]
WantedBy=multi-user.target
EOL

sudo systemctl daemon-reload
sudo systemctl enable traccar
sudo systemctl start traccar

# Criando comandos amigáveis
sudo tee /usr/local/bin/iniciar-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl start traccar
EOL
sudo tee /usr/local/bin/parar-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl stop traccar
EOL
sudo tee /usr/local/bin/status-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl status traccar
EOL
sudo tee /usr/local/bin/reiniciar-traccar > /dev/null <<EOL
#!/bin/bash
sudo systemctl restart traccar
EOL
sudo tee /usr/local/bin/log-traccar > /dev/null <<EOL
#!/bin/bash
sudo tail -f /opt/traccar/logs/tracker-server.log
EOL
sudo tee /usr/local/bin/log-traccar-pesquisa > /dev/null <<EOL
#!/bin/bash
if [ -z "\$1" ]; then
    echo "Por favor, forneça um termo de pesquisa."
    echo "Uso: log-traccar-pesquisa termo"
    exit 1
fi
sudo tail -f /opt/traccar/logs/tracker-server.log | grep --color=auto "\$1"
EOL
sudo tee /usr/local/bin/editar-traccar > /dev/null <<EOL
#!/bin/bash
sudo nano /opt/traccar/conf/traccar.xml
EOL
sudo chmod +x /usr/local/bin/iniciar-traccar /usr/local/bin/parar-traccar /usr/local/bin/status-traccar /usr/local/bin/reiniciar-traccar /usr/local/bin/log-traccar /usr/local/bin/editar-traccar /usr/local/bin/log-traccar-pesquisa

# Finalizando instalação
echo "Instalação concluída com sucesso!"
echo "Gerencie o Traccar com:"
echo "iniciar-traccar | parar-traccar | status-traccar | reiniciar-traccar | log-traccar | log-traccar-pesquisa xxxx | editar-traccar"
echo "Acesse via: https://$DOMAIN"
