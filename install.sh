#!/bin/bash
##
# EngineGP   (https://enginegp.ru or https://enginegp.com)
#
# @copyright Copyright (c) 2023-present Solovev Sergei <inbox@seansolovev.ru>
# 
# @link      https://github.com/EngineGPDev/Autoinstall for the canonical source repository
# @link      https://gitforge.ru/EngineGP/Autoinstall for the canonical source repository
#
# @license   https://github.com/EngineGPDev/Autoinstall/blob/main/LICENSE MIT License
# @license   https://gitforge.ru/EngineGP/Autoinstall/src/branch/main/LICENSE MIT License
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
suppOS=("Debian 11" "Debian 12" "Ubuntu 22.04")

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
                # Список пакетов для установки
                pkgsLNAMP=(php-fpm php-json php-mbstring php-zip php-gd php-xml php-curl apache2 libapache2-mod-fcgid nginx)
                pkgsEGP=(ufw memcached screen cron php$verPHP-fpm php$verPHP-common php$verPHP-cli php$verPHP-memcache php$verPHP-mysql php$verPHP-xml php$verPHP-mbstring php$verPHP-gd php$verPHP-imagick php$verPHP-zip php$verPHP-curl php$verPHP-ssh2)

                # Установка стека LNAMP + phpMyAdmin
                # Проверяем наличие репозитория php sury
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/php.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий php не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий php
                        sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1

                        # Определяем версию php по умолчанию
                        defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Репозиторий php не обнаружен. Добавляем..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Добавляем репозиторий php
                    sudo add-apt-repository ppa:ondrej/php -y >> $logsINST 2>&1

                    # Обновление таблиц и пакетов
                    apt-get -y update >> $logsINST 2>&1
                    apt-get -y upgrade >> $logsINST 2>&1

                    # Определяем версию php по умолчанию
                    defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                fi

                # Проверяем наличие репозитория apache2 sury
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/apache2.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий apache2 не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий apache2
                        sudo curl -sSL https://packages.sury.org/apache2/README.txt | sudo bash -x >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Репозиторий apache2 не обнаружен. Добавляем..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Добавляем репозиторий apache2
                    sudo add-apt-repository ppa:ondrej/apache2 -y >> $logsINST 2>&1

                    # Обновление таблиц и пакетов
                    apt-get -y update >> $logsINST 2>&1
                    apt-get -y upgrade >> $logsINST 2>&1
                fi

                # Проверяем наличие репозитория nginx sury
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/nginx.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий nginx
                        sudo curl -sSL https://packages.sury.org/nginx/README.txt | sudo bash -x >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Добавляем репозиторий nginx
                    sudo add-apt-repository ppa:ondrej/nginx -y >> $logsINST 2>&1

                    # Обновление таблиц и пакетов
                    apt-get -y update >> $logsINST 2>&1
                    apt-get -y upgrade >> $logsINST 2>&1
                fi

                # Генерирование паролей и имён
                passSQL=$(pwgen -cns -1 16)
                passPMA=$(pwgen -cns -1 16)
                usrEgpSQL="enginegp_$(pwgen -cns -1 8)"
                dbEgpSQL="enginegp_$(pwgen -1 8)"
                passEgpSQL=$(pwgen -cns -1 16)
                usrEgpPASS=$(pwgen -cns -1 16)

                # Конфигурация apache для EngineGP
                apache_enginegp="<VirtualHost 127.0.0.1:81>
     ServerName $sysIP
     DocumentRoot /var/www/enginegp
     DirectoryIndex index.php
     ErrorLog \${APACHE_LOG_DIR}/enginegp.log
     CustomLog \${APACHE_LOG_DIR}/enginegp.log combined

     <Directory /var/www/enginegp>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Require all granted
     </Directory>

    <FilesMatch \.php$>
      SetHandler "proxy:unix:/run/php/php$verPHP-fpm.sock\|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
"
                # Конфигурация apache для EngineGP
                apache_remoteip="RemoteIPHeader X-Real-IP
RemoteIPHeader X-Client-IP
RemoteIPHeader X-Forwarded-For
RemoteIPInternalProxy 127.0.0.1
"

                # Конфигурация nginx для EngineGP
                nginx_enginegp="server {
    listen 80;
    server_name $sysIP;

    location / {
        proxy_pass http://127.0.0.1:81;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
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
}"
                # Конфигурация nginx для phpMyAdmin
                nginx_phpmyadmin="server {
    listen 9090;
    server_name $sysIP;
    
    root /usr/share/phpmyadmin;

    location / {
        index index.php;
        try_files \$uri \$uri/ /index.php;

        location ~ ^/(.+\.php)$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php$defPHP-fpm.sock;
        }

        location ~* ^/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
            root /usr/share/phpmyadmin;
        }
    }

    location ~ /\.ht {
        deny all;
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
                    sudo curl -SLO https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb >> $logsINST 2>&1
                    sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.29-1_all.deb >> $logsINST 2>&1
                    sudo apt-get update >> $logsINST 2>&1
                    sudo rm mysql-apt-config_0.8.29-1_all.deb >> $logsINST 2>&1
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
                for package in "${pkgsLNAMP[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo apt-get install -y "$package" >> $logsINST 2>&1
                    fi
                done

                # Цикл установки пакетов
                for package in "${pkgsEGP[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        apt-get install -y "$package" >> $logsINST 2>&1
                    fi
                done

                # Установка версии php по умолчанию
                if [[ "$(php -v | grep -oP '(?<=PHP )(\d+\.\d+)')" != "$verPHP" ]]; then
                    sudo update-alternatives --set php /usr/bin/php$verPHP >> $logsINST 2>&1
                    sudo update-alternatives --set php-config /usr/bin/php-config$verPHP >> $logsINST 2>&1
                    sudo update-alternatives --set phpdbg /usr/bin/phpdbg$verPHP >> $logsINST 2>&1
                    sudo update-alternatives --set phpize /usr/bin/phpize$verPHP >> $logsINST 2>&1
                fi

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
                    echo -e "$nginx_phpmyadmin" | sudo tee /etc/nginx/sites-available/00-phpmyadmin >> $logsINST 2>&1
                    sudo ln -s /etc/nginx/sites-available/00-phpmyadmin /etc/nginx/sites-enabled/ >> $logsINST 2>&1

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

                # Выставляем права на каталог
                sudo chown -R www-data:www-data /var/www/enginegp >> $logsINST 2>&1
                sudo chmod -R 755 /var/www/enginegp >> $logsINST 2>&1

                # Создание каталога для логов apache и nginx
                sudo mkdir /var/log/enginegp >> $logsINST 2>&1

                # Настраиваем apache
                if dpkg-query -W -f='${Status}' "libapache2-mod-fcgid" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "apache2 не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Разрешаем доступ к портам
                    sudo ufw allow 80 >> $logsINST 2>&1
                    sudo ufw allow 443 >> $logsINST 2>&1

                    # Изменяем порт, на котором сидит Apache
                    sudo mv /etc/apache2/ports.conf /etc/apache2/ports.conf.default >> $logsINST 2>&1
                    echo "Listen 127.0.0.1:81" | sudo tee /etc/apache2/ports.conf >> $logsINST 2>&1

                    # Создаем виртуальный хостинг для EngineGP
                    echo -e "$apache_enginegp" | sudo tee /etc/apache2/sites-available/enginegp.conf >> $logsINST 2>&1

                    # Создаем конфиг remoteip
                    echo -e "$apache_remoteip" | sudo tee /etc/apache2/conf-available/remoteip.conf >> $logsINST 2>&1

                    # Включаем модули Apache
                    sudo a2enmod actions fcgid alias proxy_fcgi rewrite remoteip >> $logsINST 2>&1
                    sudo a2enconf remoteip >> $logsINST 2>&1
                    sudo systemctl restart apache2 >> $logsINST 2>&1

                    # Проводим тестирование и запускаем конфиг Apache
                    sudo apachectl configtest >> $logsINST 2>&1
                    sudo a2ensite enginegp.conf >> $logsINST 2>&1
                    sudo a2dissite 000-default.conf >> $logsINST 2>&1
                    sudo systemctl restart apache2 >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "libapache2-mod-fcgid не установлен. Продолжение установки невозможно." >> $logsINST 2>&1
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Настраиваем nginx
                if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "nginx не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Удаляем дефолтный и создаём конфиг EngineGP
                    sudo rm /etc/nginx/sites-enabled/default >> $logsINST 2>&1
                    echo -e "$nginx_enginegp" | sudo tee /etc/nginx/sites-available/01-enginegp >> $logsINST 2>&1
                    sudo ln -s /etc/nginx/sites-available/01-enginegp /etc/nginx/sites-enabled/ >> $logsINST 2>&1

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
                echo "Хотите настроить локацию на сервере с EngineGP? (y/n)"
                read useEngineGP

                case $useEngineGP in
                    [Yy]*)
                        echo "Введите пароль root от MySQL:"
                        read userPassword
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
                # Проверяем наличие репозитория apache2 sury
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/apache2.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий apache2 не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий apache2
                        sudo curl -sSL https://packages.sury.org/apache2/README.txt | sudo bash -x >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Репозиторий apache2 не обнаружен. Добавляем..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Добавляем репозиторий apache2
                    sudo add-apt-repository ppa:ondrej/apache2 -y >> $logsINST 2>&1

                    # Обновление таблиц и пакетов
                    apt-get -y update >> $logsINST 2>&1
                    apt-get -y upgrade >> $logsINST 2>&1
                fi

                # Проверяем наличие репозитория nginx sury
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/nginx.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий nginx
                        sudo curl -sSL https://packages.sury.org/nginx/README.txt | sudo bash -x >> $logsINST 2>&1

                        # Обновление таблиц и пакетов
                        apt-get -y update >> $logsINST 2>&1
                        apt-get -y upgrade >> $logsINST 2>&1
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Репозиторий nginx не обнаружен. Добавляем..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Добавляем репозиторий nginx
                    sudo add-apt-repository ppa:ondrej/nginx -y >> $logsINST 2>&1

                    # Обновление таблиц и пакетов
                    apt-get -y update >> $logsINST 2>&1
                    apt-get -y upgrade >> $logsINST 2>&1
                fi

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
                        sudo curl -SLO https://dev.mysql.com/get/mysql-apt-config_0.8.29-1_all.deb >> $logsINST 2>&1
                        sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.29-1_all.deb >> $logsINST 2>&1
                        sudo apt-get update >> $logsINST 2>&1
                        sudo rm mysql-apt-config_0.8.29-1_all.deb >> $logsINST 2>&1
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
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "rc.local не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sed -i '14d' /etc/rc.local >> $logsINST 2>&1
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
                    echo "SteamCMD не настроен. Выполняется настройка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    groupmod -g 998 `cat /etc/group | grep :1000 | awk -F":" '{print $1}'` >> $logsINST 2>&1
                    groupadd -g 1000 servers >> $logsINST 2>&1
                    mkdir -p /path /path/cmd /path/update /path/maps >> $logsINST 2>&1
                    chmod -R 755 /path >> $logsINST 2>&1
                    chown root:servers /path >> $logsINST 2>&1
                    mkdir -p /servers >> $logsINST 2>&1
                    chmod -R 711 /servers >> $logsINST 2>&1
                    chown root:servers /servers >> $logsINST 2>&1
                    mkdir -p /copy >> $logsINST 2>&1
                    chmod -R 750 /copy >> $logsINST 2>&1
                    chown root:root /copy >> $logsINST 2>&1
                    sudo curl -SL -o steamcmd_linux.tar.gz http://media.steampowered.com/client/steamcmd_linux.tar.gz >> $logsINST 2>&1
                    tar -xzf steamcmd_linux.tar.gz -C /path/cmd >> $logsINST 2>&1
                    rm steamcmd_linux.tar.gz >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "SteamCMD уже установлен. Продолжение установки невозможно...." | tee -a $logsINST
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
                    echo "2. Build ReHLDS"
                    echo "3. Build 8308"
                    echo "4. Build 8196"
                    echo "5. Build 7882"
                    echo "6. Build 7559"
                    echo "7. Build 6153"
                    echo "8. Build 5787"
                    echo "0. Вернуться в предыдущее меню"

                    read -p "Выберите пункт меню: " cs16_choice

                    case $cs16_choice in
                        1)
                            mkdir -p /path/cs/steam 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/steam/steam.zip $gamesURL/cs/steam.zip 2>&1 | tee -a ${logsINST}
                            sudo unzip /path/cs/steam/steam.zip -d /path/cs/steam/ 2>&1 | tee -a ${logsINST}
                            sudo rm /path/cs/steam/steam.zip | tee -a $logsINST 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        2)
                            mkdir -p /path/cs/rehlds 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/rehlds/rehlds.zip $gamesURL/cs/rehlds.zip 2>&1 | tee -a ${logsINST}
                            sudo unzip /path/cs/rehlds/rehlds.zip -d /path/cs/rehlds/ 2>&1 | tee -a ${logsINST}
                            sudo rm /path/cs/rehlds/rehlds.zip 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        3)
                            mkdir -p /path/cs/8308 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/8308/8308.zip $gamesURL/cs/8308.zip 2>&1 | tee -a ${logsINST}
                            sudo unzip /path/cs/8308/8308.zip -d /path/cs/8308/ 2>&1 | tee -a ${logsINST}
                            sudo rm /path/cs/8308/8308.zip 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        4)
                            mkdir -p /path/cs/8196 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/8196/8196.zip $gamesURL/cs/8196.zip 2>&1 | tee -a ${logsINST}
                            unzip /path/cs/8196/8196.zip -d /path/cs/8196/ 2>&1 | tee -a ${logsINST}
                            rm /path/cs/8308/8308.zip 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        5)
                            mkdir -p /path/cs/7882 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/7882/7882.zip $gamesURL/cs/7882.zip 2>&1 | tee -a ${logsINST}
                            unzip /path/cs/7882/7882.zip -d /path/cs/7882/ 2>&1 | tee -a ${logsINST}
                            rm /path/cs/7882/7882.zip 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        6)
                            mkdir -p /path/cs/7559 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/7559/7559.zip $gamesURL/cs/7559.zip 2>&1 | tee -a ${logsINST}
                            unzip /path/cs/7559/7559.zip -d /path/cs/7559/ 2>&1 | tee -a ${logsINST}
                            rm /path/cs/7559/7559.zip 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        7)
                            mkdir -p /path/cs/6153 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/6153/6153.zip $gamesURL/cs/6153.zip 2>&1 | tee -a ${logsINST}
                            unzip /path/cs/6153/6153.zip -d /path/cs/6153/ 2>&1 | tee -a ${logsINST}
                            rm /path/cs/6153/6153.zip 2>&1 | tee -a ${logsINST}
                            cs16_choice
                            ;;
                        8)
                            mkdir -p /path/cs/5787 2>&1 | tee -a ${logsINST}
                            sudo curl -SL -o /path/cs/5787/5787.zip $gamesURL/cs/5787.zip 2>&1 | tee -a ${logsINST}
                            unzip /path/cs/5787/5787.zip -d /path/cs/5787/ 2>&1 | tee -a ${logsINST}
                            rm /path/cs/5787/5787.zip 2>&1 | tee -a ${logsINST}
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
                            /path/cmd/steamcmd.sh +login anonymous +force_install_dir /path/csgo/steam +app_update 740 validate +quit 2>&1 | tee -a ${logsINST}
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
                            /path/cmd/steamcmd.sh +login anonymous +force_install_dir /path/cs2/steam +app_update 730 validate +quit 2>&1 | tee -a ${logsINST}
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
                    # Add code for installing MTA game here
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