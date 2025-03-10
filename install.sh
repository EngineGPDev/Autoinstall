#!/bin/bash
##
# EngineGP   (https://enginegp.ru or https://enginegp.com)
#
# @copyright Copyright (c) 2024-present Solovev Sergei <inbox@seansolovev.ru>
#
# @link      https://github.com/EngineGPDev/Autoinstall for the canonical source repository
#
# @license   https://github.com/EngineGPDev/Autoinstall/blob/main/LICENSE MIT License
##

clear

# Arrays and variables used
suppOs=("debian" "ubuntu")
aptOs=("debian" "ubuntu")
currOs=$(grep ^ID= /etc/os-release | awk -F= '{print $2}')
logsInst="/var/log/enginegp_install.log"

# User verification
if [ "$(whoami)" != "root" ]; then
    echo "It needs to be run under the root user!" 2>&1 | tee -a "$logsInst"
    exit 1
fi

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
relArgs=()

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
            --release|--beta|--snapshot)
                relArgs+=("$key")
                shift # Пропустить аргументы
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

# Checking for system support
foundOs=false
for os in "${suppOs[@]}"; do
    if [[ "$os" == "$currOs" ]]; then
        foundOs=true
        break
    fi
done

# Downloading and running the installation file
if $foundOs; then
    for os in "${aptOs[@]}"; do
        if [[ "$os" == "$currOs" ]]; then
            # Required packages
            pkgsList=("jq" "curl" "zip" "unzip")

            # Updating the package list
            echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
            echo "Updating the package list..." | tee -a "$logsInst"
            echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
            apt-get -y update 2>&1 | tee -a "$logsInst" > /dev/null

            # Check and installation sudo
            if ! dpkg-query -W -f='${Status}' "sudo" 2>/dev/null | grep -q "install ok installed"; then
                echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
                echo "sudo not installed. Installation in progress..." | tee -a "$logsInst"
                echo "===================================" 2>&1 | tee -a "$logsInst" > /dev/null
                apt-get install -y sudo 2>&1 | tee -a "$logsInst" > /dev/null
            fi

            # Package installation cycle
            for package in "${pkgsList[@]}"; do
                # Checking for packages and installing packages
                if ! dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    echo "$package not installed. Installation in progress..." | tee -a "$logsInst"
                    echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                    sudo apt-get install -y "$package" 2>&1 | sudo tee -a "$logsInst" > /dev/null
                fi
            done

            # Preparing a temporary catalog
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Preparing a temporary catalog" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo mkdir -p /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo rm -rf /tmp/enginegp/* 2>&1 | sudo tee -a "$logsInst" > /dev/null

            # Downloading the installation script
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Downloading the installation script" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            curl -s https://api.github.com/repos/EngineGPDev/Autoinstall/releases | jq -r 'map(select(.prerelease == true)) | .[0].zipball_url' | xargs -n 1 curl -L -o /tmp/enginegp/autoinstall.zip 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo unzip -o /tmp/enginegp/autoinstall.zip -d /tmp/enginegp 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo mv /tmp/enginegp/*Autoinstall-* /tmp/enginegp/autoinstall 2>&1 | sudo tee -a "$logsInst" > /dev/null

            # Starting the automatic installation
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            echo "Starting the automatic installation" | tee -a "$logsInst"
            echo "===================================" 2>&1 | sudo tee -a "$logsInst" > /dev/null
            sudo chmod +x /tmp/enginegp/autoinstall/deb.install.sh 2>&1 | sudo tee -a "$logsInst" > /dev/null
            # Передача значений в команду
            if [ ${#relArgs[@]} -gt 0 ]; then
                sudo /tmp/enginegp/autoinstall/deb.install.sh --php "$verPhp" --ip "$sysIp" "${relArgs[@]}"
            else
                sudo /tmp/enginegp/autoinstall/deb.install.sh --php "$verPhp" --ip "$sysIp"
            fi
        fi
    done
else
    echo "Your system is not supported." 2>&1 | tee -a "$logsInst"
fi
