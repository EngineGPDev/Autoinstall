#!/bin/bash
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
pkgsREQ=(sudo curl lsb-release wget gnupg rsync pwgen zip unzip bc tar software-properties-common)

# Цикл установки пакетов
for package in "${pkgsREQ[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        echo "===================================" >> $logsINST 2>&1
        echo "$package не установлен. Выполняется установка..."  | tee -a $logsINST
        echo "===================================" >> $logsINST 2>&1
        apt-get install -y "$package" >> $logsINST 2>&1
    else
        echo "===================================" >> $logsINST 2>&1
        echo "$package уже установлен в системе." | tee -a $logsINST
        echo "===================================" >> $logsINST 2>&1
    fi
done

# Массив с поддерживаемыми версиями операционной системы
suppOS=("Debian 10" "Debian 11" "Ubuntu 22.04")

# Получаем текущую версию операционной системы
disOS=`lsb_release -si`
relOS=`lsb_release -sr`
currOS="$disOS $relOS"

# Файловый репозиторий
resURL="https://resources.enginegp.com"

# Проверка аргументов командной строки
if [ $# -gt 0 ]; then
    # Переменные для хранения
    verEGP=""
    verPHP=""
    verSQL=""
    sysIP=""

    # Перебор всех аргументов
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            --release)
                # Если передан аргумент --release, сохранить указанную версию EngineGP
                verEGP="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --release
                ;;
            --php)
                # Если передан аргумент --php, сохранить указанную версию PHP
                verPHP="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --php
                ;;
            --sql)
                # Если передан аргумент --sql, сохранить указанную версию PHP
                verSQL="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --php
                ;;
            --ip)
                # Если передан аргумент --ip, сохранить указанный IP-адрес
                sysIP="$2"
                shift # Пропустить значение IP-адреса
                shift # Пропустить аргумент --ip
                ;;
            *)
                # Неизвестный аргумент, вывести справку и выйти
                clear
                echo "Использование: ./install.sh [--release версия] [--php версия] [--sql версия] [--ip IP-адрес]"
                echo "  --release версия: установить указанную версию EngineGP. Формат должен быть: 3630"
                echo "  --php версия: установить указанную версию PHP. Формат должен быть: 7.1"
                echo "  --sql версия: установить указанную базу данный. Формат должен быть: mysql или mariadb"
                echo "  --ip IP-адрес: использовать указанный IP-адрес. Формат должен быть: 192.168.1.1"
                exit 1
                ;;
        esac
    done

    # Если версия EngineGP не выбрана, использовать последнюю стабильную версию
    if [ -z "$verEGP" ]; then
        LATEST_URL="$resURL/latest"
        verEGP=$(curl -s "$LATEST_URL" | grep -o 'Current: [0-9.]*' | awk '{print $2}')
    fi

    # Если версия PHP не выбрана, использовать PHP 7.2 по умолчанию
    if [ -z "$verPHP" ]; then
        verPHP="7.4"
    fi

    # Если IP-адрес не указан, получить внешний IP-адрес с помощью сервиса ipinfo.io
    if [ -z "$sysIP" ]; then
        sysIP=$(curl -s ipinfo.io/ip)
    fi
else
    # Получаем последнюю версию EngineGP из файла на сайте
    LATEST_URL="$resURL/latest"
    # Если нет аргументов, задаём по умолчанию
    verEGP=$(curl -s "$LATEST_URL" | grep -o 'Current: [0-9.]*' | awk '{print $2}')
    filesEGP=$verEGP
    verPHP="7.4"
    sysIP=$(curl -s ipinfo.io/ip)
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

# Проверяем условия и записываем версию в переменную
if [[ "$verEGP" == 3* ]]; then
    resEGP="EngineGPv3"
elif [[ "$verEGP" == 4* ]]; then
    resEGP="EngineGPv4"
else
    resEGP="EngineGPv4"
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
                pkgsLNAMP=(apache2 php php-fpm php-ctype php-json php-mbstring php-zip php-gd php-xml php-curl libapache2-mod-fcgid nginx)
                pkgsEGP=(ufw memcached cron php$verPHP php$verPHP-fpm php$verPHP-common php$verPHP-cli php$verPHP-memcache php$verPHP-memcached php$verPHP-mysql php$verPHP-xml php$verPHP-mbstring php$verPHP-gd php$verPHP-imagick php$verPHP-zip php$verPHP-curl php$verPHP-ssh2 php$verPHP-xml)

                # Установка стека LNAMP + phpMyAdmin
                # Проверяем наличие репозитория php sury
                if [[ " ${disOS} " =~ " Debian " ]]; then
                    if [ ! -f "/etc/apt/sources.list.d/php.list" ]; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий php не обнаружен. Добавляем..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        # Добавляем репозиторий php
                        sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x >> $logsINST 2>&1

                        # Обновление таблиц
                        apt-get -y update >> $logsINST 2>&1

                        # Определяем версию php по умолчанию
                        defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "Репозиторий php обнаружен." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                    fi
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Репозиторий php не обнаружен. Добавляем..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    # Добавляем репозиторий php
                    sudo add-apt-repository ppa:ondrej/php -y >> $logsINST 2>&1

                    # Обновление таблиц
                    apt-get -y update >> $logsINST 2>&1

                    # Определяем версию php по умолчанию
                    defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                fi

                # Генерирование паролей и имён
                passSQL=$(pwgen -cns -1 16)
                passPMA=$(pwgen -cns -1 16)
                usrEgpSQL="enginegp_$(pwgen -cns -1 8)"
                dbEgpSQL="enginegp_$(pwgen -1 8)"
                passEgpSQL=$(pwgen -cns -1 16)
                usrEgpPASS=$(pwgen -cns -1 16)
                usrEgpHASH=$(echo -n "$usrEgpPASS" | md5sum | sed 's/-//' | tr -d '[:space:]')

                # Конфигурация apache для EngineGP
                apache_enginegp="<VirtualHost *:8080>
     ServerName $sysIP
     DocumentRoot /var/www/enginegp
     DirectoryIndex index.php index.html
     ErrorLog \${APACHE_LOG_DIR}/enginegp.log
     CustomLog \${APACHE_LOG_DIR}/enginegp.log combined

     <Directory /var/www/enginegp>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        Order allow,deny
        allow from all
     </Directory>

    <FilesMatch \.php$>
      # For Apache version 2.4.10 and above, use SetHandler to run PHP as a fastCGI process server
      SetHandler "proxy:unix:/run/php/php$verPHP-fpm.sock\|fcgi://localhost"
    </FilesMatch>
</VirtualHost>
"

                # Конфигурация nginx для EngineGP
                nginx_enginegp="server {
    listen 80;
    server_name $sysIP;

    location / {
        proxy_pass http://$sysIP:8080;
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
}"
                # Конфигурация nginx для phpMyAdmin
                nginx_phpmyadmin="server {
    listen 9090;
    server_name $sysIP;
    
    root /usr/share;

    location /phpmyadmin {
        index index.php index.html index.htm;
        try_files \$uri \$uri/ /phpmyadmin/index.php;

        location ~ ^/phpmyadmin/(.+\.php)$ {
            include snippets/fastcgi-php.conf;
            fastcgi_pass unix:/run/php/php$defPHP-fpm.sock;
        }

        location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
            root /usr/share;
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
                    sudo curl -SLO https://dev.mysql.com/get/mysql-apt-config_0.8.26-1_all.deb >> $logsINST 2>&1
                    sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.26-1_all.deb >> $logsINST 2>&1
                    sudo apt-get update >> $logsINST 2>&1
                    sudo rm mysql-apt-config_0.8.26-1_all.deb >> $logsINST 2>&1
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
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package уже установлен в системе." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
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
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package уже установлен в системе." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
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
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "php$defPHP-fpm уже запущен." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                    fi
                fi

                # Проверяем установку php-fpm для EngineGP
                if dpkg-query -W -f='${Status}' "php$verPHP-fpm" 2>/dev/null | grep -q "install ok installed"; then
                    if ! systemctl is-active --quiet php$verPHP-fpm; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "php$verPHP-fpm не запущен. Выполняется запуск..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        sudo systemctl start php$verPHP-fpm >> $logsINST 2>&1
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "php$verPHP-fpm уже запущен." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                    fi
                fi
                  
                # Создание каталогов
                sudo mkdir /var/log/enginegp >> $logsINST 2>&1
                sudo mkdir /var/www/enginegp >> $logsINST 2>&1

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
                    echo "Listen 8080" | sudo tee /etc/apache2/ports.conf >> $logsINST 2>&1

                    # Создаем виртуальный хостинг для EngineGP
                    echo -e "$apache_enginegp" | sudo tee /etc/apache2/sites-available/enginegp.conf >> $logsINST 2>&1

                    # Включаем модули Apache
                    sudo a2enmod actions fcgid alias proxy_fcgi rewrite >> $logsINST 2>&1
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

                # Установка EngineGP
                # Создание временной папки
                sudo mkdir /tmp/enginegp >> $logsINST 2>&1

                # Закачиваем и распаковываем панель
                if [ ! -f "/var/www/enginegp/index.php" ]; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "enginegp не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo curl -SL -o /tmp/enginegp/enginegp.zip "$resURL/$resEGP/$verEGP/$verEGP.zip" >> $logsINST 2>&1
                    sudo unzip /tmp/enginegp/enginegp.zip -d /tmp/enginegp/ >> $logsINST 2>&1
                    sudo rsync -av /tmp/enginegp/EngineGP-*/. /var/www/enginegp/ >> $logsINST 2>&1
                    sudo rm /tmp/enginegp/enginegp.zip >> $logsINST 2>&1
                    sudo rm -r /tmp/enginegp/EngineGP-* >> $logsINST 2>&1
                    sed -i "s/IPADDR/$sysIP/g" /var/www/enginegp/system/data/config.php >> $logsINST 2>&1
                    sed -i "s/enginegp/$dbEgpSQL/g" /var/www/enginegp/system/data/mysql.php >> $logsINST 2>&1
                    sed -i "s/root/$usrEgpSQL/g" /var/www/enginegp/system/data/mysql.php >> $logsINST 2>&1
                    sed -i "s/SQLPASS/$passEgpSQL/g" /var/www/enginegp/system/data/mysql.php >> $logsINST 2>&1
                    sed -i "s/ENGINEGPHASH/$usrEgpHASH/g" /var/www/enginegp/enginegp.sql >> $logsINST 2>&1
                    mysql -u $usrEgpSQL -p$passEgpSQL $dbEgpSQL < /var/www/enginegp/enginegp.sql >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "enginegp уже установлен в системе. Продолжение установки невозможно." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    read -p "Нажмите Enter для завершения..."
                    continue
                fi

                # Установка и настрока composer
                if [ ! -d "/var/www/enginegp/vendor" ]; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "composer не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    curl -o /tmp/enginegp/composer-setup.php https://getcomposer.org/installer >> $logsINST 2>&1
                    php$verPHP /tmp/enginegp/composer-setup.php --install-dir=/usr/local/bin --filename=composer >> $logsINST 2>&1
                    sudo rm /tmp/enginegp/composer-setup.php >> $logsINST 2>&1
                    sudo composer install --no-interaction --working-dir=/var/www/enginegp >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "composer уже установлен в системе." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                fi

                # Выставляем права на каталог
                sudo chown -R www-data:www-data /var/www/enginegp >> $logsINST 2>&1
                sudo chmod -R 755 /var/www/enginegp >> $logsINST 2>&1

                # Сообщение о завершении установки
                echo "===================================" | tee -a $logsINST
                echo "Установка завершена!" | tee -a $logsINST
                echo "Ссылка на EngineGP: http://$sysIP/" | tee -a $saveDIR
                echo "Пользователь: root" | tee -a $saveDIR
                echo "Пароль: $usrEgpPASS" | tee -a $saveDIR
                echo "Ссылка на phpmyadmin: http://$sysIP:9090/phpmyadmin/" | tee -a $saveDIR
                echo "Таблица EngineGP: $dbEgpSQL" | tee -a $saveDIR
                echo "Пароль MySQL от $usrEgpSQL: $passEgpSQL" | tee -a $saveDIR
                echo "Пароль MySQL от root: $passSQL" | tee -a $saveDIR
                echo "Пароль MySQL от phpmyadmin: $passPMA" | tee -a $saveDIR
                echo "===================================" | tee -a $logsINST
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
            # Проверяем, содержится ли текущая версия в массиве поддерживаемых версий
            if [[ " ${suppOS[@]} " =~ " ${currOS} " ]]; then
                pkgsLOC=(lib32z1 libbabeltrace1 libc6-dbg libdw1 lib32stdc++6 libreadline5 lib32gcc1 screen tcpdump lsof qstat gdb-minimal ntpdate gcc-multilib iptables default-jdk nginx)
                passMySQL=$(pwgen -cns -1 16)
                passProFTPD=$(pwgen -cns -1 16)

                if ! dpkg --print-foreign-architectures | grep -q "i386"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "Архитектура i386 не добавлена. Выполняется добавление..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    sudo dpkg --add-architecture i386 >> $logsINST 2>&1

                    # Обновление таблиц
                    apt-get -y update >> $logsINST 2>&1
                else
                    echo "===================================" >> $logsINST 2>&1
                    echo "Архитектура i386 уже добавлена." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                fi

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
                    sudo curl -SLO https://dev.mysql.com/get/mysql-apt-config_0.8.26-1_all.deb >> $logsINST 2>&1
                    sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.26-1_all.deb >> $logsINST 2>&1
                    sudo apt-get update >> $logsINST 2>&1
                    sudo rm mysql-apt-config_0.8.26-1_all.deb >> $logsINST 2>&1
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

                # Цикл установки пакетов
                for package in "${pkgsLOC[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package не установлен. Выполняется установка..." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                        apt-get install -y "$package" >> $logsINST 2>&1
                    else
                        echo "===================================" >> $logsINST 2>&1
                        echo "$package уже установлен в системе." | tee -a $logsINST
                        echo "===================================" >> $logsINST 2>&1
                    fi
                done

                # Устанавливаем ProFTPD
                if ! dpkg-query -W -f='${Status}' "proftpd" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" >> $logsINST 2>&1
                    echo "proftpd не установлен. Выполняется установка..." | tee -a $logsINST
                    echo "===================================" >> $logsINST 2>&1
                    echo "proftpd shared/proftpd/inetd_or_standalone select standalone" | debconf-set-selections
                    sudo apt-get install -y proftpd proftpd-mod-mysql >> $logsINST 2>&1
                    curl -o /etc/proftpd/proftpd.conf $resURL/Components/ProFTPD/proftpd >> $logsINST 2>&1
                    curl -o /etc/proftpd/proftpd_modules.conf $resURL/Components/ProFTPD/proftpd_modules >> $logsINST 2>&1
                    curl -o /etc/proftpd/sql.conf $resURL/Components/ProFTPD/proftpd_sql >> $logsINST 2>&1
                    mysql -uroot -p$passMySQL -e "CREATE DATABASE ftp;" >> $logsINST 2>&1
                    mysql -uroot -p$passMySQL -e "CREATE USER 'ftp'@'localhost' IDENTIFIED BY '$passProFTPD';" >> $logsINST 2>&1
                    mysql -uroot -p$passMySQL -e "GRANT ALL PRIVILEGES ON ftp . * TO 'ftp'@'localhost';" >> $logsINST 2>&1
                    mysql -uroot -p$passMySQL ftp < EngineGP-requirements/proftpd/sqldump.sql >> $logsINST 2>&1
                    sed -i 's/passwdfor/'$passProFTPD'/g' /etc/proftpd/sql.conf >> $logsINST 2>&1
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
                echo "">>$SAVE
                echo "Location data:">>$saveDIR
                echo "SQL_Username: root">>$saveDIR
                echo "SQL_Password: $passMySQL">>$saveDIR
                echo "SQL_FileTP: ftp">>$saveDIR
                echo "SQL_Port: 3306">>$saveDIR
                echo "Password for FTP database: $passProFTPD">>$saveDIR
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
                    # Add code for installing SAMP game here
                    ;;
                3)
                    # Add code for installing MTA game here
                    ;;
                4)
                    # Add code for installing MTA game here
                    ;;
                5)
                    # Add code for installing MTA game here
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
            echo "Последняя версия EngineGP: $verEGP" | tee -a $logsINST
            echo "Текущая версия Linux: $currOS" | tee -a $logsINST
            echo "Внешний IP-адрес: $sysIP" | tee -a $logsINST
            echo "Версия php: $verPHP" | tee -a $logsINST
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