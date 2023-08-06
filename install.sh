#!/bin/bash
# Обновление таблиц и системы
sysUpdate (){
    apt-get -y update
    apt-get -y upgrade
}

# Обновление системы
sysUpdate

# Установка начальных пакетов
pkgsREQ=(sudo curl)

# Цикл установки пакетов
for package in "${pkgsREQ[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
        clear
        echo "$package не установлен. Выполняется установка..."
        apt-get install -y "$package"
    fi
done

# Определение операционной системы
verOS=`cat /etc/issue.net | awk '{print $1,$3}'`

# Проверка аргументов командной строки
if [ $# -gt 0 ]; then
    # Переменные для хранения
    verEGP=""
    verPHP=""
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
            --ip)
                # Если передан аргумент --ip, сохранить указанный IP-адрес
                sysIP="$2"
                shift # Пропустить значение IP-адреса
                shift # Пропустить аргумент --ip
                ;;
            *)
                # Неизвестный аргумент, вывести справку и выйти
                clear
                echo "Использование: ./install.sh [--release версия] [--php версия] [--ip IP-адрес]"
                echo "  --release версия: установить указанную версию EngineGP"
                echo "  --php версия: установить указанную версию PHP"
                echo "  --ip IP-адрес: использовать указанный IP-адрес"
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
        verPHP="8.0"
    fi

    # Если IP-адрес не указан, получить внешний IP-адрес с помощью сервиса ipinfo.io
    if [ -z "$sysIP" ]; then
        sysIP=$(curl -s ipinfo.io/ip)
    fi
else
    # Если нет аргументов, получить последнюю версию EngineGP из файла на сайте
    LATEST_URL="https://resources.enginegp.com/latest"
    verEGP=$(curl -s "$LATEST_URL" | awk 'NR==1 {print $2}')
    verPHP="8.0"
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
            # Список пакетов для установки
            pkgsALL=(ufw memcached unzip bc cron apache2 libapache2-mpm-itk php$verPHP php$verPHP-common php$verPHP-cli php$verPHP-memcache php$verPHP-memcached php$verPHP-mysql php$verPHP-xml php$verPHP-mbstring php$verPHP-gd php$verPHP-imagick php$verPHP-zip php$verPHP-curl php$verPHP-ssh2 php$verPHP-xml libapache2-mod-php$verPHP nginx mariadb-server)

            apache_ports="Listen 8080

            <IfModule ssl_module>
                Listen 443
            </IfModule>

            <IfModule mod_gnutls.c>
                Listen 443
            </IfModule>"

            # Конфигурация apache для EngineGP
            apache_enginegp="<VirtualHost *:8080>
    ServerName $sysIP
    DocumentRoot /var/enginegp
    ErrorLog /var/log/enginegp/apache_enginegp_error.log
    CustomLog /var/log/enginegp/apache_enginegp_access.log combined

    <IfModule mpm_itk_module>
         AssignUserID www-data www-data
    </IfModule>

    <Directory />
         Options FollowSymLinks
         AllowOverride All
    </Directory>

    <Directory /var/enginegp/>
         Options Indexes FollowSymLinks
         AllowOverride All
         Require all granted

         <FilesMatch \.php$>
             SetHandler application/x-httpd-php
         </FilesMatch>
    </Directory>
</VirtualHost>"

            # Конфигурация nginx для EngineGP
            nginx_enginegp="server {
    listen 80;
    server_name $sysIP;

    root /var/enginegp;
    charset utf-8;

    access_log /var/log/enginegp/nginx_enginegp_access.log combined buffer=64k;
    error_log /var/log/enginegp/nginx_enginegp_error.log error;

    index index.php index.htm index.html;
        
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_connect_timeout 120;
        proxy_send_timeout 120;
        proxy_read_timeout 180;
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
}"
            # Цикл установки пакетов
            for package in "${pkgsALL[@]}"; do
                # Проверяем наличие php
                if [ ! -f "/etc/apt/sources.list.d/php.list" ]; then
                    # Добавляем репозиторий php
                    sudo curl -sSL https://packages.sury.org/php/README.txt | sudo bash -x

                    # Обновление таблиц
                    apt-get -y update
                fi

                # Проверка на наличие и установка пакетов
                if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                    echo "$package не установлен. Выполняется установка..."
                    apt-get install -y "$package"
                fi

                # Проверяем установку apache
                if dpkg-query -W -f='${Status}' "libapache2-mod-php$verPHP" 2>/dev/null | grep -q "install ok installed"; then
                    if [ ! -f /etc/apache2/sites-available/enginegp.conf ]; then
                        # Разрешаем доступ к портам
                        sudo ufw allow 80 >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        sudo ufw allow 443 >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Изменяем порт, на котором слушает Apache
                        echo -e "$apache_ports" | sudo tee /etc/apache2/ports.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Создаём папку для записи логов, если ещё не создана
                        sudo mkdir /var/log/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Отключаем конфигурационный файл 000-default.conf
                        sudo a2dissite 000-default.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Создаем виртуальный хостинг для EngineGP
                        echo -e "$apache_enginegp" | sudo tee /etc/apache2/sites-available/enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Проверяем конфиг apache и выводим в логи
                        sudo apachectl configtest >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Включаем конфигурацию
                        sudo a2ensite enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Включаем rewrite
                        sudo a2enmod rewrite >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Включаем MPM-ITK
                        sudo a2enmod mpm_itk >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Включаем mod_php
                        sudo a2enmod php$verPHP >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Перезапускаем apache
                        sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    fi
                fi

                # Проверяем установку nginx
                if dpkg-query -W -f='${Status}' "nginx" 2>/dev/null | grep -q "install ok installed"; then
                    if [ ! -f /etc/nginx/sites-available/enginegp.conf ]; then
                        # Создаём папку для записи логов, если ещё не создана
                        sudo mkdir /var/log/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Создаем виртуальный хостинг для EngineGP
                        echo -e "$nginx_enginegp" | sudo tee /etc/nginx/sites-available/enginegp.conf >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Создаём симлинк конфига NGINX
                        sudo ln -s /etc/nginx/sites-available/enginegp.conf /etc/nginx/sites-enabled/ >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Проверяем конфиг nginx и выводим в логи
                        sudo nginx -t >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Перезапускаем nginx
                        sudo systemctl restart nginx >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    fi
                fi

                # Устанавливаем панель
                if dpkg-query -W -f='${Status}' "php$verPHP-xml" 2>/dev/null | grep -q "install ok installed"; then
                    if [ ! -d /var/enginegp/ ]; then
                        # Закачиваем и распаковываем панель
                        sudo curl -sSL -o /var/enginegp.zip "$resURL/$resEGP/$verEGP/$verEGP.zip" >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        sudo unzip /var/enginegp.zip -d /var/ >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        sudo mv /var/EngineGP-* /var/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        sudo rm /var/enginegp.zip >> "$(dirname "$0")/enginegp_install.log" 2>&1
                
                        # Задаём права на каталог
                        chown www-data:www-data -R /var/enginegp/ >> "$(dirname "$0")/enginegp_install.log" 2>&1

                        # Установка и настрока composer
                        curl -o composer-setup.php https://getcomposer.org/installer >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        php composer-setup.php --install-dir=/usr/local/bin --filename=composer >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        cd /var/enginegp >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        sudo composer install --no-interaction >> "$(dirname "$0")/enginegp_install.log" 2>&1
                        cd >> "$(dirname "$0")/enginegp_install.log" 2>&1
                    fi
                fi
            done

            # Перезапускаем apache
            sudo systemctl restart apache2 >> "$(dirname "$0")/enginegp_install.log" 2>&1
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
            echo "Текущая версия Linux: $verOS"
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