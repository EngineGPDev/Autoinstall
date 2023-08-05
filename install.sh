#!/bin/bash

# Установка начальных пакетов
required_packages=(sudo curl)

for package in "${required_packages[@]}"; do
    if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "installed"; then
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
    EGP_VERSION=""
    PHP_VERSION=""
    IP_ADDRESS=""

    # Перебор всех аргументов
    while [[ $# -gt 0 ]]; do
        key="$1"

        case $key in
            --release)
                # Если передан аргумент --release, сохранить указанную версию EngineGP
                EGP_VERSION="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --release
                ;;
            --php)
                # Если передан аргумент --php, сохранить указанную версию PHP
                PHP_VERSION="$2"
                shift # Пропустить значение версии
                shift # Пропустить аргумент --php
                ;;
            --ip)
                # Если передан аргумент --ip, сохранить указанный IP-адрес
                IP_ADDRESS="$2"
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
    if [ -z "$EGP_VERSION" ]; then
        LATEST_URL="https://resources.enginegp.com/latest"
        EGP_VERSION=$(curl -s "$LATEST_URL" | awk 'NR==1 {print $2}')
    fi

    # Если версия PHP не выбрана, использовать PHP 8.0 по умолчанию
    if [ -z "$PHP_VERSION" ]; then
        PHP_VERSION="8.0"
    fi

    # Если IP-адрес не указан, получить внешний IP-адрес с помощью сервиса ipinfo.io
    if [ -z "$IP_ADDRESS" ]; then
        IP_ADDRESS=$(curl -s ipinfo.io/ip)
    fi
else
    # Если нет аргументов, получить последнюю версию EngineGP из файла на сайте
    LATEST_URL="https://resources.enginegp.com/latest"
    EGP_VERSION=$(curl -s "$LATEST_URL" | awk 'NR==1 {print $2}')
    PHP_VERSION="8.0"
    IP_ADDRESS=$(curl -s ipinfo.io/ip)
fi

# Проверяем, является ли полученный IP-адрес действительным IPv4 адресом
if [[ $IP_ADDRESS =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    sysIP=$IP_ADDRESS
else
    clear
    echo "Не удалось получить внешний IP-адрес"
    echo "Используй: ./install.sh [--ip IP-адрес]"
    exit
fi

# Обновление таблиц и системы
sysUpdate (){
    apt-get -y update
    apt-get -y upgrade
}

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
            echo "Вы выбрали: Установка панели управления"
            # Здесь добавить код для установки панели управления
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
            echo "Последняя версия EngineGP: $EGP_VERSION"
            echo "Текущая версия Linux: $verOS"
            echo "Внешний IP-адрес: $sysIP"
            echo "Версия php: $PHP_VERSION"
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