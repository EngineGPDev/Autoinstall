#!/bin/bash
# Получаем внешний IP-адрес с помощью сервиса ipinfo.io
external_ip=$(curl -s ipinfo.io/ip)

# Проверяем, является ли полученный IP-адрес действительным IPv4 адресом
if [[ $external_ip =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Внешний IP-адрес: $external_ip"
else
    echo "Не удалось получить внешний IP-адрес"
fi

# Обновление таблиц и системы
sysUpdate (){
    apt-get -y update
    apt-get -y upgrade
}

# Установка начальных пакетов
if ! command -v curl &> /dev/null; then
    echo "curl не установлен. Выполняется установка..."
    apt-get install -y curl
fi

# Проверка аргументов командной строки
if [ $# -gt 0 ]; then
    # Если передан ключ и версия, установить указанную версию
    if [ "$1" == "--release" ] && [ $# -gt 1 ]; then
        VERSION="$2"
    else
        # Иначе, вывести справку и выйти
        echo "Использование: ./install.sh [--release версия]"
        echo "  --release версия: установить указанную версию"
        exit 1
    fi
else
    # Если нет аргументов, получить последнюю версию из файла на сайте
    LATEST_URL="https://resources.enginegp.com/latest"
    VERSION=$(curl -s "$LATEST_URL" | awk 'NR==1 {print $2}')
fi

# Вывод версии для информирования пользователя
echo "Устанавливаем версию: $VERSION"

# Здесь выполняется код установки CMS с использованием заданной или последней версии
# Например:
# wget "https://example.com/cms-$VERSION.tar.gz"
# tar -xzvf "cms-$VERSION.tar.gz"
# cd "cms-$VERSION"
# ./install.sh

# Примечание: Вам нужно заменить URL и команды установки на соответствующие для вашей CMS

echo "Установка завершена."