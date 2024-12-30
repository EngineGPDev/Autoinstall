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

# Очистка экрана перед установкой
clear

# User verification
if [ "$(whoami)" != "root" ]; then
    echo "It needs to be run under the root user!" 2>&1 | tee -a "$logsInst"
    exit 1
fi

# Обновление таблиц и системы
sysUpdate (){
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    echo "Обновление системы..." | tee -a "$logsInst"
    echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y update 2>&1 | tee -a "$logsInst" > /dev/null
    apt-get -y dist-upgrade 2>&1 | tee -a "$logsInst" > /dev/null
}

# Создаём переменную для логов
logsInst="/var/log/enginegp_install.log"

# Файл сохранения данных
saveFile="/root/enginegp.cfg"

# Обновление системы
sysUpdate

# Установка начальных пакетов.
pkgsReq=("sudo" "curl" "lsb-release" "wget" "gnupg" "pwgen" "zip" "unzip" "bc" "tar" "software-properties-common" "git" "jq" "openssl")

# Цикл установки пакетов
for package in "${pkgsReq[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
        echo "$package не установлен. Выполняется установка..."  | tee -a "$logsInst"
        echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
        apt-get install -y "$package" 2>&1 | tee -a "$logsInst" > /dev/null
    fi
done

# Массив с поддерживаемыми версиями операционной системы
suppOs=("Debian 11" "Debian 12" "Ubuntu 22.04" "Ubuntu 24.04")
repoExp=$("*.list" "*.sources")

# Получаем текущую версию операционной системы
disOs=$(lsb_release -si)
relOs=$(lsb_release -sr)
currOs="$disOs $relOs"

# Проверка, есть ли currOs в массиве suppOs
foundOs=false
for os in "${suppOs[@]}"; do
    if [[ "$os" == "$currOs" ]]; then
        foundOs=true
        break
    fi
done

# Переменные для хранения
verPhp="8.2"
sysIp=$(ip a | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v '127.0.0.1' | head -n 1)
relType="beta"

# Проверка аргументов командной строки
if [ $# -gt 0 ]; then
    # Перебор всех аргументов
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            --php)
                # Если передан аргумент --php, сохранить указанную версию PHP
                verPhp="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --php
                ;;
            --ip)
                # Если передан аргумент --ip, сохранить указанный IP-адрес
                sysIp="$2"
                shift # Пропустить значение IP-адреса
                shift # Пропустить аргумент --ip
                ;;
            --release)
                relType="release"
                shift # Пропустить аргумент --release
                ;;
            --beta)
                relType="beta"
                shift # Пропустить аргумент --beta
                ;;
            --snapshot)
                relType="snapshot"
                shift # Пропустить аргумент --snapshot
                ;;
            *)
                # Неизвестный аргумент, вывести справку и выйти
                clear
                echo "Использование: ./install.sh --php 8.2 --ip 192.168.1.1 --release"
                echo "  --php версия: установить указанную версию PHP. Формат должен быть: 8.2"
                echo "  --ip IP-адрес: использовать указанный IP-адрес. Формат должен быть: 192.168.1.1"
                echo "  --release: установить последнюю, стабильную версию"
                echo "  --beta: установить последнюю, бета-версию"
                echo "  --snapshot: установить последний snapshot"
                exit 1
                ;;
        esac
    done
fi

# Проверяем, является ли полученный IP-адрес действительным IPv4 адресом
if [[ ! $sysIp =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
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
    echo "3. Установка игровых серверов"
    echo "4. Системная информация"
    echo "0. Выход"

    read -rp "Выберите пункт меню: " choice

    case $choice in
        1)
            clear
            # Проверяем, содержится ли текущая версия в массиве поддерживаемых версий
            if $foundOs; then
                # Проверяем наличие репозитория php
                if [[ " ${disOs} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/php.list" ]; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Репозиторий php не обнаружен. Добавляем..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        # Скачиваем ключа зеркала репозитория Sury
                        curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://mirror.enginegp.com/sury/debsuryorg-archive-keyring.deb 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Устанавливаем ключа зеркала репозитория Sury
                        sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Добавляем репозиторий php
                        sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-php.gpg] https://mirror.enginegp.com/sury/php/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/php.list' 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Обновление таблиц и пакетов
                        sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get -y dist-upgrade 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Определяем версию php по умолчанию
                        defPhp=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                    fi
                else
                    foundExp=false

                    # Проверяем наличие каждого файла
                    for exp in "${repoExp[@]}"; do
                        if [ ! -f "/etc/apt/sources.list.d/ondrej-ubuntu-php-$exp" ]; then
                            foundExp=true
                        fi
                    done

                    if [ "$foundExp" = false ]; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Репозиторий php не обнаружен. Добавляем..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        # Добавляем репозиторий php
                        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/php -y 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Обновление таблиц и пакетов
                        sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get -y dist-upgrade 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Определяем версию php по умолчанию
                        defPhp=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                    fi
                fi

                # Проверяем наличие репозитория nginx
                if [[ " ${disOs} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/nginx.list" ]; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        # Скачиваем ключа зеркала репозитория Sury
                        curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://mirror.enginegp.com/sury/debsuryorg-archive-keyring.deb 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Устанавливаем ключа зеркала репозитория Sury
                        sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Добавляем репозиторий nginx
                        sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-nginx.gpg] https://mirror.enginegp.com/sury/nginx/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/nginx.list' 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Обновление таблиц и пакетов
                        sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get -y dist-upgrade 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                else
                    foundExp=false

                    # Проверяем наличие каждого файла
                    for exp in "${repoExp[@]}"; do
                        if [ ! -f "/etc/apt/sources.list.d/ondrej-ubuntu-nginx-$exp" ]; then
                            foundExp=true
                        fi
                    done

                    if [ "$foundExp" = false ]; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        # Добавляем репозиторий nginx
                        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx -y 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Обновление таблиц и пакетов
                        sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get -y dist-upgrade 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                fi

                # Список пакетов для установки
                pkgsList=("php$verPhp-fpm" "php$verPhp-common" "php$verPhp-cli" "php$verPhp-memcache" "php$verPhp-mysql" "php$verPhp-xml" "php$verPhp-mbstring" "php$verPhp-gd" "php$verPhp-imagick" "php$verPhp-zip" "php$verPhp-curl" "php$verPhp-gmp" "php$verPhp-bz2" "nginx" "mariadb-server" "ufw" "memcached" "screen" "tmux" "cron")
                pkgsPma=("php$defPhp-fpm" "php$defPhp-mbstring" "php$defPhp-zip" "php$defPhp-gd" "php$defPhp-json" "php$defPhp-curl")

                # Генерирование паролей и имён
                passPma=$(pwgen -cns -1 16)
                cronKey=$(pwgen -cns -1 12)
                jwtKey=$(openssl rand -base64 32)
                userEgpSql="enginegp_$(pwgen -cns -1 8)"
                dbEgpSql="enginegp_$(pwgen -1 8)"
                passEgpSql=$(pwgen -cns -1 16)
                usrEgpPass=$(pwgen -cns -1 16)

                # Конфигурация nginx для EngineGP
                nginx_enginegp="server {
    listen 80;
    server_name $sysIp;

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

    location ~ /\.ht|\.en {
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
        fastcgi_pass unix:/run/php/php$verPhp-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}"

                # Конфигурация nginx для phpMyAdmin
                nginx_phpmyadmin="server {
    listen 9090;
    server_name $sysIp;

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
        fastcgi_pass unix:/run/php/php$defPhp-fpm.sock;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
    }
}"
                # Задачи CRON
                cronTasks="#
# Default Crontab by EngineGP
* * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads scan_servers_admins'
* * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads scan_servers_down'
*/2 * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads scan_servers'
*/15 * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads scan_servers_stop'
*/15 * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads scan_servers_copy'
0 */1 * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads graph_servers_hour'
0 0 */1 * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey threads graph_servers_day'
*/10 * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey notice_help'
*/30 * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey notice_server_overdue'
*/30 * * * * bash -c 'cd /var/www/enginegp/ && php cron.php $cronKey preparing_web_delete'
# Default Crontab by EngineGP
#"

                # Цикл установки пакетов
                for package in "${pkgsList[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "$package не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                done

                # Цикл установки пакетов
                for package in "${pkgsPma[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "$package не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                done

                # Установка phpMyAdmin
                if ! dpkg-query -W -f='${Status}' "phpmyadmin" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "phpmyadmin не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo debconf-set-selections <<EOF
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/mysql/app-pass password $passPma
phpmyadmin phpmyadmin/password-confirm password $passPma
phpmyadmin phpmyadmin/reconfigure-webserver multiselect
EOF
                    sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y phpmyadmin 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo -e "$nginx_phpmyadmin" | sudo tee /etc/nginx/sites-available/00-phpmyadmin.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo ln -s /etc/nginx/sites-available/00-phpmyadmin.conf /etc/nginx/sites-enabled/ 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo systemctl restart nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "phpmyadmin уже установлен в системе. Продолжение установки невозможно." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi

                # Установка версии php по умолчанию
                if [[ "$(php -v | grep -oP '(?<=PHP )(\d+\.\d+)')" != "$verPhp" ]]; then
                    sudo update-alternatives --set php /usr/bin/php"$verPhp" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo update-alternatives --set php-config /usr/bin/php-config"$verPhp" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo update-alternatives --set phpdbg /usr/bin/phpdbg"$verPhp" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo update-alternatives --set phpize /usr/bin/phpize"$verPhp" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi

                # Проверяем установку php-fpm по умолчанию
                if dpkg-query -W -f='${Status}' "php$defPhp-fpm" 2>/dev/null | grep -q "install ok installed"; then
                    if ! systemctl is-active --quiet php"$defPhp"-fpm; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "php$defPhp-fpm не запущен. Выполняется запуск..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo systemctl start php"$defPhp"-fpm 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                fi

                # Проверяем установку php-fpm для EngineGP
                if dpkg-query -W -f='${Status}' "php$verPhp-fpm" 2>/dev/null | grep -q "install ok installed"; then
                    if ! systemctl is-active --quiet php"$verPhp"-fpm; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "php$verPhp-fpm не запущен. Выполняется запуск..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo systemctl start php"$verPhp"-fpm 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                fi

                # Установка и настрока composer
                if [ ! -f "/usr/local/bin/composer" ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "composer не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    curl -sSL https://getcomposer.org/installer | sudo php -- --install-dir=/usr/local/bin --filename=composer 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi

                # Установка EngineGP
                if [ ! -d "/var/www/enginegp" ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "enginegp не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    # Создание временного каталога
                    sudo mkdir -p /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Загрузка EngineGP
                    if [ "$relType" == "snapshot" ]; then
                        sudo git clone --depth 1 --branch main https://github.com/EngineGPDev/EngineGP.git /var/www/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null                        
                    elif [ "$relType" == "beta" ]; then
                        curl -s https://api.github.com/repos/EngineGPDev/EngineGP/releases | jq -r 'map(select(.prerelease == true)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/enginegp/enginegp.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo unzip -o /tmp/enginegp/enginegp.zip -d /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo mv /tmp/enginegp/EngineGPDev-EngineGP-* /var/www/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    else
                        curl -s https://api.github.com/repos/EngineGPDev/EngineGP/releases | jq -r 'map(select(.prerelease == false)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/enginegp/enginegp.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo unzip -o /tmp/enginegp/enginegp.zip -d /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo mv /tmp/enginegp/EngineGPDev-EngineGP-* /var/www/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi

                    # Очищаем временную папку
                    sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Установка зависимостей composer
                    sudo COMPOSER_ALLOW_SUPERUSER=1 composer install --working-dir=/var/www/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Хэширование пароля пользователя перед записью в базу данных
                    usrEgpHASH=$(php"$verPhp" -r "echo password_hash('$usrEgpPass', PASSWORD_DEFAULT);")

                    # Настраиваем конфигурацию панели
                    sudo mv /var/www/enginegp/.env.example /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/APP_URL=\"example.com\"/APP_URL=\"$sysIp\"/g" /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/APP_CRONKEY=\"enginegp_ck\"/APP_CRONKEY=\"$cronKey\"/g" /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/JWT_KEY=\"jwt_key\"/JWT_KEY=\"$jwtKey\"/g" /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/DB_DATABASE=\"enginegp_db\"/DB_DATABASE=\"$dbEgpSql\"/g" /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/DB_USERNAME=\"enginegp_usr\"/DB_USERNAME=\"$userEgpSql\"/g" /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/DB_PASSWORD=\"enginegp_pwd\"/DB_PASSWORD=\"$passEgpSql\"/g" /var/www/enginegp/.env 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i "s/ENGINEGPHASH/$(echo "$usrEgpHASH" | sed 's/[\/&]/\\&/g')/g" /var/www/enginegp/enginegp.sql 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Создание пользователя
                    sudo mysql -e "CREATE USER '$userEgpSql'@'localhost' IDENTIFIED BY '$passEgpSql';" 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Создание базы данных
                    sudo mysql -e "CREATE DATABASE $dbEgpSql CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    
                    # Предоставление привилегий пользователю на базу данных
                    sudo mysql -e "GRANT ALL PRIVILEGES ON $dbEgpSql.* TO '$userEgpSql'@'localhost';" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    
                    # Применение изменений привилегий
                    sudo mysql -e "FLUSH PRIVILEGES;" 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Экспорт базы данных
                    { sudo cat /var/www/enginegp/enginegp.sql | sudo mysql -u "$userEgpSql" -p"$passEgpSql" "$dbEgpSql"; } 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    rm /var/www/enginegp/enginegp.sql 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Устанавливаем задачи CRON
                    { (sudo crontab -l; echo "$cronTasks") | sudo crontab -; } 2>&1 | sudo tee -a "$logsInst" > /dev/null
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "enginegp уже установлен в системе. Продолжение установки невозможно." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi

                # Выставляем права на каталог и файлы
                sudo chown -R www-data:www-data /var/www/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo find /var/www/enginegp -type f -exec chmod 644 {} \; 2>&1 | sudo tee -a "$logsInst" > /dev/null
                sudo find /var/www/enginegp -type d -exec chmod 755 {} \; 2>&1 | sudo tee -a "$logsInst" > /dev/null

                # Настраиваем nginx
                if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "nginx не настроен. Выполняется настройка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    # Удаляем дефолтный и создаём конфиг EngineGP
                    sudo rm /etc/nginx/sites-enabled/default 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo -e "$nginx_enginegp" | sudo tee /etc/nginx/sites-available/01-enginegp.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo ln -s /etc/nginx/sites-available/01-enginegp.conf /etc/nginx/sites-enabled/ 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo systemctl restart nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "NGINX не установлен. Продолжение установки невозможно." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi

                # Сообщение о завершении установки
                echo "===================================" | sudo tee -a $saveFile
                echo "Установка завершена!" | sudo tee -a $saveFile
                echo "Ссылка на EngineGP: http://$sysIp/" | sudo tee -a $saveFile
                echo "Пользователь: admin" | sudo tee -a $saveFile
                echo "Пароль: $usrEgpPass" | sudo tee -a $saveFile
                echo "===================================" | sudo tee -a $saveFile
                echo "MySQL данные для EngineGP" | sudo tee -a $saveFile
                echo "Ссылка на phpMyAdmin: http://$sysIp:9090/" | sudo tee -a $saveFile
                echo "База данных: $dbEgpSql" | sudo tee -a $saveFile
                echo "Пользователь: $userEgpSql" | sudo tee -a $saveFile
                echo "Пароль: $passEgpSql" | sudo tee -a $saveFile
                echo "===================================" | sudo tee -a $saveFile
                echo "Системные данные MySQL" | sudo tee -a $saveFile
                echo "Пароль пользователя phpmyadmin: $passPma" | sudo tee -a $saveFile
                echo "===================================" | sudo tee -a $saveFile
                read -rp "Нажмите Enter для завершения..."
                continue
            else
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "Вы используете неподдерживаемую версию Linux" | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                read -rp "Нажмите Enter для завершения..."
            fi
            ;;
        2)
            clear

            dbProFTPD="ftp_$(pwgen -cns -1 8)"
            userProFTPD="ftp_$(pwgen -cns -1 8)"
            passProFTPD=$(pwgen -cns -1 16)

            # Проверяем, содержится ли текущая версия в массиве поддерживаемых версий
            if $foundOs; then
                # Проверяем наличие репозитория nginx
                if [[ " ${disOs} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/nginx.list" ]; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        # Скачиваем ключа зеркала репозитория Sury
                        curl -sSLo /tmp/debsuryorg-archive-keyring.deb https://mirror.enginegp.com/sury/debsuryorg-archive-keyring.deb 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Устанавливаем ключа зеркала репозитория Sury
                        sudo dpkg -i /tmp/debsuryorg-archive-keyring.deb 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Добавляем репозиторий nginx
                        sh -c 'echo "deb [signed-by=/usr/share/keyrings/deb.sury.org-nginx.gpg] https://mirror.enginegp.com/sury/nginx/ $(lsb_release -sc) main" > /etc/apt/sources.list.d/nginx.list' 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Обновление таблиц и пакетов
                        sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get -y dist-upgrade 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                else
                    foundExp=false

                    # Проверяем наличие каждого файла
                    for exp in "${repoExp[@]}"; do
                        if [ ! -f "/etc/apt/sources.list.d/ondrej-ubuntu-nginx-$exp" ]; then
                            foundExp=true
                        fi
                    done

                    if [ "$foundExp" = false ]; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        # Добавляем репозиторий nginx
                        sudo LC_ALL=C.UTF-8 add-apt-repository ppa:ondrej/nginx -y 2>&1 | sudo tee -a "$logsInst" > /dev/null

                        # Обновление таблиц и пакетов
                        sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get -y dist-upgrade 2>&1 | sudo tee -a "$logsInst" > /dev/null
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

                pkgsLOC=("glibc-source" "lib32z1" "libbabeltrace1" "libc6-dbg" "libdw1" "lib32stdc++6" "libreadline8" "lib32gcc-s1" "libtinfo5:i386" "screen" "tmux" "tcpdump" "lsof" "qstat" "gdb-minimal" "ntpdate" "gcc-multilib" "iptables" "default-jdk" "nginx" "mariadb-server")

                if ! dpkg --print-foreign-architectures | grep -q "i386"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "Архитектура i386 не добавлена. Выполняется добавление..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo dpkg --add-architecture i386 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Обновление таблиц
                    sudo apt-get -y update 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi

                # Цикл установки пакетов
                for package in "${pkgsLOC[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "$package не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                done

                # Настраиваем FastDL
                if [ ! -f /etc/nginx/sites-available/02-fastdl.conf ]; then
                    # Создаём каталог и выдаём ему права
                    sudo mkdir -p /var/nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chmod -R 755 /var/nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "fastdl не настроен. Выполняется настройка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    # Удаляем дефолтный конфиг и создаём для FastDL
                    sudo rm /etc/nginx/sites-enabled/default 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo -e "$nginx_fastdl" | sudo tee /etc/nginx/sites-available/02-fastdl.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo ln -s /etc/nginx/sites-available/02-fastdl.conf /etc/nginx/sites-enabled/ 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo systemctl restart nginx 2>&1 | sudo tee -a "$logsInst" > /dev/null
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "fastdl не установлен. Продолжение установки невозможно." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi

                # Устанавливаем ProFTPD
                if ! dpkg-query -W -f='${Status}' "proftpd" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "proftpd не установлен. Выполняется установка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Устанавливаем ProFTPD и необходимые модули
                    echo "proftpd shared/proftpd/inetd_or_standalone select standalone" | debconf-set-selections
                    sudo apt-get install -y proftpd-basic proftpd-mod-mysql 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Создание временного каталога
                    sudo mkdir -p /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Скачиваем конфигурационные файлы ProFTPD
                    curl -s https://api.github.com/repos/EngineGPDev/ProFTPD/releases | jq -r 'map(select(.prerelease == false)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/enginegp/proftpd.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo unzip -o /tmp/enginegp/proftpd.zip -d /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo mv /tmp/enginegp/EngineGPDev-ProFTPD-*/proftpd.conf /etc/proftpd/proftpd.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo mv /tmp/enginegp/EngineGPDev-ProFTPD-*/modules.conf /etc/proftpd/modules.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo mv /tmp/enginegp/EngineGPDev-ProFTPD-*/sql.conf /etc/proftpd/sql.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Создаем базу данных для ProFTPD
                    sudo mysql -e "CREATE DATABASE $dbProFTPD CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Создаем пользователя для ProFTPD и предоставляем ему все права на базу данных
                    sudo mysql -e "CREATE USER '$userProFTPD'@'localhost' IDENTIFIED BY '$passProFTPD';" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo mysql -e "GRANT ALL PRIVILEGES ON $dbProFTPD . * TO '$userProFTPD'@'localhost';" 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Импортируем дамп базы данных для ProFTPD
                    { sudo cat /tmp/enginegp/EngineGPDev-ProFTPD-*/proftpd.sql | sudo mysql -u "$userProFTPD" -p"$passProFTPD" "$dbProFTPD"; } 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Очищаем временную папку
                    sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Вносим даннык в конфигурационный файл
                    sed -i 's/__FTP_DATABASE__/'"$dbProFTPD"'/g' /etc/proftpd/sql.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i 's/__FTP_USER__/'"$userProFTPD"'/g' /etc/proftpd/sql.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sed -i 's/__FTP_PASSWORD__/'"$passProFTPD"'/g' /etc/proftpd/sql.conf 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Устанавливаем права доступа на конфигурационные файлы
                    chmod -R 750 /etc/proftpd 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    # Перезапускаем ProFTPD для применения изменений
                    systemctl restart proftpd 2>&1 | sudo tee -a "$logsInst" > /dev/null
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "proftpd уже установлен. Продолжение установки невозможно." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi

                # Настраиваем rclocal
                if [ ! -f /etc/rc.local ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "rc.local не настроен. Выполняется настройка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo touch /etc/rc.local 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo '#!/bin/bash' | sudo tee -a /etc/rc.local 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "/root/iptables_block" | sudo tee -a /etc/rc.local 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "exit 0" | sudo tee -a /etc/rc.local 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chmod +x /etc/rc.local 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi

                # Настраиваем iptables
                if dpkg-query -W -f='${Status}' "iptables" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "iptables не настроен. Выполняется настройка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    # Проверка на наличие файла
                    if [ ! -f /root/iptables_block ]; then
                        sudo touch /root/iptables_block 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        sudo chmod 500 /root/iptables_block 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    else
                        sudo chmod 500 /root/iptables_block 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    fi
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "iptables уже установлен. Продолжение установки невозможно." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi

                # Установка SteamCMD
                if [ ! -d "/path/cmd" ]; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "steamcmd не настроен. Выполняется настройка..." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo groupadd -f servers 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    sudo mkdir -p /path /path/cmd /path/update /path/maps 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chmod -R 755 /path 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chown root:servers /path 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    sudo mkdir -p /servers 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chmod -R 711 /servers 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chown root:servers /servers 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    sudo mkdir -p /copy 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chmod -R 750 /copy 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chown root:root /copy 2>&1 | sudo tee -a "$logsInst" > /dev/null

                    curl -SL -o steamcmd_linux.tar.gz http://media.steampowered.com/client/steamcmd_linux.tar.gz 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo tar -xzf steamcmd_linux.tar.gz -C /path/cmd 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo rm steamcmd_linux.tar.gz 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo chmod +x /path/cmd/steamcmd.sh 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo /path/cmd/steamcmd.sh +quit 2>&1 | sudo tee -a "$logsInst" > /dev/null
                else
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "steamcmd уже установлен. Продолжение установки невозможно...." | sudo tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    read -rp "Нажмите Enter для завершения..."
                    continue
                fi
                echo "===================================" | sudo tee -a $saveFile
                echo "Данные локации" | sudo tee -a $saveFile
                echo "Пользователь ProFTPD: $userProFTPD" | sudo tee -a $saveFile
                echo "Пароль ProFTPD: $passProFTPD" | sudo tee -a $saveFile
                echo "База данных ProFTPD: $dbProFTPD" | sudo tee -a $saveFile
                echo "Порт базы данных: 3306" | sudo tee -a $saveFile
                echo "===================================" | sudo tee -a $saveFile
                read -rp "Нажмите Enter для завершения..."
                continue
            else
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                echo "Вы используете неподдерживаемую версию Linux" | sudo tee -a "$logsInst"
                echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                read -rp "Нажмите Enter для завершения..."
            fi
            ;;
        3)
            game_menu() {
                clear
                # Игровой репозиторий
                gamesURL="http://gs.enginegp.ru"

                echo "Меню установки игровых серверов:"
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

                read -rp "Выберите пункт меню: " game_choice

                case $game_choice in
                    1)
                        cs16_menu() {
                            while true; do
                                clear
                                mkdir -p /path/cs /path/update/cs /path/maps/cs /servers/cs 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки Counter-Strike: 1.6"
                                echo "1. Steam"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " cs16_choice

                                case $cs16_choice in
                                    1)
                                        mkdir -p /path/cs/steam 2>&1 | sudo tee -a "${logsInst}"
                                        sudo /path/cmd/steamcmd.sh +force_install_dir /path/cs/steam +login anonymous +app_update 90 -beta beta validate +quit 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        cs16_menu
                        ;;
                    2)
                        cssold_menu() {
                            while true; do
                                clear
                                mkdir -p /path/cssold /path/update/cssold /path/maps/cssold /servers/cssold 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки Counter-Strike: Source v34"
                                echo "1. Steam"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " css34_choice

                                case $css34_choice in
                                    1)
                                        mkdir -p /path/cssold/steam 2>&1 | tee -a "${logsInst}"
                                        curl -SL -o /path/cssold/steam/steam.zip $gamesURL/cssold/steam.zip 2>&1 | sudo tee -a "${logsInst}"
                                        sudo unzip -o /path/cssold/steam/steam.zip -d /path/cssold/steam/ 2>&1 | sudo tee -a "${logsInst}"
                                        sudo rm /path/cssold/steam/steam.zip 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        cssold_menu
                        ;;
                    3)
                        css_menu() {
                            while true; do
                                clear
                                mkdir -p /path/css /path/update/css /path/maps/css /servers/css 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки Counter-Strike: Source"
                                echo "1. Steam"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " css_choice

                                case $css_choice in
                                    1)
                                        mkdir -p /path/css/steam 2>&1 | sudo tee -a "${logsInst}"
                                        /path/cmd/steamcmd.sh +force_install_dir /path/css/steam +login anonymous +app_update 232330 validate +quit 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        css_menu
                        ;;
                    4)
                        csgo_menu() {
                            while true; do
                                clear
                                mkdir -p /path/csgo /path/update/csgo /path/maps/csgo /servers/csgo 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки Counter-Strike: GO"
                                echo "1. Steam"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " csgo_choice

                                case $csgo_choice in
                                    1)
                                        mkdir -p /path/csgo/steam 2>&1 | sudo tee -a "${logsInst}"
                                        /path/cmd/steamcmd.sh +force_install_dir /path/csgo/steam +login anonymous +app_update 740 validate +quit 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        csgo_menu
                        ;;
                    5)
                        cs2_menu() {
                            while true; do
                                clear
                                mkdir -p /path/cs2 /path/update/cs2 /path/maps/cs2 /servers/cs2 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки Counter-Strike: 2"
                                echo "1. Steam"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " cs2_choice

                                case $cs2_choice in
                                    1)
                                        mkdir -p /path/cs2/steam 2>&1 | sudo tee -a "${logsInst}"
                                        /path/cmd/steamcmd.sh +force_install_dir /path/cs2/steam +login anonymous +app_update 730 validate +quit 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        cs2_menu
                        ;;
                    6)
                        samp_menu() {
                            while true; do
                                clear
                                mkdir -p /path/samp /path/update/samp /path/maps/samp /servers/samp /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки GTA: SAMP"
                                echo "1. 0.3.7-R2"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " samp_choice

                                case $samp_choice in
                                    1)
                                        curl -SL -o /tmp/enginegp/samp037svr_R2-2-1.tar.gz https://gta-multiplayer.cz/downloads/samp037svr_R2-2-1.tar.gz 2>&1 | sudo tee -a "${logsInst}"
                                        sudo tar -xzf /tmp/enginegp/samp037svr_R2-2-1.tar.gz -C /tmp/enginegp 2>&1 | sudo tee -a "$logsInst"
                                        sudo mv /tmp/enginegp/samp03 /path/samp/037R2 2>&1 | sudo tee -a "$logsInst"
                                        sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        samp_menu
                        ;;
                    7)
                        crmp_menu() {
                            while true; do
                                clear
                                mkdir -p /path/crmp /path/update/crmp /path/maps/crmp /servers/crmp /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки GTA: CRMP"
                                echo "1. 0.3e Rev C3"
                                echo "2. 0.3.7 Rev C5"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " crmp_choice

                                case $crmp_choice in
                                    1)
                                        curl -SL -o /tmp/enginegp/srv-cr-mp-c3-linux.tar.gz https://cr-mp.ru/download/srv-cr-mp-c3-linux.tar.gz 2>&1 | sudo tee -a "${logsInst}"
                                        sudo tar -xzf /tmp/enginegp/srv-cr-mp-c3-linux.tar.gz -C /tmp/enginegp 2>&1 | sudo tee -a "$logsInst"
                                        sudo mv /tmp/enginegp/srv-cr-mp-c3-linux /path/crmp/03eC3 2>&1 | sudo tee -a "$logsInst"
                                        sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                    2)
                                        curl -SL -o /tmp/enginegp/srv-cr-mp-c5-linux.tar.gz https://cr-mp.ru/download/srv-cr-mp-c5-linux.tar.gz 2>&1 | sudo tee -a "${logsInst}"
                                        sudo tar -xzf /tmp/enginegp/srv-cr-mp-c5-linux.tar.gz -C /tmp/enginegp 2>&1 | sudo tee -a "$logsInst"
                                        sudo mv /tmp/enginegp/samp03 /path/crmp/037C5 2>&1 | sudo tee -a "$logsInst"
                                        sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        crmp_menu
                        ;;
                    8)
                        mta_menu() {
                            while true; do
                                clear
                                mkdir -p /path/mta /path/update/mta /path/maps/mta /servers/mta /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки GTA: MTA"
                                echo "1. 1.6.0"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " mta_choice

                                case $mta_choice in
                                    1)
                                        curl -SL -o /tmp/enginegp/multitheftauto_linux_x64.tar.gz https://linux.multitheftauto.com/dl/multitheftauto_linux_x64.tar.gz 2>&1 | sudo tee -a "${logsInst}"
                                        sudo tar -xzf /tmp/enginegp/multitheftauto_linux_x64.tar.gz -C /tmp/enginegp 2>&1 | sudo tee -a "$logsInst"
                                        sudo mv /tmp/enginegp/multitheftauto_linux_x64 /path/mta/160 2>&1 | sudo tee -a "$logsInst"
                                        sudo mv /path/mta/160/mta-server64 /path/mta/160/mta-server 2>&1 | sudo tee -a "$logsInst"
                                        sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        mta_menu
                        ;;
                    9)
                        mc_menu() {
                            while true; do
                                clear
                                mkdir -p /path/mc /path/update/mc /path/maps/mc /servers/mc 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                echo "Меню установки Minecraft"
                                echo "1. PaperSpigot 1.20.4 [Java 17]"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " mc_choice

                                case $mc_choice in
                                    1)
                                        mkdir -p /path/mc/paper1204 2>&1 | sudo tee -a "${logsInst}"
                                        curl -SL -o /path/mc/paper1204/start.jar https://api.papermc.io/v2/projects/paper/versions/1.20.4/builds/497/downloads/paper-1.20.4-497.jar 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        mc_menu
                        ;;
                    10)
                        rust_menu() {
                            while true; do
                                clear
                                mkdir -p /path/rust /path/update/rust /servers/rust
                                echo "Меню установки RUST"
                                echo "1. Steam"
                                echo "0. Вернуться в предыдущее меню"

                                read -rp "Выберите пункт меню: " rust_choice
                                case $rust_choice in
                                    1)
                                        clear
                                        mkdir -p /path/rust/steam 2>&1 | tee -a "${logsInst}"
                                        sudo /path/cmd/steamcmd.sh +force_install_dir /path/rust/steam +login anonymous +app_update 258550 validate +quit 2>&1 | sudo tee -a "${logsInst}"
                                        ;;
                                    0)
                                        break
                                        ;;
                                    *)
                                        clear
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                                        ;;
                                esac
                            done
                        }

                        rust_menu
                        ;;
                    0)
                        break
                        ;;
                    *)
                        clear
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
                        echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                        ;;
                esac
            }

            game_menu
            ;;
        4)
            clear
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Текущая версия Linux: $currOs" | sudo tee -a "$logsInst"
            echo "Внешний IP-адрес: $sysIp" | sudo tee -a "$logsInst"
            echo "Версия php: $verPhp" | sudo tee -a "$logsInst"
            echo "Выпуск EngineGP: $relType" | sudo tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            read -rp "Нажмите Enter для выхода в главное меню..."
            continue
            ;;
        0)
            clear
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "До свидания!" | sudo tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            exit 0
            ;;
        *)
            clear
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Неверный выбор. Попробуйте еще раз." | sudo tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            ;;
    esac

    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
    echo "Нажмите Enter, чтобы продолжить..." | sudo tee -a "$logsInst"
    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
done
