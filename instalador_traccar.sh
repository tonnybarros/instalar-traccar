#!/bin/bash

# Instalador automático do Traccar com MySQL ou PostgreSQL e SSL via Nginx
# 
# Programador: Tony Barros
# Email: tonybarros@gmail.com
# Contato: +55 21 97912-3851
# 
# Colaborador: Michaell Oliveira
# Email: michaelloliveira@gmail.com
# Contato: +55 79 9116-5245
#
# Changelog
# [2025-03-24] Michaell Oliveira
# * Refatorado
# * Possibilidade de escolher a versão to Traccar 
#   caso não escolha obtem a mais recente
# * Possibilidade de escolher banco de dados:
#   Mysql (padrão) ou Postgresql
# * Compatível com Ubuntu, Debiam, Fedora, Almalinux, Centos
# * Validação de campos sensíveis
# * Mensagens mais informativas
# * Verificação de erros

set -e  # Para encerrar o script em caso de erro

clear
display_banner() {
    echo ""
    echo "████████╗██████╗  █████╗  ██████╗ ██████╗ █████╗ ██████╗ "
    echo "╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██╔════╝██╔══██╗██╔══██╗"
    echo "   ██║   ██████╔╝███████║██║     ██║     ███████║██████╔╝ "
    echo "   ██║   ██╔══██╗██╔══██║██║     ██║     ██╔══██║██╔══██╗"
    echo "   ██║   ██║  ██║██║  ██║╚██████╗╚██████╗██║  ██║██║  ██║"
    echo "   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ╚═════╝ ╚═════╝╚═════╝ ╚═╝  ╚═╝ v2.2"
    echo ""
    echo "Instalador do Traccar - 1.1.4"
    echo "O script sempre vai buscar a última versão Traccar disponível no GitHub caso não informe."
    echo "O script otimizará a memória do Java (caso aceite), leia mais aqui: https://www.traccar.org/optimization/"
    echo "!!!Recomendado usar servidor formatado!!!"
    read -p "Para iniciar, tecle ENTER"
}

get_user_input() {
    
    read -p "Digite a versão do Traccar (Ex: 6.6 ou deixe em branco para a última versão): " LATEST_VERSION

    while [[ -z "$DB_TYPE" ]]; do
        read -p "Escolha o banco de dados (mysql/postgresql): " DB_TYPE
    done
    while [[ -z "$DB_NAME" ]]; do
        read -p "Digite o nome do banco de dados para o Traccar: " DB_NAME
    done
    while [[ -z "$DB_USER" ]]; do
        read -p "Digite o usuário do banco que será criado para o Traccar: " DB_USER
    done
    while [[ -z "$DB_PASS" ]]; do
        read -sp "Digite a senha para o usuário do banco: " DB_PASS
        echo ""
    done
    while [[ -z "$DOMAIN" ]]; do
        read -p "Digite seu domínio (ex: rastreamento.meudominio.com): " DOMAIN
    done
}

install_dependencies() {
    # Detectar a distribuição
    DISTRO=$(lsb_release -i | awk '{print $3}')
    
    if [[ "$DISTRO" == "Ubuntu" || "$DISTRO" == "Debian" ]]; then
        sudo apt update && sudo apt upgrade -y
        sudo apt install -y unzip openjdk-17-jre nginx certbot python3-certbot-nginx curl
        if [[ "$DB_TYPE" == "mysql" ]]; then
            sudo apt install -y mysql-server
        elif [[ "$DB_TYPE" == "postgresql" ]]; then
            sudo apt install -y postgresql postgresql-contrib
        fi
    elif [[ "$DISTRO" == "Fedora" || "$DISTRO" == "CentOS" || "$DISTRO" == "AlmaLinux" ]]; then
        sudo dnf update -y
        sudo dnf install -y unzip java-17-openjdk nginx certbot python3-certbot-nginx curl
        if [[ "$DB_TYPE" == "mysql" ]]; then
            sudo dnf install -y mysql-server
        elif [[ "$DB_TYPE" == "postgresql" ]]; then
            sudo dnf install -y postgresql postgresql-server
        fi
    else
        echo "Distribuição não suportada!"
        exit 1
    fi
}

configure_database() {
    if [[ "$DB_TYPE" == "mysql" ]]; then
        sudo mysql -e "CREATE DATABASE IF NOT EXISTS $DB_NAME CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        sudo mysql -e "CREATE USER IF NOT EXISTS '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS';"
        sudo mysql -e "GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost';"
        sudo mysql -e "FLUSH PRIVILEGES;"
    elif [[ "$DB_TYPE" == "postgresql" ]]; then
        sudo -u postgres psql -c "CREATE DATABASE $DB_NAME;"
        sudo -u postgres psql -c "CREATE USER $DB_USER WITH ENCRYPTED PASSWORD '$DB_PASS';"
        sudo -u postgres psql -c "GRANT ALL PRIVILEGES ON DATABASE $DB_NAME TO $DB_USER;"
    fi
}

download_traccar() {
    if [[ -z "$LATEST_VERSION" ]]; then
        LATEST_VERSION=$(curl -s https://api.github.com/repos/traccar/traccar/releases/latest | grep tag_name | awk -F '"' '{print $4}')
    fi
    wget https://github.com/traccar/traccar/releases/download/$LATEST_VERSION/traccar-linux-64-${LATEST_VERSION:1}.zip
    unzip -o traccar-linux-64-${LATEST_VERSION:1}.zip
    sudo ./traccar.run
}

configure_traccar() {
    DB_DRIVER=""
    DB_URL=""
    if [[ "$DB_TYPE" == "mysql" ]]; then
        DB_DRIVER="com.mysql.cj.jdbc.Driver"
        DB_URL="jdbc:mysql://localhost:3306/$DB_NAME?serverTimezone=UTC&amp;useSSL=false&amp;allowPublicKeyRetrieval=true"
    elif [[ "$DB_TYPE" == "postgresql" ]]; then
        DB_DRIVER="org.postgresql.Driver"
        DB_URL="jdbc:postgresql://localhost:5432/$DB_NAME"
    fi
    sudo tee /opt/traccar/conf/traccar.xml > /dev/null <<EOL
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE properties SYSTEM "http://java.sun.com/dtd/properties.dtd">
<properties>
    <entry key='database.driver'>$DB_DRIVER</entry>
    <entry key='database.url'>$DB_URL</entry>
    <entry key='database.user'>$DB_USER</entry>
    <entry key='database.password'>$DB_PASS</entry>
</properties>
EOL
}

configure_nginx() {
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
    sudo ln -sf /etc/nginx/sites-available/traccar /etc/nginx/sites-enabled/
    sudo nginx -t && sudo systemctl restart nginx
}

configure_ssl() {
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --register-unsafely-without-email --redirect
}

finish_installation() {
    echo "Instalação concluída com sucesso!"
    echo "Acesse via: https://$DOMAIN"
}

display_banner
get_user_input
install_dependencies
configure_database
download_traccar
configure_traccar
configure_nginx
configure_ssl
finish_installation
