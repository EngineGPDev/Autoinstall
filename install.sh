#!/bin/bash
# Обновление таблиц и системы
sysUpdate (){
    apt-get -y update
    apt-get -y upgrade
}

# Обновление системы
sysUpdate

# Установка начальных пакетов.
# lsb-release wget gnupg - Требуются для MySQL. В остальном зависимость не проверялась.
pkgsREQ=(sudo curl lsb-release wget gnupg)

# Цикл установки пакетов
for package in "${pkgsREQ[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        clear
        echo "$package не установлен. Выполняется установка..."  | tee -a "$(dirname "$0")/enginegp_install.log"
        apt-get install -y "$package" >> "$(dirname "$0")/enginegp_install.log" 2>&1
    else
        echo "$package уже установлен в системе." | tee -a "$(dirname "$0")/enginegp_install.log"
    fi
done

# Массив с поддерживаемыми версиями Debian
suppOS=("Debian 10" "Debian 11")

# Получаем текущую версию операционной системы
currOS=`cat /etc/issue.net | awk '{print $1,$3}'`

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
                echo "  --release версия: установить указанную версию EngineGP. Формат должен быть: 3.6.3.0"
                echo "  --php версия: установить указанную версию PHP. Формат должен быть: 8.1"
                echo "  --sql версия: установить указанную базу данный. Формат должен быть: mysql или mariadb"
                echo "  --ip IP-адрес: использовать указанный IP-адрес. Формат должен быть: 192.168.1.1"
                exit 1
                ;;
        esac
    done

    # Если версия EngineGP не выбрана, использовать последнюю стабильную версию
    if [ -z "$verEGP" ]; then
        LATEST_URL="https://resources.enginegp.com/latest"
        verEGP=$(curl -s "$LATEST_URL" | awk 'NR==1 {print $2}')
    fi

    # Если версия PHP не выбрана, использовать PHP 8.0 по умолчанию
    if [ -z "$verPHP" ]; then
        verPHP="7.0"
    fi

    # Если IP-адрес не указан, получить внешний IP-адрес с помощью сервиса ipinfo.io
    if [ -z "$sysIP" ]; then
        sysIP=$(curl -s ipinfo.io/ip)
    fi
else
    # Если нет аргументов, получить последнюю версию EngineGP из файла на сайте
    LATEST_URL="https://resources.enginegp.com/latest"
    verEGP=$(curl -s "$LATEST_URL" | awk 'NR==1 {print $2}')
    verPHP="7.0"
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
if [[ "verEGP" == 3.* ]]; then
    resEGP="EngineGP.v3"
elif [[ "$version" == 4.* ]]; then
    resEGP="EngineGP.v4"
else
    resEGP="EngineGP.v4"
fi

# Файловый репозиторий
resURL="https://resources.enginegp.com/"

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
                pkgsLNAMP=(apache2 php php-fpm php-ctype php-json php-mbstring php-zip php-gd php-xml php-curl libapache2-mod-php libapache2-mod-fcgid nginx)
                pkgsEGP=(ufw memcached unzip bc cron php$verPHP php$verPHP-fpm php$verPHP-common php$verPHP-cli php$verPHP-memcache php$verPHP-memcached php$verPHP-mysql php$verPHP-xml php$verPHP-mbstring php$verPHP-gd php$verPHP-imagick php$verPHP-zip php$verPHP-curl php$verPHP-ssh2 php$verPHP-xml libapache2-mod-php$verPHP)

                # Установка стека LNAMP + phpMyAdmin
                # Проверяем наличие репозитория php sury
                if [ ! -f "/etc/apt/sources.list.d/php.list" ]; then
                    echo "Репозиторий php не обнаружен. Добавляем..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    # Добавляем репозиторий php
                    sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Обновление таблиц
                    apt-get -y update >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Определяем версию php по умолчанию
                    defPHP=$(apt-cache policy php | awk -F ': ' '/Candidate:/ {split($2, a, "[:+~]"); print a[2]}')
                fi

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

    location ~* \.(gif|jpeg|jpg|txt|png|tif|tiff|ico|jng|bmp|doc|pdf|rtf|xls|ppt|rar|rpm|swf|zip|bin|exe|dll|deb|cur)$ {
        access_log off;
        expires 3d;
    }

    location ~* \.(css|js)$ {
        access_log off;
        expires 180m;
    }

    location ~ /\.ht {
        deny all;
    }

    location /phpmyadmin {
        root /usr/share/;
        index index.php;

       location ~ ^/phpmyadmin/(.+\.php)$ {
           try_files \$uri =404;
           root /usr/share/;
           proxy_pass http://$sysIP:8080;
       }

       location ~* ^/phpmyadmin/(.+\.(jpg|jpeg|gif|css|png|js|ico|html|xml|txt))$ {
           root /usr/share/;
       }
    }
}"

                # Устанавливаем базу данных
                if ! dpkg-query -W -f='${Status}' "mysql-server" 2>/dev/null | grep -q "install ok installed"; then
                    echo "mysql-server не установлен. Выполняется установка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    sudo debconf-set-selections <<EOF
mysql-apt-config mysql-apt-config/select-server select mysql-8.0
mysql-apt-config mysql-apt-config/select-tools select Enabled
mysql-apt-config mysql-apt-config/select-preview select Disabled
EOF
                    sudo curl -sSLO https://dev.mysql.com/get/mysql-apt-config_0.8.26-1_all.deb >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo DEBIAN_FRONTEND="noninteractive" dpkg -i mysql-apt-config_0.8.26-1_all.deb >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo apt-get update >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo rm mysql-apt-config_0.8.26-1_all.deb >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo debconf-set-selections <<EOF
mysql-community-server mysql-community-server/root-pass password 123456789
mysql-community-server mysql-community-server/re-root-pass password 123456789
mysql-community-server mysql-server/default-auth-override select Use Strong Password Encryption (RECOMMENDED)
EOF
                    sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y mysql-server >> "$(dirname "$0")/enginegp_install.log" 2>&1
                else
                    echo "mysql-server уже установлен в системе. Продолжение установки невозможно." | tee -a "$(dirname "$0")/enginegp_install.log"
                    exit 1
                fi

                # Цикл установки пакетов
                for package in "${pkgsLNAMP[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "$package не установлен. Выполняется установка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                        sudo apt-get install -y "$package" >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    else
                        echo "$package уже установлен в системе." | tee -a "$(dirname "$0")/enginegp_install.log"
                    fi
                done

                # Цикл установки пакетов
                for package in "${pkgsEGP[@]}"; do
                    # Проверка на наличие и установка пакетов
                    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                        echo "$package не установлен. Выполняется установка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                        apt-get install -y "$package" >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    else
                        echo "$package уже установлен в системе." | tee -a "$(dirname "$0")/enginegp_install.log"
                    fi
                done

                # Установка phpMyAdmin
                if ! dpkg-query -W -f='${Status}' "phpmyadmin" 2>/dev/null | grep -q "install ok installed"; then
                    echo "phpmyadmin не установлен. Выполняется установка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    sudo debconf-set-selections <<EOF
phpmyadmin phpmyadmin/dbconfig-install boolean true
phpmyadmin phpmyadmin/mysql/app-pass password 1234567890
phpmyadmin phpmyadmin/password-confirm password 1234567890
phpmyadmin phpmyadmin/mysql/admin-pass password 123456789
phpmyadmin phpmyadmin/app-password-confirm password 123456789
phpmyadmin phpmyadmin/reconfigure-webserver multiselect
EOF
                    sudo DEBIAN_FRONTEND="noninteractive" apt-get install -y phpmyadmin >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo ln -s /etc/phpmyadmin/apache.conf /etc/apache2/conf-available/phpmyadmin.conf
                    sudo a2enconf phpmyadmin.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1
                else
                    echo "phpmyadmin уже установлен в системе. Продолжение установки невозможно." | tee -a "$(dirname "$0")/enginegp_install.log"
                    exit 1
                fi

                # Проверяем установку php-fpm
                if dpkg-query -W -f='${Status}' "php$defPHP-fpm" 2>/dev/null | grep -q "install ok installed"; then
                    if ! systemctl is-active --quiet php$defPHP-fpm; then
                        echo "php$defPHP-fpm не запущен. Выполняется запуск..." | tee -a "$(dirname "$0")/enginegp_install.log"
                        sudo systemctl start php$defPHP-fpm >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    else
                        echo "php$defPHP-fpm уже запущен." | tee -a "$(dirname "$0")/enginegp_install.log"
                    fi
                fi
                  
                # Создание каталогов
                sudo mkdir /var/log/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo mkdir /var/www/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo chown -R www-data:www-data /var/www/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                sudo chmod -R 755 /var/www/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1

                # Настраиваем apache
                if dpkg-query -W -f='${Status}' "libapache2-mod-fcgid" 2>/dev/null | grep -q "install ok installed"; then
                    echo "apache2 не настроен. Выполняется настройка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    # Разрешаем доступ к портам
                    sudo ufw allow 80 >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo ufw allow 443 >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Изменяем порт, на котором сидит Apache
                    sudo mv /etc/apache2/ports.conf /etc/apache2/ports.conf.default >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    echo "Listen 8080" | sudo tee /etc/apache2/ports.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Создаем виртуальный хостинг для EngineGP
                    echo -e "$apache_enginegp" | sudo tee /etc/apache2/sites-available/enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Включаем модули Apache
                    sudo a2enmod actions fcgid alias proxy_fcgi >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Проводим тестирование и запускаем конфиг Apache
                    sudo apachectl configtest >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo a2ensite enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo a2dissite 000-default.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1
                else
                     echo "libapache2-mod-fcgid не установлен. Продолжение установки невозможно." >> "$(dirname "$0")/enginegp_install.log" 2>&1
                     exit 1
                fi

                # Настраиваем nginx
                if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                    echo "nginx не настроен. Выполняется настройка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    # Удаляем дефолтный и создаём конфиг EngineGP
                    sudo rm /etc/nginx/sites-enabled/default >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    echo -e "$nginx_enginegp" | sudo tee /etc/nginx/sites-available/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo ln -s /etc/nginx/sites-available/enginegp /etc/nginx/sites-enabled/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1

                    # Проводим тестирование и запускаем конфиг NGINX
                    sudo nginx -t >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo systemctl restart nginx >> "$(dirname "$0")/enginegp_install.log" 2>&1
                else
                     echo "NGINX не установлен. Продолжение установки невозможно." | tee -a "$(dirname "$0")/enginegp_install.log"
                     exit 1
                fi

                # Установка EngineGP
                # Закачиваем и распаковываем панель
                if [ ! -f "/var/www/enginegp/index.php" ]; then
                    echo "enginegp не установлен. Выполняется установка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    sudo curl -sSL -o /var/www/enginegp.zip "$resURL/$resEGP/$verEGP/$verEGP.zip" >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo unzip /var/www/enginegp.zip -d /var/www/ >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo mv /var/EngineGP-* /var/www/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo rm /var/www/enginegp.zip >> "$(dirname "$0")/enginegp_install.log" 2>&1
                else
                    echo "enginegp уже установлен в системе. Продолжение установки невозможно." | tee -a "$(dirname "$0")/enginegp_install.log"
                    exit 1
                fi

                # Установка и настрока composer
                if [ ! -d "/var/www/enginegp/vendor" ]; then
                    echo "composer не установлен. Выполняется установка..." | tee -a "$(dirname "$0")/enginegp_install.log"
                    curl -o composer-setup.php https://getcomposer.org/installer >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    php$verPHP composer-setup.php --install-dir=/usr/local/bin --filename=composer >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    cd /var/www/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    sudo composer install --no-interaction >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    cd >> "$(dirname "$0")/enginegp_install.log" 2>&1
                else
                    echo "composer уже установлен в системе. Продолжение установки невозможно." | tee -a "$(dirname "$0")/enginegp_install.log"
                    exit 1
                fi

                # Сообщение о завершении установки
                echo "Установка завершена!" | tee -a "$(dirname "$0")/enginegp_install.log"
            else
                echo "Вы используете неподдерживаемую версию Linux" | tee -a "$(dirname "$0")/enginegp_install.log"
            fi
            ;;
        2)
            clear
            echo "Вы выбрали: Настройка сервера под игры"
            # Здесь добавить код для настройки сервера под игры
            ;;
        3)
            clear
            echo "Вы выбрали: Установка игровых сборок"
            # Здесь добавить код для установки игровых сборок
            ;;
        4)
            clear
            echo "Последняя версия EngineGP: $verEGP"
            echo "Текущая версия Linux: $currOS"
            echo "Внешний IP-адрес: $sysIP"
            echo "Версия php: $verPHP"
            ;;
        0)
            clear
            echo "До свидания!"
            exit 0
            ;;
        *)
            clear
            echo "Неверный выбор. Попробуйте еще раз."
            ;;
    esac

    read -p "Нажмите Enter, чтобы продолжить..."
done