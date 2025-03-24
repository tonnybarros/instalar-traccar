#!/bin/bash

# Instalador automático do Traccar com MySQL e SSL via Nginx

clear

echo ""
echo "████████╗██████╗  █████╗  ██████╗ ██████╗ █████╗ ██████╗ "
echo "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗"
echo "   ██║   ██████╔╝███████║██║     ██║     ███████║██████╔╝ "
echo "   ██║   ██╔══██╗██╔══██║██║     ██║     ██╔══██║██╔══██╗"
echo "   ██║   ██║  ██║██║  ██║╚██████╗╚██████╗██║  ██║██║  ██║"
echo "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚═════╝ ╚═╝  ╚═╝ v2.1"
echo ""
echo "Instalador do Traccar - Última versão disponível"
echo "O script sempre vai buscar a ultima versão disponível no Github"
echo "O script vai otimizar memória do Java (caso aceite), leia mais aqui: https://www.traccar.org/optimization/"
read -p "Para iniciar tecle ENTER"

# Solicitação prévia de dados
read -p "Digite o nome do banco de dados para o Traccar: " DB_NAME
read -p "Digite o usuário MySQL que será criado para o Traccar: " DB_USER
read -sp "Digite a senha para o usuário MySQL: " DB_PASS
echo ""
read -p "Digite seu domínio (ex: rastreamento.meudominio.com): " DOMAIN

# Pergunta sobre a porcentagem de memória
TOTAL_MEMORY_KB=$(grep MemTotal /proc/meminfo | awk '{print $2}')  # Memória total em KB
TOTAL_MEMORY_MB=$((TOTAL_MEMORY_KB / 1024))  # Converter para MB
echo "A memória total do servidor é: ${TOTAL_MEMORY_MB}MB"
read -p "Digite a porcentagem da memória do servidor que deseja alocar para o Java (exemplo: 60 para 60%) (Deixe em branco para não editar o serviço): " MEMORY_PERCENT

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

# Calcular 60% da memória total do servidor em MB
if [ ! -z "$MEMORY_PERCENT" ]; then
    MAX_MEMORY_MB=$((TOTAL_MEMORY_MB * MEMORY_PERCENT / 100)) # Porcentagem de memória em MB

    echo "Configurando a memória máxima de uso do Java (Xmx) para ${MEMORY_PERCENT}% da memória total desse servidor: ${MAX_MEMORY_MB}MB"
    sudo sed -i "s|ExecStart=/opt/traccar/jre/bin/java -jar tracker-server.jar conf/traccar.xml|ExecStart=/opt/traccar/jre/bin/java -Xmx${MAX_MEMORY_MB}m -jar tracker-server.jar conf/traccar.xml|" /etc/systemd/system/traccar.service

    sudo systemctl daemon-reload
    sudo systemctl restart traccar
fi

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
echo ""
echo "Acesse via: https://$DOMAIN"
echo "Crie os dados de acesso no primeiro acesso!"
echo ""
echo "Banco do Mysql: $DB_NAME"
echo "Usuário do Mysql: $DB_USER"
echo "Senha Mysql: $DB_PASS"
