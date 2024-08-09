#!/bin/bash
##
# EngineGP   (https://enginegp.ru or https://enginegp.com)
#
# @copyright Copyright (c) 2023-present Solovev Sergei <inbox@seansolovev.ru>
# 
# @link      https://github.com/EngineGPDev/Autoinstall for the canonical source repository
#
# @license   https://github.com/EngineGPDev/Autoinstall/blob/main/LICENSE MIT License
##

# Обновление таблиц и системы
sysUpdate (){
    echo "===================================" >> $logsINST 2>&1
    echo "Обновление системы..." | tee -a $logsINST
    echo "===================================" >> $logsINST 2>&1
    apt-get -y update >> $logsINST 2>&1
    apt-get -y upgrade >> $logsINST 2>&1
}

# Очистка экрана перед установкой
clear

# Создаём переменную для логов
logsINST="$(dirname "$0")/enginegp_install.log"

# Директория сохранения данных
saveDIR="/root/enginegp.cfg"

# Обновление системы
sysUpdate

# Установка начальных пакетов.
pkgsREQ=(sudo curl lsb-release wget gnupg pwgen zip unzip bc tar software-properties-common git)

# Цикл установки пакетов
for package in "${pkgsREQ[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" >> $logsINST 2>&1
        echo "$package не установлен. Выполняется установка..."  | tee -a $logsINST
        echo "===================================" >> $logsINST 2>&1
        apt-get install -y "$package" >> $logsINST 2>&1
    fi
done

# Массив с поддерживаемыми версиями операционной системы
suppOS=("Debian 11" "Debian 12" "Ubuntu 22.04" "Ubuntu 24.04")

# Получаем текущую версию операционной системы
disOS=`lsb_release -si`
relOS=`lsb_release -sr`
currOS="$disOS $relOS"

# Файловый репозиторий
resURL="https://resources.enginegp.com"

# Проверка аргументов командной строки
if [ $# -gt 0 ]; then
    # Переменные для хранения
    verPHP=""
    sysIP=""
    gitEGP=""

    # Перебор всех аргументов
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            --php)
                # Если передан аргумент --php, сохранить указанную версию PHP
                verPHP="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --php
                ;;
            --ip)
                # Если передан аргумент --ip, сохранить указанный IP-адрес
                sysIP="$2"
                shift # Пропустить значение IP-адреса
                shift # Пропустить аргумент --ip
                ;;
            --branch)
                # Если передан аргумент --ip, сохранить указанный IP-адрес
                gitEGP="$2"
                shift # Пропустить значение ветки
                shift # Пропустить аргумент --branch
                ;;
            *)
                # Неизвестный аргумент, вывести справку и выйти
                clear
                echo "Использование: ./install.sh --php 7.4 --ip 192.168.1.1 --branch main"
                echo "  --php версия: установить указанную версию PHP. Формат должен быть: 7.4"
                echo "  --ip IP-адрес: использовать указанный IP-адрес. Формат должен быть: 192.168.1.1"
                echo "  --branch ветка: использовать указаную ветку GIT. Формат должен быть: main"
                exit 1
                ;;
        esac
    done

    # Если версия PHP не выбрана, использовать PHP 7.4 по умолчанию
    if [ -z "$verPHP" ]; then
        verPHP="7.4"
    fi

    # Если IP-адрес не указан, получить внешний IP-адрес с помощью сервиса ipinfo.io
    if [ -z "$sysIP" ]; then
        sysIP=$(curl -s ipinfo.io/ip)
    fi

    # Если ветка не указана, использовать main
    if [ -z "$gitEGP" ]; then
        gitEGP="main"
    fi
else
    # Если нет аргументов, задаём по умолчанию
    verPHP="7.4"
    sysIP=$(curl -s ipinfo.io/ip)
    gitEGP="main"
fi

# Проверяем, является ли полученный IP-адрес действительным IPv4 адресом
if [[ $sysIP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    sysIP=$sysIP
else
    clear
    echo "Не удалось получить внешний IP-адрес"
    echo "Используй: ./install.sh [--ip IP-адрес]"
    exit
fi

while true; do
    clear
    echo "Меню установки EngineGP:"
    echo "1. Установка панели управления"
    echo "2. Настройка сервера под игры"
    echo "3. Установка игровых сборок"
    echo "4. Системная информация"
    echo "0. Выход"

    read -p "Выберите пункт меню: " choice

    case $choice in
        1)
            clear
            # Проверяем, содержится ли текущая версия в массиве поддерживаемых версий
            if [[ " ${suppOS[@]} " =~ " ${currOS} " ]]; then
                # Проверяем наличие репозитория php
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/php.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий php не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Установка используемых пакетов
                        sudo apt-get -y install lsb-release ca-certificates curl >> $logsINST 2>&1

                        # Скачиваем ключа зеркала репозитория Sury
                        sudo curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://mirror.enginegp.com/sury/debsuryorg-archive-keyring.deb >> $logsINST 2>&1

                        # Устанавливаем ключа зеркала репозитория Sury
                        sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb >> $logsINST 2>&1

                        # Добавляем репозиторий php
                        sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://mirror.enginegp.com/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1

                        # Определяем версию php по умолчанию
                        defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                    fi
                else
                    if [ ! -f "/etc/apt/sources.list.d/ondrej-ubuntu-php-*.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий php не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий php
                        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1

                        # Определяем версию php по умолчанию
                        defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                    fi
                fi

                # Проверяем наличие репозитория nginx
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/nginx.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Установка используемых пакетов
                        sudo apt-get -y install lsb-release ca-certificates curl >> $logsINST 2>&1

                        # Скачиваем ключа зеркала репозитория Sury
                        sudo curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://mirror.enginegp.com/sury/debsuryorg-archive-keyring.deb >> $logsINST 2>&1

                        # Устанавливаем ключа зеркала репозитория Sury
                        sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb >> $logsINST 2>&1

                        # Добавляем репозиторий nginx
                        sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-nginx.gpg] https://mirror.enginegp.com/sury/nginx/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/nginx.list' >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                else
                    if [ ! -f "/etc/apt/sources.list.d/ondrej-ubuntu-nginx-*.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий nginx
                        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx -y >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                fi

                # Список пакетов для установки
                pkgsLIST=(php$verPHP-fpm php$verPHP-common php$verPHP-cli php$verPHP-memcache php$verPHP-mysql php$verPHP-xml php$verPHP-mbstring php$verPHP-gd php$verPHP-imagick php$verPHP-zip php$verPHP-curl php$verPHP-ssh2 nginx ufw memcached screen cron)
                pkgsPMA=(php$defPHP-fpm php$defPHP-mbstring php$defPHP-zip php$defPHP-gd php$defPHP-json php$defPHP-curl)

                # Генерирование паролей и имён
                passSQL=$(pwgen -cns -1 16)
                passPMA=$(pwgen -cns -1 16)
                usrEgpSQL="enginegp_$(pwgen -cns -1 8)"
                dbEgpSQL="enginegp_$(pwgen -1 8)"
                passEgpSQL=$(pwgen -cns -1 16)
                usrEgpPASS=$(pwgen -cns -1 16)

                # Конфигурация nginx для EngineGP
                nginx_enginegp="server {
    listen 80;
    server_name $sysIP;

    root /var/www/enginegp;
    index index.php;

    charset utf-8;

    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }

    location /acp/ {
        try_files \$uri \$uri/ /acp/index.php?\$args;
    }

    location ~* /\.(gif|jpeg|jpg|txt|png|tif|tiff|ico|jng|bmp|doc|pdf|rtf|xls|ppt|rar|rpm|swf|zip|bin|exe|dll|deb|cur)$ {
        access_log off;
        expires 3d;
    }

    location ~* /\.(css|js)$ {
        access_log off;
        expires 180m;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ /\.en {
        deny all;
    }

    error_page 403 /403.html;
    location = /403.html {
        internal;
    }

    error_page 404 /404.html;
    location = /404.html {
        internal;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php$verPHP-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}"

                # Конфигурация nginx для phpMyAdmin
                nginx_phpmyadmin="server {
    listen 9090;
    server_name $sysIP;

    root /usr/share/phpmyadmin;
    index index.php;

    location / {
        try_files \$uri \$uri/ /index.php;
    }

    location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
        root /usr/share/phpmyadmin;
    }

    location ~ /\.ht {
        deny all;
    }

    location ~ \.php$ {
        include fastcgi_params;
        fastcgi_pass unix:/run/php/php$defPHP-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        include fastcgi_params;
    }
}"

                # Устанавливаем базу данных
                if ! dpkg-query -W -f='${Status}' "mysql-server" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "mysql-server не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo debconf-set-selections <<EOF
mysql-apt-config mysql-apt-config/select-server select mysql-8.0
mysql-apt-config mysql-apt-config/select-tools select Enabled
mysql-apt-config mysql-apt-config/select-preview select Disabled
EOF
                    sudo curl -SLO https://dev.mysql.com/get/mysql-apt-config_0.8.30-1_all.deb >> $logsINST 2>&1
                    sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.30-1_all.deb >> $logsINST 2>&1
                    sudo apt-get update >> $logsINST 2>&1
                    sudo rm mysql-apt-config_0.8.30-1_all.deb >> $logsINST 2>&1
                    sudo debconf-set-selections <<EOF
mysql-community-server mysql-community-server/root-pass password $passSQL
mysql-community-server mysql-community-server/re-root-pass password $passSQL
mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)
EOF
                    sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y mysql-server >> $logsINST 2>&1

                    # Создание пользователя
                    mysql -u root -p$passSQL -e "CREATE USER '$usrEgpSQL'@'localhost' IDENTIFIED BY '$passEgpSQL';" >> $logsINST 2>&1

                    # Создание базы данных
                    mysql -u root -p$passSQL -e "CREATE DATABASE $dbEgpSQL;" >> $logsINST 2>&1
                    
                    # Предоставление привилегий пользователю на базу данных
                    mysql -u root -p$passSQL -e "GRANT ALL PRIVILEGES ON $dbEgpSQL.* TO '$usrEgpSQL'@'localhost';" >> $logsINST 2>&1
                    
                    # Применение изменений привилегий
                    mysql -u root -p$passSQL -e "FLUSH PRIVILEGES;" >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "mysql-server уже установлен в системе. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Цикл установки пакетов
                for package in "${pkgsLIST[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo apt-get install -y "$package" >> $logsINST 2>&1
                    fi
                done

                # Цикл установки пакетов
                for package in "${pkgsPMA[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo apt-get install -y "$package" >> $logsINST 2>&1
                    fi
                done

                # Установка phpMyAdmin
                if ! dpkg-query -W -f='${Status}' "phpmyadmin" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "phpmyadmin не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo debconf-set-selections <<EOF
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/mysql/app-pass password $passPMA
phpmyadmin phpmyadmin/password-confirm password $passPMA
phpmyadmin phpmyadmin/mysql/admin-pass password $passSQL
phpmyadmin phpmyadmin/app-password-confirm password $passSQL
phpmyadmin phpmyadmin/reconfigure-webserver multiselect
EOF
                    sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y phpmyadmin >> $logsINST 2>&1
                    echo -e "$nginx_phpmyadmin" | sudo tee /etc/nginx/sites-available/00-phpmyadmin.conf >> $logsINST 2>&1
                    sudo ln -s /etc/nginx/sites-available/00-phpmyadmin.conf /etc/nginx/sites-enabled/ >> $logsINST 2>&1

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t >> $logsINST 2>&1
                    sudo systemctl restart nginx >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "phpmyadmin уже установлен в системе. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Установка версии php по умолчанию
                if [[ "$(php -v | grep -oP '(?<=PHP )(\d+\.\d+)')" != "$verPHP" ]]; then
                    sudo update-alternatives --set php /usr/bin/php$verPHP >> $logsINST 2>&1
                    sudo update-alternatives --set php-config /usr/bin/php-config$verPHP >> $logsINST 2>&1
                    sudo update-alternatives --set phpdbg /usr/bin/phpdbg$verPHP >> $logsINST 2>&1
                    sudo update-alternatives --set phpize /usr/bin/phpize$verPHP >> $logsINST 2>&1
                fi

                # Проверяем установку php-fpm по умолчанию
                if dpkg-query -W -f='${Status}' "php$defPHP-fpm" 2>/dev/null | grep -q "install ok installed"; then
                    if ! systemctl is-active --quiet php$defPHP-fpm; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "php$defPHP-fpm не запущен. Выполняется запуск..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo systemctl start php$defPHP-fpm >> $logsINST 2>&1
                    fi
                fi

                # Проверяем установку php-fpm для EngineGP
                if dpkg-query -W -f='${Status}' "php$verPHP-fpm" 2>/dev/null | grep -q "install ok installed"; then
                    if ! systemctl is-active --quiet php$verPHP-fpm; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "php$verPHP-fpm не запущен. Выполняется запуск..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo systemctl start php$verPHP-fpm >> $logsINST 2>&1
                    fi
                fi

                # Установка и настрока composer
                if [ ! -f "/usr/local/bin/composer" ]; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "composer не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    curl -sSL https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer >> $logsINST 2>&1
                fi

                # Установка EngineGP
                if [ ! -d "/var/www/enginegp" ]; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "enginegp не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1

                    # Клонирование репозитория
                    sudo git clone --branch $gitEGP https://github.com/EngineGPDev/EngineGP.git /var/www/enginegp >> $logsINST 2>&1

                    # Установка зависимостей composer
                    sudo COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir=/var/www/enginegp >> $logsINST 2>&1

                    # Хэширование пароля пользователя перед записью в базу данных
                    usrEgpHASH=$(php$verPHP -r "echo password_hash('$usrEgpPASS', PASSWORD_DEFAULT);") >> $logsINST 2>&1

                    # Настраиваем конфигурацию панели и экспортируем базу данных
                    sudo mv /var/www/enginegp/.env.example /var/www/enginegp/.env >> $logsINST 2>&1
                    sed -i "s/example.com/$sysIP/g" /var/www/enginegp/.env >> $logsINST 2>&1
                    sed -i "s/enginegp_db/$dbEgpSQL/g" /var/www/enginegp/.env >> $logsINST 2>&1
                    sed -i "s/enginegp_usr/$usrEgpSQL/g" /var/www/enginegp/.env >> $logsINST 2>&1
                    sed -i "s/enginegp_pwd/$passEgpSQL/g" /var/www/enginegp/.env >> $logsINST 2>&1
                    sed -i "s/ENGINEGPHASH/$(echo "$usrEgpHASH" | sed 's/[\/&]/\\&/g')/g" /var/www/enginegp/enginegp.sql >> $logsINST 2>&1
                    mysql -u $usrEgpSQL -p$passEgpSQL $dbEgpSQL < /var/www/enginegp/enginegp.sql >> $logsINST 2>&1
                    rm /var/www/enginegp/enginegp.sql >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "enginegp уже установлен в системе. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Выставляем права на каталог и файлы
                sudo chown -R www-data:www-data /var/www/enginegp >> $logsINST 2>&1
                sudo find /var/www/enginegp -type f -exec chmod 644 {} \; >> $logsINST 2>&1
                sudo find /var/www/enginegp -type d -exec chmod 755 {} \; >> $logsINST 2>&1

                # Настраиваем nginx
                if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "nginx не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Удаляем дефолтный и создаём конфиг EngineGP
                    sudo rm /etc/nginx/sites-enabled/default >> $logsINST 2>&1
                    echo -e "$nginx_enginegp" | sudo tee /etc/nginx/sites-available/01-enginegp.conf >> $logsINST 2>&1
                    sudo ln -s /etc/nginx/sites-available/01-enginegp.conf /etc/nginx/sites-enabled/ >> $logsINST 2>&1

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t >> $logsINST 2>&1
                    sudo systemctl restart nginx >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "NGINX не установлен. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Сообщение о завершении установки
                echo "===================================" | tee -a $saveDIR
                echo "Установка завершена!" | tee -a $saveDIR
                echo "Ссылка на EngineGP: http://$sysIP/" | tee -a $saveDIR
                echo "Пользователь: root" | tee -a $saveDIR
                echo "Пароль: $usrEgpPASS" | tee -a $saveDIR
                echo "===================================" | tee -a $saveDIR
                echo "MySQL данные для EngineGP" | tee -a $saveDIR
                echo "Ссылка на phpMyAdmin: http://$sysIP:9090/" | tee -a $saveDIR
                echo "База данных: $dbEgpSQL" | tee -a $saveDIR
                echo "Пользователь: $usrEgpSQL" | tee -a $saveDIR
                echo "Пароль: $passEgpSQL" | tee -a $saveDIR
                echo "===================================" | tee -a $saveDIR
                echo "Системные данные MySQL" | tee -a $saveDIR
                echo "MySQL пароль от root: $passSQL" | tee -a $saveDIR
                echo "MySQL пароль от phpMyAdmin: $passPMA" | tee -a $saveDIR
                echo "===================================" | tee -a $saveDIR
                read -p "Нажмите Enter для завершения..."
                continue
            else
                echo "===================================" >> $logsINST 2>&1
                echo "Вы используете неподдерживаемую версию Linux" | tee -a $logsINST
                echo "===================================" >> $logsINST 2>&1
                read -p "Нажмите Enter для завершения..."
            fi
            ;;
        2)
            clear

            useEngineGP=""

            while true; do
                echo -n "Хотите настроить локацию на сервере с EngineGP? (y/n)"
                read useEngineGP

                case $useEngineGP in
                    [Yy]*)
                        echo -n "Введите пароль root от MySQL:"
                        read -s userPassword
                        echo
                        passMySQL=$userPassword
                        break
                        ;;
                    [Nn]*)
                        passMySQL=$(pwgen -cns -1 16)
                        break
                        ;;
                    *)
                        echo "Пожалуйста, введите 'y' или 'n'."
                        ;;
                esac
            done

            clear

            passProFTPD=$(pwgen -cns -1 16)
            
            # Проверяем, содержится ли текущая версия в массиве поддерживаемых версий
            if [[ " ${suppOS[@]} " =~ " ${currOS} " ]]; then
                # Проверяем наличие репозитория nginx
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/nginx.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Установка используемых пакетов
                        sudo apt-get -y install lsb-release ca-certificates curl >> $logsINST 2>&1

                        # Скачиваем ключа зеркала репозитория Sury
                        sudo curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://mirror.enginegp.com/sury/debsuryorg-archive-keyring.deb >> $logsINST 2>&1

                        # Устанавливаем ключа зеркала репозитория Sury
                        sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb >> $logsINST 2>&1

                        # Добавляем репозиторий nginx
                        sudo sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-nginx.gpg] https://mirror.enginegp.com/sury/nginx/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/nginx.list' >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                else
                    if [ ! -f "/etc/apt/sources.list.d/ondrej-ubuntu-nginx-*.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий nginx
                        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx -y >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                fi

                # Конфигурация nginx для FastDL
                nginx_fastdl="server {
    listen 8080;
    location / {
        root   /var/nginx/;
        index  index.html index.htm;
        set \$limit_rate 20m;
    }
    location ~ /(.*)/.*\.cfg {
        deny all;
    }
    location ~ /(.*)/.*\.vpk {
        deny all;
    }
    location ~ /(.*)/cfg/ {
        deny all;
    }
    location ~ /(.*)/addons/ {
        deny all;
    }
    location ~ /(.*)/logs/ {
        deny all;
    }
}"

                pkgsLOC=(glibc-source lib32z1 libbabeltrace1 libc6-dbg libdw1 lib32stdc++6 libreadline8 lib32gcc-s1 screen tcpdump lsof qstat gdb-minimal ntpdate gcc-multilib iptables default-jdk nginx)

                if ! dpkg --print-foreign-architectures | grep -q "i386"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "Архитектура i386 не добавлена. Выполняется добавление..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo dpkg --add-architecture i386 >> $logsINST 2>&1

                    # Обновление таблиц
                    apt-get -y update >> $logsINST 2>&1
                fi

                # Устанавливаем базу данных
                if [[ "${useEngineGP,,}" == "n" ]]; then
                    if ! dpkg-query -W -f='${Status}' "mysql-server" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "mysql-server не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo debconf-set-selections <<EOF
mysql-apt-config mysql-apt-config/select-server select mysql-8.0
mysql-apt-config mysql-apt-config/select-tools select Enabled
mysql-apt-config mysql-apt-config/select-preview select Disabled
EOF
                        sudo curl -SLO https://dev.mysql.com/get/mysql-apt-config_0.8.30-1_all.deb >> $logsINST 2>&1
                        sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.30-1_all.deb >> $logsINST 2>&1
                        sudo apt-get update >> $logsINST 2>&1
                        sudo rm mysql-apt-config_0.8.30-1_all.deb >> $logsINST 2>&1
                        sudo debconf-set-selections <<EOF
mysql-community-server mysql-community-server/root-pass password $passMySQL
mysql-community-server mysql-community-server/re-root-pass password $passMySQL
mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)
EOF
                        sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y mysql-server >> $logsINST 2>&1
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "mysql-server уже установлен в системе. Продолжение установки невозможно." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        read -p "Нажмите Enter для завершения..."
                        continue
                    fi
                fi

                # Цикл установки пакетов
                for package in "${pkgsLOC[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        apt-get install -y "$package" >> $logsINST 2>&1
                    fi
                done

                # Настраиваем FastDL
                if [ ! -f /etc/nginx/sites-available/02-fastdl.conf ]; then
                    # Создаём каталог и выдаём ему права
                    sudo mkdir -p /var/nginx >> $logsINST 2>&1
                    sudo chmod -R 755 /var/nginx >> $logsINST 2>&1

                    echo "===================================" >> $logsINST 2>&1
                    echo "fastdl не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Удаляем дефолтный конфиг и создаём для FastDL
                    sudo rm /etc/nginx/sites-enabled/default >> $logsINST 2>&1
                    echo -e "$nginx_fastdl" | sudo tee /etc/nginx/sites-available/02-fastdl.conf >> $logsINST 2>&1
                    sudo ln -s /etc/nginx/sites-available/02-fastdl.conf /etc/nginx/sites-enabled/ >> $logsINST 2>&1

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t >> $logsINST 2>&1
                    sudo systemctl restart nginx >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "fastdl не установлен. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Устанавливаем ProFTPD
                if ! dpkg-query -W -f='${Status}' "proftpd" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "proftpd не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    echo "proftpd shared/proftpd/inetd_or_standalone select standalone" | debconf-set-selections
                    sudo apt-get install -y proftpd-basic proftpd-mod-mysql >> $logsINST 2>&1
                    curl -o /etc/proftpd/proftpd.conf $resURL/Components/ProFTPD/proftpd >> $logsINST 2>&1
                    curl -o /etc/proftpd/modules.conf $resURL/Components/ProFTPD/proftpd_modules >> $logsINST 2>&1
                    curl -o /etc/proftpd/sql.conf $resURL/Components/ProFTPD/proftpd_sql >> $logsINST 2>&1
                    mysql -u root -p$passMySQL -e "CREATE DATABASE ftp;" >> $logsINST 2>&1
                    mysql -u root -p$passMySQL -e "CREATE USER 'ftp'@'localhost' IDENTIFIED BY '$passProFTPD';" >> $logsINST 2>&1
                    mysql -u root -p$passMySQL -e "GRANT ALL PRIVILEGES ON ftp . * TO 'ftp'@'localhost';" >> $logsINST 2>&1
                    curl -sSL $resURL/Components/ProFTPD/sqldump.sql | mysql -u root -p$passMySQL ftp >> $logsINST 2>&1
                    sed -i 's/passwdfor/'$passMySQL'/g' /etc/proftpd/sql.conf >> $logsINST 2>&1
                    chmod -R 750 /etc/proftpd >> $logsINST 2>&1
                    systemctl restart proftpd >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "proftpd уже установлен. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Настраиваем rclocal
                if [ ! -f /etc/rc.local ]; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "rc.local не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo touch /etc/rc.local >> $logsINST 2>&1
                    echo '#!/bin/bash' | sudo tee -a /etc/rc.local >> $logsINST 2>&1
                    echo "/root/iptables_block" | sudo tee -a /etc/rc.local >> $logsINST 2>&1
                    echo "exit 0" | sudo tee -a /etc/rc.local >> $logsINST 2>&1
                    sudo chmod +x /etc/rc.local >> $logsINST 2>&1
                fi

                # Настраиваем iptables
                if dpkg-query -W -f='${Status}' "iptables" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "iptables не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Проверка на наличие файла
                    if [ ! -f /root/iptables_block ]; then
                        sudo touch /root/iptables_block >> $logsINST 2>&1
                        sudo chmod 500 /root/iptables_block >> $logsINST 2>&1
                    else
                        sudo chmod 500 /root/iptables_block >> $logsINST 2>&1
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "iptables уже установлен. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Установка SteamCMD
                if [ ! -d "/path/cmd" ]; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "steamcmd не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo groupmod -g 998 `cat /etc/group | grep :1000 | awk -F":" '{print $1}'` >> $logsINST 2>&1
                    sudo groupadd -g 1000 servers >> $logsINST 2>&1

                    sudo mkdir -p /path /path/cmd /path/update /path/maps >> $logsINST 2>&1
                    sudo chmod -R 755 /path >> $logsINST 2>&1
                    sudo chown root:servers /path >> $logsINST 2>&1

                    sudo mkdir -p /servers >> $logsINST 2>&1
                    sudo chmod -R 711 /servers >> $logsINST 2>&1
                    sudo chown root:servers /servers >> $logsINST 2>&1

                    sudo mkdir -p /copy >> $logsINST 2>&1
                    sudo chmod -R 750 /copy >> $logsINST 2>&1
                    sudo chown root:root /copy >> $logsINST 2>&1

                    sudo sudo curl -SL -o steamcmd_linux.tar.gz http://media.steampowered.com/client/steamcmd_linux.tar.gz >> $logsINST 2>&1
                    sudo tar -xzf steamcmd_linux.tar.gz -C /path/cmd >> $logsINST 2>&1
                    sudo rm steamcmd_linux.tar.gz >> $logsINST 2>&1
                    sudo chmod +x /path/cmd/steamcmd.sh >> $logsINST 2>&1
                    sudo /path/cmd/steamcmd.sh +quit >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "steamcmd уже установлен. Продолжение установки невозможно...." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi
                echo "===================================" | tee -a $saveDIR
                echo "Данные локации" | tee -a $saveDIR
                echo "SQL_Username: root" | tee -a $saveDIR
                echo "SQL_Password: $passMySQL" | tee -a $saveDIR
                echo "SQL_FileTP: ftp" | tee -a $saveDIR
                echo "SQL_Port: 3306" | tee -a $saveDIR
                echo "Password for FTP database: $passProFTPD" | tee -a $saveDIR
                echo "===================================" | tee -a $saveDIR
                read -p "Нажмите Enter для завершения..."
                continue
            else
                echo "===================================" >> $logsINST 2>&1
                echo "Вы используете неподдерживаемую версию Linux" | tee -a $logsINST
                echo "===================================" >> $logsINST 2>&1
                read -p "Нажмите Enter для завершения..."
            fi
            ;;
        3)
            clear
            # Игровой репозиторий
            gamesURL="http://gs.enginegp.ru"

            echo "Меню установки игровых сборок:"
            echo "1. Counter-Strike: 1.6"
            echo "2. Counter-Strike: Source v34 (old)"
            echo "3. Counter-Strike: Source (new)"
            echo "4. Counter-Strike: Global Offensive"
            echo "5. Counter-Strike: 2"
            echo "6. Grand Theft Auto: San Andreas MultiPlayer"
            echo "7. Grand Theft Auto: Criminal Russia MultiPlayer"
            echo "8. Grand Theft Auto: Multi Theft Auto"
            echo "9. Minecraft Java Edition"
            echo "10. RUST"
            echo "0. Вернуться в предыдущее меню"

            read -p "Выберите пункт меню: " game_choice

            case $game_choice in
                1)
                    clear
                    mkdir -p /path/cs /path/update/cs /path/maps/cs /servers/cs >> $logsINST 2>&1
                    echo "Меню установки Counter-Strike: 1.6"
                    echo "1. Steam [Clean server]"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " cs16_choice

                    case $cs16_choice in
                        1)
                            mkdir -p /path/cs/steam 2>&1 | tee -a ${logsINST}
                            sudo /path/cmd/steamcmd.sh +force_install_dir /path/cs/steam +login anonymous +app_update 90 -beta beta validate +quit 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        0)
                            game_choice
                            ;;
                        *)
                            clear
                            echo "===================================" >> $logsINST 2>&1
                            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                            echo "===================================" >> $logsINST 2>&1
                            ;;
                    esac
                    ;;
                2)
                    clear
                    mkdir -p /path/cssold /path/update/cssold /path/maps/cssold /servers/cssold >> $logsINST 2>&1
                    echo "Меню установки Counter-Strike: Source v34"
                    echo "1. Steam [Clean server]"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " css34_choice

                    case $css34_choice in
                        1)
                            mkdir -p /path/cssold/steam 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cssold/steam/steam.zip $gamesURL/cssold/steam.zip 2>&1 | tee -a ${logsINST}
                            sudo unzip /path/cssold/steam/steam.zip -d /path/cssold/steam/ 2>&1 | tee -a ${logsINST}
                            sudo rm /path/cssold/steam/steam.zip | tee -a $logsINST 2>&1 | tee -a ${logsINST}
                            css34_choice
                            ;;
                        0)
                            game_choice
                            ;;
                        *)
                            clear
                            echo "===================================" >> $logsINST 2>&1
                            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                            echo "===================================" >> $logsINST 2>&1
                            ;;
                    esac
                    ;;
                3)
                    clear
                    mkdir -p /path/css /path/update/css /path/maps/css /servers/css >> $logsINST 2>&1
                    echo "Меню установки Counter-Strike: Source"
                    echo "1. Steam [Clean server]"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " css_choice

                    case $css_choice in
                        1)
                            mkdir -p /path/css/steam 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/css/steam/steam.zip $gamesURL/css/steam.zip 2>&1 | tee -a ${logsINST}
                            sudo unzip /path/css/steam/steam.zip -d /path/css/steam/ 2>&1 | tee -a ${logsINST}
                            sudo rm /path/css/steam/steam.zip | tee -a $logsINST 2>&1 | tee -a ${logsINST}
                            css_choice
                            ;;
                        0)
                            game_choice
                            ;;
                        *)
                            clear
                            echo "===================================" >> $logsINST 2>&1
                            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                            echo "===================================" >> $logsINST 2>&1
                            ;;
                    esac
                    ;;
                4)
                    clear
                    mkdir -p /path/csgo /path/update/csgo /path/maps/csgo /servers/csgo >> $logsINST 2>&1
                    echo "Меню установки Counter-Strike: GO"
                    echo "1. Steam [Clean server]"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " csgo_choice

                    case $csgo_choice in
                        1)
                            mkdir -p /path/csgo/steam 2>&1 | tee -a ${logsINST}
                            /path/cmd/steamcmd.sh +force_install_dir /path/csgo/steam +login anonymous +app_update 740 validate +quit 2>&1 | tee -a ${logsINST}
                            csgo_choice
                            ;;
                        0)
                            game_choice
                            ;;
                        *)
                            clear
                            echo "===================================" >> $logsINST 2>&1
                            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                            echo "===================================" >> $logsINST 2>&1
                            ;;
                    esac
                    ;;
                5)
                    clear
                    mkdir -p /path/cs2 /path/update/cs2 /path/maps/cs2 /servers/cs2 >> $logsINST 2>&1
                    echo "Меню установки Counter-Strike: 2"
                    echo "1. Steam [Clean server]"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " cs2_choice

                    case $cs2_choice in
                        1)
                            mkdir -p /path/cs2/steam 2>&1 | tee -a ${logsINST}
                            /path/cmd/steamcmd.sh +force_install_dir /path/cs2/steam +login anonymous +app_update 730 validate +quit 2>&1 | tee -a ${logsINST}
                            cs2_choice
                            ;;
                        0)
                            game_choice
                            ;;
                        *)
                            clear
                            echo "===================================" >> $logsINST 2>&1
                            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                            echo "===================================" >> $logsINST 2>&1
                            ;;
                    esac
                    ;;
                6)
                    # Add code for installing MTA game here
                    ;;
                7)
                    # Add code for installing MTA game here
                    ;;
                8)
                    # Add code for installing MTA game here
                    ;;
                9)
                    # Add code for installing MTA game here
                    ;;
                10)
                    clear
                    mkdir -p /path/rust /path/update/rust /servers/rust
                    echo "Меню установки RUST"
                    echo "1. Steam [Clean server]"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " rust_choice
                    case $rust_choice in
                        1)
                            clear
                            mkdir -p /path/rust/steam 2>&1 | tee -a ${logsINST}
                            sudo /path/cmd/steamcmd.sh +force_install_dir /path/rust/steam +login anonymous +app_update 258550 validate +quit 2>&1 | tee -a ${logsINST}
                            rust_choice
                            ;;
                        0)
                            game_choice
                            ;;
                        *)
                            clear
                            echo "===================================" >> $logsINST 2>&1
                            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                            echo "===================================" >> $logsINST 2>&1
                            ;;
                    esac
                    ;;
                0)
                    choice
                    ;;
                *)
                    clear
                    echo "===================================" >> $logsINST 2>&1
                    echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    ;;
            esac
            ;;
        4)
            clear
            echo "===================================" >> $logsINST 2>&1
            echo "Текущая версия Linux: $currOS" | tee -a $logsINST
            echo "Внешний IP-адрес: $sysIP" | tee -a $logsINST
            echo "Версия php: $verPHP" | tee -a $logsINST
            echo "Ветка GIT: $gitEGP" | tee -a $logsINST
            echo "===================================" >> $logsINST 2>&1
            read -p "Нажмите Enter для выхода в главное меню..."
            continue
            ;;
        0)
            clear
            echo "===================================" >> $logsINST 2>&1
            echo "До свидания!" | tee -a $logsINST
            echo "===================================" >> $logsINST 2>&1
            exit 0
            ;;
        *)
            clear
            echo "===================================" >> $logsINST 2>&1
            echo "Неверный выбор. Попробуйте еще раз." | tee -a $logsINST
            echo "===================================" >> $logsINST 2>&1
            ;;
    esac

    echo "===================================" >> $logsINST 2>&1
    echo "Нажмите Enter, чтобы продолжить..." | tee -a $logsINST
    echo "===================================" >> $logsINST 2>&1
done