#!/bin/bash
# UFW Docker Security Script v3.1 - С ПОДДЕРЖКОЙ RUSTDESK
# Дата: 2025
# Изменения: добавлена секция для RustDesk с настраиваемыми портами

# ============================================
# ЦВЕТА ДЛЯ ВЫВОДА
# ============================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# ============================================
# ГЛОБАЛЬНЫЕ ПЕРЕМЕННЫЕ
# ============================================
SCRIPT_VERSION="3.1"
LOG_FILE="/var/log/ufw-docker-setup.log"
DRY_RUN=false

# ============================================
# КОНФИГУРАЦИЯ - настройте под свои нужды
# ============================================

# SSH порт (по умолчанию 22)
SSH_PORT=22

# ★★★ РАЗДЕЛЬНЫЕ СПИСКИ IP ★★★

# Белый список IP ТОЛЬКО для SSH доступа
SSH_ALLOWED_IPS=(
    "91.205.157.0/24"
    "91.205.216.0/22"
    "193.107.112.0/22"
    "195.18.16.0/22"
)

# Белый список IP для доступа к контейнерам и Docker сетям
DOCKER_ALLOWED_IPS=(
    "2.56.24.0/23"
    "2.59.51.0/24"
    "2.63.144.0/20"
    "2.63.176.0/20"
    "2.63.224.0/20"
    "5.144.96.0/20"
    "5.144.112.0/21"
    "5.144.120.0/22"
    "5.144.124.0/23"
    "5.189.208.0/21"
    "5.227.118.0/23"
    "5.227.120.0/23"
    "5.227.160.0/23"
    "5.227.162.0/24"
    "5.227.164.0/22"
    "5.227.170.0/23"
    "31.15.80.0/20"
    "31.29.144.0/23"
    "31.29.150.0/24"
    "31.29.177.0/24"
    "31.40.112.0/20"
    "31.40.132.0/24"
    "31.40.137.0/24"
    "31.40.138.0/24"
    "31.40.140.0/24"
    "31.40.143.0/24"
    "31.40.151.0/24"
    "31.40.153.0/24"
    "31.40.162.0/23"
    "31.40.165.0/24"
    "31.40.167.0/24"
    "31.40.172.0/23"
    "31.40.178.0/23"
    "31.40.208.0/22"
    "31.40.252.0/22"
    "31.131.92.0/22"
    "37.16.73.0/24"
    "37.44.252.0/22"
    "37.139.192.0/18"
    "37.208.96.0/22"
    "37.208.120.0/21"
    "45.90.45.0/24"
    "46.20.185.0/24"
    "46.20.186.0/23"
    "46.20.188.0/24"
    "46.20.190.0/24"
    "46.23.184.0/21"
    "46.61.245.0/24"
    "46.148.240.0/21"
    "46.148.248.0/22"
    "46.148.253.0/24"
    "46.161.9.0/24"
    "46.232.164.0/22"
    "46.250.76.0/23"
    "46.250.80.0/22"
    "62.5.128.0/17"
    "62.105.44.0/22"
    "62.105.48.0/20"
    "62.113.88.0/24"
    "62.118.0.0/18"
    "62.118.64.0/19"
    "62.118.98.0/23"
    "62.118.100.0/22"
    "62.118.104.0/23"
    "62.118.110.0/23"
    "62.118.112.0/20"
    "62.118.128.0/17"
    "62.152.64.0/19"
    "62.168.224.0/19"
    "62.182.136.0/21"
    "62.220.48.0/21"
    "77.66.128.0/19"
    "77.66.160.0/20"
    "77.66.176.0/21"
    "77.66.184.0/22"
    "77.66.188.0/23"
    "77.66.192.0/18"
    "77.83.8.0/22"
    "77.83.16.0/22"
    "77.93.124.0/22"
    "77.220.60.0/22"
    "77.239.194.0/23"
    "77.239.200.0/21"
    "77.239.208.0/20"
    "78.109.47.0/24"
    "78.136.196.0/22"
    "78.136.200.0/21"
    "78.153.0.0/19"
    "78.153.137.0/24"
    "78.153.138.0/24"
    "78.153.147.0/24"
    "79.143.238.0/23"
    "79.171.115.0/24"
    "80.80.96.0/19"
    "80.83.225.0/24"
    "80.83.228.0/22"
    "80.83.232.0/21"
    "81.23.160.0/23"
    "81.23.162.0/24"
    "81.23.164.0/22"
    "81.23.173.0/24"
    "81.23.174.0/23"
    "81.91.32.0/19"
    "81.177.72.0/22"
    "81.177.76.0/23"
    "81.177.79.0/24"
    "81.195.0.0/17"
    "81.195.128.0/20"
    "81.195.145.0/24"
    "81.195.146.0/23"
    "81.195.149.0/24"
    "81.195.150.0/24"
    "81.195.152.0/21"
    "81.195.160.0/21"
    "81.195.168.0/22"
    "81.195.173.0/24"
    "81.195.174.0/23"
    "81.195.176.0/20"
    "81.195.192.0/18"
    "81.201.16.0/20"
    "82.96.192.0/18"
    "82.204.128.0/17"
    "83.136.24.0/21"
    "83.151.0.0/20"
    "83.171.252.0/22"
    "83.172.60.0/22"
    "83.237.0.0/16"
    "83.242.128.0/18"
    "83.242.192.0/19"
    "83.242.224.0/20"
    "83.242.240.0/22"
    "84.17.0.0/19"
    "84.42.92.0/22"
    "85.115.200.0/22"
    "85.140.0.0/19"
    "85.140.40.0/22"
    "85.140.48.0/21"
    "85.140.74.0/23"
    "85.140.76.0/22"
    "85.140.88.0/21"
    "85.140.113.0/24"
    "85.140.116.0/22"
    "85.140.120.0/22"
    "85.140.124.0/23"
    "85.140.128.0/17"
    "85.141.0.0/16"
    "85.174.144.0/20"
    "85.193.64.0/22"
    "85.235.32.0/19"
    "85.235.160.0/19"
    "89.22.188.0/22"
    "89.107.136.0/22"
    "89.107.194.0/23"
    "89.169.80.0/21"
    "89.169.88.0/22"
    "89.175.0.0/16"
    "89.251.111.0/24"
    "89.251.144.0/21"
    "89.251.152.0/22"
    "89.251.156.0/23"
    "91.76.0.0/14"
    "91.103.110.0/23"
    "91.143.60.0/23"
    "91.143.63.0/24"
    "91.185.76.0/22"
    "91.185.87.0/24"
    "91.195.210.0/23"
    "91.205.157.0/24"
    "91.205.216.0/22"
    "91.211.28.0/22"
    "91.216.147.0/24"
    "91.223.226.0/24"
    "92.39.64.0/20"
    "92.43.184.0/21"
    "92.246.200.0/22"
    "92.246.216.0/22"
    "92.246.222.0/23"
    "93.90.224.0/20"
    "94.72.0.0/19"
    "94.72.32.0/20"
    "94.72.48.0/21"
    "94.72.56.0/22"
    "94.72.60.0/23"
    "94.77.128.0/18"
    "94.126.24.0/21"
    "94.140.128.0/19"
    "94.229.232.0/24"
    "94.243.0.0/20"
    "94.243.16.0/22"
    "94.243.24.0/21"
    "94.243.32.0/20"
    "94.243.48.0/22"
    "95.64.128.0/17"
    "95.104.178.0/23"
    "95.104.182.0/23"
    "95.104.224.0/19"
    "95.139.0.0/18"
    "95.139.68.0/23"
    "95.139.71.0/24"
    "95.139.76.0/22"
    "95.139.80.0/20"
    "95.139.96.0/19"
    "95.153.128.0/18"
    "95.153.208.0/20"
    "95.153.224.0/19"
    "95.169.128.0/19"
    "95.215.248.0/22"
    "109.94.220.0/22"
    "109.95.160.0/22"
    "109.105.64.0/19"
    "109.196.192.0/20"
    "109.198.224.0/19"
    "109.236.52.0/22"
    "109.236.96.0/20"
    "109.237.104.0/24"
    "141.101.232.0/24"
    "141.105.24.0/21"
    "176.52.8.0/21"
    "176.52.16.0/20"
    "176.52.32.0/22"
    "176.52.40.0/22"
    "176.52.52.0/22"
    "176.52.56.0/22"
    "176.52.64.0/24"
    "176.52.76.0/22"
    "176.52.96.0/20"
    "176.52.112.0/22"
    "176.52.120.0/24"
    "176.52.122.0/23"
    "176.52.124.0/22"
    "176.118.8.0/21"
    "176.118.16.0/21"
    "176.118.28.0/22"
    "176.119.169.0/24"
    "176.119.170.0/23"
    "176.119.172.0/24"
    "176.208.74.0/24"
    "176.211.120.0/22"
    "176.222.16.0/23"
    "176.222.200.0/21"
    "176.241.96.0/21"
    "178.34.152.0/21"
    "178.34.176.0/20"
    "178.72.64.0/20"
    "178.72.80.0/22"
    "178.72.88.0/22"
    "178.72.96.0/22"
    "178.141.0.0/16"
    "178.155.4.0/22"
    "178.155.8.0/21"
    "178.155.16.0/20"
    "178.155.32.0/19"
    "178.155.64.0/18"
    "178.159.16.0/20"
    "178.173.124.0/22"
    "178.216.216.0/21"
    "178.217.40.0/21"
    "185.15.36.0/22"
    "185.35.192.0/22"
    "185.59.137.0/24"
    "185.59.138.0/23"
    "185.64.44.0/22"
    "185.92.136.0/22"
    "185.100.101.0/24"
    "185.103.26.0/23"
    "185.116.228.0/22"
    "185.138.206.0/23"
    "185.168.236.0/22"
    "185.190.166.0/24"
    "185.224.96.0/22"
    "185.242.16.0/22"
    "188.119.76.0/24"
    "188.119.78.0/23"
    "188.124.224.0/21"
    "188.124.248.0/21"
    "188.191.86.0/23"
    "188.191.240.0/21"
    "192.162.0.0/22"
    "193.8.211.0/24"
    "193.22.148.0/22"
    "193.47.44.0/22"
    "193.56.64.0/22"
    "193.56.72.0/22"
    "193.104.27.0/24"
    "193.104.128.0/24"
    "193.107.112.0/22"
    "193.142.148.0/24"
    "193.148.52.0/22"
    "193.169.118.0/23"
    "193.189.68.0/23"
    "193.228.164.0/23"
    "193.232.55.0/24"
    "194.33.81.0/24"
    "194.50.170.0/24"
    "194.126.203.0/24"
    "194.147.48.0/22"
    "195.7.160.0/19"
    "195.18.16.0/22"
    "195.19.217.0/24"
    "195.34.0.0/20"
    "195.34.16.0/23"
    "195.34.22.0/23"
    "195.34.24.0/21"
    "195.34.32.0/19"
    "195.42.64.0/19"
    "195.62.54.0/23"
    "195.96.64.0/19"
    "195.122.224.0/19"
    "195.210.128.0/18"
    "212.30.128.0/18"
    "212.45.247.0/24"
    "212.48.32.0/19"
    "212.77.128.0/19"
    "212.109.208.0/21"
    "212.115.51.0/24"
    "212.188.0.0/18"
    "212.188.68.0/22"
    "212.188.72.0/21"
    "212.188.80.0/20"
    "212.188.96.0/19"
    "212.248.0.0/17"
    "213.27.0.0/17"
    "213.87.8.0/21"
    "213.87.34.0/23"
    "213.87.40.0/23"
    "213.87.53.0/24"
    "213.87.54.0/23"
    "213.87.56.0/21"
    "213.87.64.0/21"
    "213.87.76.0/22"
    "213.87.80.0/20"
    "213.87.98.0/23"
    "213.87.100.0/23"
    "213.87.104.0/21"
    "213.87.112.0/22"
    "213.87.118.0/23"
    "213.87.120.0/22"
    "213.87.126.0/23"
    "213.87.128.0/18"
    "213.87.200.0/21"
    "213.87.208.0/20"
    "213.87.224.0/19"
    "213.108.128.0/23"
    "213.147.32.0/19"
    "213.176.228.0/22"
    "213.176.248.0/21"
    "217.8.224.0/20"
    "217.20.64.0/20"
    "217.66.16.0/20"
    "217.66.148.0/22"
    "217.66.152.0/21"
    "217.69.192.0/19"
    "217.74.240.0/20"
    "217.173.16.0/20"
    "217.197.172.0/22"
)

# Белый список IP для RustDesk (удаленный доступ)
RUSTDESK_ALLOWED_IPS=(
)

# DNS серверы для контейнеров
DNS_SERVERS=(
    "8.8.8.8"     # Google Primary
    "8.8.4.4"     # Google Secondary
    "1.1.1.1"     # Cloudflare Primary
    "1.0.0.1"     # Cloudflare Secondary
)

# Docker сети
DOCKER_NETWORKS=(
    "10.0.0.0/8"  # Объединённая сеть (РЕКОМЕНДУЕТСЯ)
)

# Контейнеры: IP:PORT:PROTOCOL или NETWORK:PORT:PROTOCOL
CONTAINERS=(
    "10.0.0.0/8:443:tcp,udp"
    "10.0.0.0/8:4443:tcp,udp"
#    "10.0.0.0/8:51821:udp"
#    "10.0.0.0/8:80:tcp"
    "10.0.0.0/8:8080:tcp"
)

# ★★★ RUSTDESK ПОРТЫ (можно добавлять свои) ★★★
# Формат: PORT:PROTOCOL
RUSTDESK_PORTS=(
    "21115:tcp"      # NAT type test
    "21116:tcp,udp"  # ID registration and heartbeat
    "21117:tcp"      # Relay service
    # Добавьте свои порты при необходимости:
    # "21118:tcp"
    # "21119:udp"
)

# ============================================
# МЕТКИ ДЛЯ КОММЕНТАРИЕВ
# ============================================
SSH_MARKER="[UFW-DOCKER-SSH]"
FWD_MARKER="[UFW-DOCKER-FWD]"
DNS_MARKER="[UFW-DOCKER-DNS]"
RUSTDESK_MARKER="[UFW-RUSTDESK]"
TEMP_SSH_MARKER="[TEMP-SSH-PROTECTION]"

# ============================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================

log_message() {
    local level=$1
    shift
    local message="$@"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$@"
}

log_error() {
    log_message "ERROR" "$@"
    echo -e "${RED}ОШИБКА: $@${NC}"
}

log_warning() {
    log_message "WARNING" "$@"
    echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ: $@${NC}"
}

log_success() {
    log_message "SUCCESS" "$@"
}

# ============================================
# ФУНКЦИИ ВАЛИДАЦИИ
# ============================================

# Проверка что команда существует
check_command() {
    if ! command -v "$1" &> /dev/null; then
        log_error "Команда '$1' не найдена. Установите её перед запуском скрипта."
        return 1
    fi
    return 0
}

# Валидация IP адреса
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra OCTETS <<< "$ip"
        for octet in "${OCTETS[@]}"; do
            if [ "$octet" -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Валидация CIDR нотации
validate_cidr() {
    local cidr=$1
    
    if [[ ! $cidr =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/[0-9]{1,2}$ ]]; then
        return 1
    fi
    
    local ip=$(echo $cidr | cut -d'/' -f1)
    local mask=$(echo $cidr | cut -d'/' -f2)
    
    if ! validate_ip "$ip"; then
        return 1
    fi
    
    if [ "$mask" -lt 0 ] || [ "$mask" -gt 32 ]; then
        return 1
    fi
    
    return 0
}

# Проверка IP адреса или CIDR
validate_ip_or_cidr() {
    local addr=$1
    if [[ $addr =~ / ]]; then
        validate_cidr "$addr"
    else
        validate_ip "$addr"
    fi
}

# Валидация порта
validate_port() {
    local port=$1
    if [[ ! $port =~ ^[0-9]+$ ]] || [ "$port" -lt 1 ] || [ "$port" -gt 65535 ]; then
        return 1
    fi
    return 0
}

# Валидация протокола
validate_protocol() {
    local proto=$1
    if [[ ! "$proto" =~ ^(tcp|udp|tcp,udp|udp,tcp)$ ]]; then
        return 1
    fi
    return 0
}

# Валидация формата контейнера
validate_container_format() {
    local container=$1
    
    if [[ ! $container =~ ^[^:]+:[0-9]+:(tcp|udp|tcp,udp|udp,tcp)$ ]]; then
        log_error "Неверный формат контейнера: $container (ожидается IP:PORT:PROTOCOL)"
        return 1
    fi
    
    IFS=':' read -r target port protocols <<< "$container"
    
    if ! validate_ip_or_cidr "$target"; then
        log_error "Неверный IP/CIDR в контейнере: $target"
        return 1
    fi
    
    if ! validate_port "$port"; then
        log_error "Неверный порт в контейнере: $port"
        return 1
    fi
    
    if ! validate_protocol "$protocols"; then
        log_error "Неверный протокол в контейнере: $protocols"
        return 1
    fi
    
    return 0
}

# Валидация формата RustDesk порта
validate_rustdesk_port_format() {
    local port_def=$1
    
    if [[ ! $port_def =~ ^[0-9]+:(tcp|udp|tcp,udp|udp,tcp)$ ]]; then
        log_error "Неверный формат порта RustDesk: $port_def (ожидается PORT:PROTOCOL)"
        return 1
    fi
    
    IFS=':' read -r port protocols <<< "$port_def"
    
    if ! validate_port "$port"; then
        log_error "Неверный порт в RustDesk: $port"
        return 1
    fi
    
    if ! validate_protocol "$protocols"; then
        log_error "Неверный протокол в RustDesk: $protocols"
        return 1
    fi
    
    return 0
}

# Проверка IP в подсети
check_ip_in_subnet() {
    local ip=$1
    local subnet=$2
    
    # Используем python для корректной проверки
    if command -v python3 &> /dev/null; then
        result=$(python3 -c "
import ipaddress
try:
    ip_obj = ipaddress.ip_address('$ip')
    net_obj = ipaddress.ip_network('$subnet', strict=False)
    print('yes' if ip_obj in net_obj else 'no')
except:
    print('error')
" 2>/dev/null)
        
        if [ "$result" = "yes" ]; then
            return 0
        fi
    else
        # Fallback для /24 и /32 без python
        if [[ $subnet =~ /32$ ]]; then
            local subnet_ip=$(echo $subnet | cut -d'/' -f1)
            if [ "$ip" = "$subnet_ip" ]; then
                return 0
            fi
        elif [[ $subnet =~ /24$ ]]; then
            local subnet_base=$(echo $subnet | cut -d'/' -f1 | cut -d'.' -f1-3)
            local ip_base=$(echo $ip | cut -d'.' -f1-3)
            if [ "$subnet_base" = "$ip_base" ]; then
                return 0
            fi
        fi
    fi
    
    return 1
}

# ============================================
# ФУНКЦИИ ПРОВЕРКИ СИСТЕМЫ
# ============================================

check_requirements() {
    echo -e "${CYAN}=== Проверка системных требований ===${NC}"
    
    local all_ok=true
    
    # Проверка UFW
    if ! check_command "ufw"; then
        log_error "UFW не установлен. Установите: apt-get install ufw"
        all_ok=false
    else
        echo -e " ${GREEN}✓${NC} UFW установлен"
    fi
    
    # Проверка прав root
    if [ "$EUID" -ne 0 ]; then
        log_error "Скрипт должен быть запущен от root (используйте sudo)"
        all_ok=false
    else
        echo -e " ${GREEN}✓${NC} Права root"
    fi
    
    # Проверка iptables
    if ! check_command "iptables"; then
        log_error "iptables не найден"
        all_ok=false
    else
        echo -e " ${GREEN}✓${NC} iptables доступен"
    fi
    
    # Рекомендация установить python3
    if ! check_command "python3"; then
        log_warning "python3 не установлен - проверка IP в подсетях будет упрощённой"
        echo -e " ${YELLOW}⚠${NC} python3 не найден (рекомендуется установить)"
    else
        echo -e " ${GREEN}✓${NC} python3 установлен"
    fi
    
    if [ "$all_ok" = false ]; then
        echo -e "\n${RED}Не все требования выполнены. Исправьте ошибки и запустите снова.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Все требования выполнены${NC}\n"
}

# Валидация конфигурации
validate_configuration() {
    echo -e "${CYAN}=== Валидация конфигурации ===${NC}"
    
    local config_ok=true
    
    # Проверка SSH порта
    if ! validate_port "$SSH_PORT"; then
        log_error "Неверный SSH_PORT: $SSH_PORT"
        config_ok=false
    else
        echo -e " ${GREEN}✓${NC} SSH_PORT: $SSH_PORT"
    fi
    
    # Проверка SSH_ALLOWED_IPS
    if [ ${#SSH_ALLOWED_IPS[@]} -eq 0 ]; then
        log_error "SSH_ALLOWED_IPS пуст - SSH будет заблокирован!"
        config_ok=false
    else
        echo -e " ${BLUE}Проверка SSH_ALLOWED_IPS (${#SSH_ALLOWED_IPS[@]} записей):${NC}"
        for ip in "${SSH_ALLOWED_IPS[@]}"; do
            if validate_ip_or_cidr "$ip"; then
                echo -e "   ${GREEN}✓${NC} $ip"
            else
                echo -e "   ${RED}✗${NC} $ip - неверный формат"
                config_ok=false
            fi
        done
    fi
    
    # Проверка DOCKER_ALLOWED_IPS
    if [ ${#DOCKER_ALLOWED_IPS[@]} -eq 0 ]; then
        log_warning "DOCKER_ALLOWED_IPS пуст - доступ к контейнерам будет заблокирован"
    else
        echo -e " ${BLUE}Проверка DOCKER_ALLOWED_IPS (${#DOCKER_ALLOWED_IPS[@]} записей):${NC}"
        for ip in "${DOCKER_ALLOWED_IPS[@]}"; do
            if validate_ip_or_cidr "$ip"; then
                echo -e "   ${GREEN}✓${NC} $ip"
            else
                echo -e "   ${RED}✗${NC} $ip - неверный формат"
                config_ok=false
            fi
        done
    fi
    
    # Проверка RUSTDESK_ALLOWED_IPS
    if [ ${#RUSTDESK_ALLOWED_IPS[@]} -eq 0 ]; then
        log_warning "RUSTDESK_ALLOWED_IPS пуст - RustDesk будет заблокирован"
    else
        echo -e " ${BLUE}Проверка RUSTDESK_ALLOWED_IPS (${#RUSTDESK_ALLOWED_IPS[@]} записей):${NC}"
        for ip in "${RUSTDESK_ALLOWED_IPS[@]}"; do
            if validate_ip_or_cidr "$ip"; then
                echo -e "   ${GREEN}✓${NC} $ip"
                if [ "$ip" = "0.0.0.0/0" ]; then
                    echo -e "   ${YELLOW}⚠${NC} ВНИМАНИЕ: RustDesk доступен всем (небезопасно!)"
                fi
            else
                echo -e "   ${RED}✗${NC} $ip - неверный формат"
                config_ok=false
            fi
        done
    fi
    
    # Проверка RUSTDESK_PORTS
    if [ ${#RUSTDESK_PORTS[@]} -eq 0 ]; then
        log_warning "RUSTDESK_PORTS пуст - правила RustDesk не будут созданы"
    else
        echo -e " ${BLUE}Проверка RUSTDESK_PORTS (${#RUSTDESK_PORTS[@]} записей):${NC}"
        for port_def in "${RUSTDESK_PORTS[@]}"; do
            if validate_rustdesk_port_format "$port_def"; then
                echo -e "   ${GREEN}✓${NC} $port_def"
            else
                echo -e "   ${RED}✗${NC} $port_def"
                config_ok=false
            fi
        done
    fi
    
    # Проверка DNS_SERVERS
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        log_warning "DNS_SERVERS пуст - DNS не будет настроен"
    else
        echo -e " ${BLUE}Проверка DNS_SERVERS (${#DNS_SERVERS[@]} записей):${NC}"
        for dns in "${DNS_SERVERS[@]}"; do
            if validate_ip "$dns"; then
                echo -e "   ${GREEN}✓${NC} $dns"
            else
                echo -e "   ${RED}✗${NC} $dns - неверный IP"
                config_ok=false
            fi
        done
    fi
    
    # Проверка DOCKER_NETWORKS
    if [ ${#DOCKER_NETWORKS[@]} -eq 0 ]; then
        log_warning "DOCKER_NETWORKS пуст"
    else
        echo -e " ${BLUE}Проверка DOCKER_NETWORKS (${#DOCKER_NETWORKS[@]} записей):${NC}"
        for net in "${DOCKER_NETWORKS[@]}"; do
            if validate_cidr "$net"; then
                echo -e "   ${GREEN}✓${NC} $net"
            else
                echo -e "   ${RED}✗${NC} $net - неверный CIDR"
                config_ok=false
            fi
        done
    fi
    
    # Проверка CONTAINERS
    if [ ${#CONTAINERS[@]} -eq 0 ]; then
        log_warning "CONTAINERS пуст - правила для контейнеров не будут созданы"
    else
        echo -e " ${BLUE}Проверка CONTAINERS (${#CONTAINERS[@]} записей):${NC}"
        for container in "${CONTAINERS[@]}"; do
            if validate_container_format "$container"; then
                echo -e "   ${GREEN}✓${NC} $container"
            else
                echo -e "   ${RED}✗${NC} $container"
                config_ok=false
            fi
        done
    fi
    
    if [ "$config_ok" = false ]; then
        echo -e "\n${RED}Ошибки в конфигурации! Исправьте и запустите снова.${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Конфигурация валидна${NC}\n"
}

# ============================================
# ФУНКЦИИ РАБОТЫ С UFW
# ============================================

# Функция для проверки, является ли строка сетью
is_network() {
    [[ $1 =~ / ]]
}

# Безопасное удаление правила по номеру
safe_delete_rule() {
    local rule_num=$1
    local max_attempts=5
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        local rule_exists=$(ufw status numbered 2>/dev/null | grep -c "^\[$rule_num\]")
        
        if [ "$rule_exists" -eq 0 ]; then
            log_info "Правило #$rule_num уже не существует"
            return 0
        fi
        
        local rule_desc=$(ufw status numbered 2>/dev/null | grep "^\[$rule_num\]" | head -1)
        
        if echo "y" | ufw delete $rule_num > /dev/null 2>&1; then
            log_success "Удалено правило #$rule_num: $rule_desc"
            sleep 0.2
            return 0
        fi
        
        attempt=$((attempt + 1))
        log_warning "Попытка $attempt/$max_attempts удаления правила #$rule_num не удалась"
        sleep 0.3
    done
    
    log_error "Не удалось удалить правило #$rule_num после $max_attempts попыток"
    return 1
}

# Удаление всех правил по комментарию
delete_rules_by_comment() {
    local marker=$1
    local description=$2
    
    echo -e "${YELLOW}Удаление: $description${NC}"
    log_info "Начало удаления правил с маркером: $marker"
    
    local total_deleted=0
    local max_iterations=1000  # Защита от бесконечного цикла
    local iteration=0
    
    # Сначала подсчитаем сколько правил нужно удалить
    local initial_count=$(ufw status numbered 2>/dev/null | grep -F "$marker" | wc -l)
    
    if [ $initial_count -eq 0 ]; then
        echo -e " ${BLUE}Правил с маркером '$marker' не найдено${NC}"
        log_info "Правил с маркером '$marker' не найдено"
        return 0
    fi
    
    echo -e " ${BLUE}Найдено правил для удаления: $initial_count${NC}"
    
    # Если правил слишком много, запросить подтверждение
    if [ $initial_count -gt 100 ]; then
        echo -e " ${RED}⚠ ВНИМАНИЕ: Найдено $initial_count правил!${NC}"
        if [ "$DRY_RUN" = false ]; then
            read -p "Продолжить удаление? (yes/no): " confirm_delete
            if [ "$confirm_delete" != "yes" ]; then
                echo -e " ${YELLOW}Удаление отменено${NC}"
                log_info "Удаление отменено пользователем (слишком много правил)"
                return 0
            fi
        fi
    fi
    
    # Циклически удаляем правила пока они существуют
    while [ $iteration -lt $max_iterations ]; do
        iteration=$((iteration + 1))
        
        # Находим ПЕРВОЕ правило с маркером
        # Используем grep -F для точного поиска, затем awk для извлечения номера
        local rule_line=$(ufw status numbered 2>/dev/null | grep -F "$marker" | head -1)
        
        # Если правил больше нет - выходим
        if [ -z "$rule_line" ]; then
            break
        fi
        
        # Извлекаем номер правила (формат: "[ 2]" или "[10]")
        local first_rule=$(echo "$rule_line" | sed 's/^\[\s*\([0-9]*\)\].*/\1/')
        
        # Проверяем что номер валидный
        if [ -z "$first_rule" ] || ! [[ "$first_rule" =~ ^[0-9]+$ ]]; then
            log_error "Не удалось извлечь номер правила из: $rule_line"
            echo -e " ${RED}✗${NC} Ошибка извлечения номера правила"
            break
        fi
        
        # Удаляем найденное правило
        if [ "$DRY_RUN" = false ]; then
            if echo "y" | ufw delete $first_rule > /dev/null 2>&1; then
                total_deleted=$((total_deleted + 1))
                
                # Показываем прогресс каждые 10 правил
                if [ $((total_deleted % 10)) -eq 0 ]; then
                    echo -e " ${GREEN}✓${NC} Удалено $total_deleted/$initial_count правил..."
                fi
                
                log_success "Удалено правило #$first_rule с маркером '$marker'"
                sleep 0.1  # Небольшая пауза для стабильности
            else
                log_error "Не удалось удалить правило #$first_rule"
                echo -e " ${RED}✗${NC} Ошибка удаления правила #$first_rule"
                break  # Выходим при ошибке
            fi
        else
            echo -e " ${BLUE}[DRY-RUN]${NC} Удалить правило #$first_rule: $(echo "$rule_line" | cut -d'#' -f2-)"
            total_deleted=$((total_deleted + 1))
            break  # В dry-run режиме удаляем только одно для примера
        fi
    done
    
    echo -e " ${GREEN}Успешно удалено: $total_deleted из $initial_count правил${NC}"
    log_info "Удалено $total_deleted из $initial_count правил с маркером '$marker'"
    
    # Проверяем, остались ли еще правила с этим маркером
    local remaining=$(ufw status numbered 2>/dev/null | grep -F "$marker" | wc -l)
    if [ $remaining -gt 0 ]; then
        echo -e " ${RED}⚠ ВНИМАНИЕ: Осталось $remaining правил с маркером '$marker'${NC}"
        log_warning "Осталось $remaining правил с маркером '$marker'"
        
        # Показываем оставшиеся правила
        echo -e " ${YELLOW}Оставшиеся правила:${NC}"
        ufw status numbered 2>/dev/null | grep -F "$marker" | head -10
        if [ $remaining -gt 10 ]; then
            echo -e " ${BLUE}... и еще $((remaining - 10)) правил${NC}"
        fi
    fi
    
    return 0
}

# Безопасное добавление правила
safe_add_rule() {
    local rule_cmd="$@"
    
    if [ "$DRY_RUN" = true ]; then
        echo -e " ${BLUE}[DRY-RUN]${NC} $rule_cmd"
        log_info "[DRY-RUN] $rule_cmd"
        return 0
    fi
    
    if eval "$rule_cmd" > /dev/null 2>&1; then
        log_success "Добавлено правило: $rule_cmd"
        return 0
    else
        log_error "Не удалось добавить правило: $rule_cmd"
        return 1
    fi
}

# ============================================
# ФУНКЦИЯ РЕЖИМА ТОЛЬКО УДАЛЕНИЯ
# ============================================

cleanup_only() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║          РЕЖИМ: ТОЛЬКО УДАЛЕНИЕ ПРАВИЛ                ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    
    log_info "=== Запуск режима только удаления ==="
    
    echo -e "\n${YELLOW}Будут удалены следующие типы правил:${NC}"
    echo -e " ${RED}•${NC} SSH правила (с маркером $SSH_MARKER)"
    echo -e " ${RED}•${NC} FWD правила для контейнеров (с маркером $FWD_MARKER)"
    echo -e " ${RED}•${NC} DNS правила (с маркером $DNS_MARKER)"
    echo -e " ${RED}•${NC} RustDesk правила (с маркером $RUSTDESK_MARKER)"
    echo -e " ${RED}•${NC} Временные SSH правила (с маркером $TEMP_SSH_MARKER)"
    
    echo -e "\n${RED}ВНИМАНИЕ: После удаления правил ваш SSH может быть заблокирован!${NC}"
    read -p "Вы уверены? Введите 'DELETE' для подтверждения: " confirm
    
    if [ "$confirm" != "DELETE" ]; then
        echo -e "${YELLOW}Отмена операции.${NC}"
        log_info "Операция удаления отменена пользователем"
        exit 0
    fi
    
    echo -e "\n${YELLOW}=== Удаление SSH правил ===${NC}"
    delete_rules_by_comment "$SSH_MARKER" "SSH правила"
    
    echo -e "\n${YELLOW}=== Удаление FWD правил (контейнеры) ===${NC}"
    delete_rules_by_comment "$FWD_MARKER" "FWD правила для контейнеров"
    
    echo -e "\n${YELLOW}=== Удаление DNS правил ===${NC}"
    delete_rules_by_comment "$DNS_MARKER" "DNS правила"
    
    echo -e "\n${YELLOW}=== Удаление RustDesk правил ===${NC}"
    delete_rules_by_comment "$RUSTDESK_MARKER" "RustDesk правила"
    
    echo -e "\n${YELLOW}=== Удаление временных SSH правил ===${NC}"
    delete_rules_by_comment "$TEMP_SSH_MARKER" "Временные SSH правила"
    
    echo -e "\n${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          УДАЛЕНИЕ ЗАВЕРШЕНО                           ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BLUE}Оставшиеся правила UFW:${NC}"
    ufw status numbered
    
    echo -e "\n${YELLOW}Перезагрузка UFW...${NC}"
    if ufw reload > /dev/null 2>&1; then
        echo -e "${GREEN}✓ UFW правила перезагружены${NC}"
        log_success "UFW перезагружен после удаления правил"
    else
        echo -e "${RED}✗ Ошибка перезагрузки UFW${NC}"
        log_error "Не удалось перезагрузить UFW"
    fi
    
    log_info "=== Режим только удаления завершён ==="
    exit 0
}

# ============================================
# ФУНКЦИЯ СОЗДАНИЯ SSH ПРАВИЛ
# ============================================

create_ssh_rules() {
    echo -e "\n${YELLOW}═══ Настройка SSH (белый список) ═══${NC}"
    echo -e "${BLUE}SSH порт: $SSH_PORT${NC}"
    echo -e "${BLUE}Разрешённых IP для SSH: ${#SSH_ALLOWED_IPS[@]}${NC}"
    log_info "=== Настройка SSH правил ==="
    
    local ssh_rules_added=0
    
    for ip in "${SSH_ALLOWED_IPS[@]}"; do
        if safe_add_rule "ufw allow from $ip to any port $SSH_PORT proto tcp comment '$SSH_MARKER SSH:$SSH_PORT from $ip'"; then
            echo -e " ${GREEN}✓${NC} SSH:$SSH_PORT разрешён для $ip"
            ssh_rules_added=$((ssh_rules_added + 1))
        else
            echo -e " ${RED}✗${NC} Не удалось добавить правило для $ip"
        fi
    done
    
    echo -e "\n${GREEN}Добавлено SSH правил: $ssh_rules_added из ${#SSH_ALLOWED_IPS[@]}${NC}"
    log_info "Добавлено SSH правил: $ssh_rules_added из ${#SSH_ALLOWED_IPS[@]}"
}

# ============================================
# ФУНКЦИЯ СОЗДАНИЯ ПРАВИЛ ДЛЯ RUSTDESK
# ============================================

create_rustdesk_rules() {
    echo -e "\n${YELLOW}═══ Входящие правила для RustDesk (удаленный доступ) ═══${NC}"
    echo -e "${BLUE}Разрешённых IP для RustDesk: ${#RUSTDESK_ALLOWED_IPS[@]}${NC}"
    log_info "=== Настройка правил для RustDesk ==="
    
    if [ ${#RUSTDESK_PORTS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ RUSTDESK_PORTS пуст, пропуск${NC}"
        log_warning "Массив RUSTDESK_PORTS пуст"
        return 0
    fi
    
    if [ ${#RUSTDESK_ALLOWED_IPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ RUSTDESK_ALLOWED_IPS пуст, пропуск${NC}"
        log_warning "Массив RUSTDESK_ALLOWED_IPS пуст"
        return 0
    fi
    
    local rules_added=0
    local rules_failed=0
    
    # Проверяем наличие 0.0.0.0/0 (доступ для всех)
    local allow_all=false
    for ip in "${RUSTDESK_ALLOWED_IPS[@]}"; do
        if [ "$ip" = "0.0.0.0/0" ]; then
            allow_all=true
            break
        fi
    done
    
    if [ "$allow_all" = true ]; then
        echo -e "\n${YELLOW}⚠ ВНИМАНИЕ: RustDesk разрешён для ВСЕХ IP (0.0.0.0/0)${NC}"
        echo -e "${YELLOW}⚠ Рекомендуется ограничить доступ конкретными IP!${NC}\n"
    fi
    
    for port_def in "${RUSTDESK_PORTS[@]}"; do
        if ! validate_rustdesk_port_format "$port_def"; then
            echo -e " ${RED}✗${NC} Пропуск невалидного: $port_def"
            rules_failed=$((rules_failed + 1))
            continue
        fi
        
        IFS=':' read -r port protocols <<< "$port_def"
        IFS=',' read -ra proto_array <<< "$protocols"
        
        echo -e "\n${BLUE}RustDesk порт: $port${NC}"
        
        for ip in "${RUSTDESK_ALLOWED_IPS[@]}"; do
            for proto in "${proto_array[@]}"; do
                if safe_add_rule "ufw allow from $ip to any port $port proto $proto comment '$RUSTDESK_MARKER RustDesk:$port from $ip'"; then
                    echo -e " ${GREEN}✓${NC} $proto $ip → порт $port"
                    rules_added=$((rules_added + 1))
                else
                    echo -e " ${RED}✗${NC} $proto $ip → порт $port"
                    rules_failed=$((rules_failed + 1))
                fi
            done
        done
    done
    
    echo -e "\n${GREEN}Добавлено правил для RustDesk: $rules_added${NC}"
    if [ $rules_failed -gt 0 ]; then
        echo -e "${RED}Не удалось добавить: $rules_failed${NC}"
    fi
    log_info "Правил для RustDesk: добавлено=$rules_added, failed=$rules_failed"
}

# ============================================
# ФУНКЦИЯ СОЗДАНИЯ ПРАВИЛ ДЛЯ КОНТЕЙНЕРОВ
# ============================================

create_container_rules() {
    echo -e "\n${YELLOW}═══ Входящие правила для контейнеров ═══${NC}"
    echo -e "${BLUE}Разрешённых IP для Docker: ${#DOCKER_ALLOWED_IPS[@]}${NC}"
    log_info "=== Настройка правил для контейнеров ==="
    
    if [ ${#CONTAINERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ CONTAINERS пуст, пропуск${NC}"
        log_warning "Массив CONTAINERS пуст"
        return 0
    fi
    
    if [ ${#DOCKER_ALLOWED_IPS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ DOCKER_ALLOWED_IPS пуст, пропуск${NC}"
        log_warning "Массив DOCKER_ALLOWED_IPS пуст"
        return 0
    fi
    
    local rules_added=0
    local rules_failed=0
    
    for container in "${CONTAINERS[@]}"; do
        if ! validate_container_format "$container"; then
            echo -e " ${RED}✗${NC} Пропуск невалидного: $container"
            rules_failed=$((rules_failed + 1))
            continue
        fi
        
        IFS=':' read -r container_target container_port protocols <<< "$container"
        IFS=',' read -ra proto_array <<< "$protocols"
        
        if is_network "$container_target"; then
            echo -e "\n${BLUE}Сеть: $container_target:$container_port${NC}"
        else
            echo -e "\n${BLUE}Контейнер: $container_target:$container_port${NC}"
        fi
        
        for ip in "${DOCKER_ALLOWED_IPS[@]}"; do
            for proto in "${proto_array[@]}"; do
                if safe_add_rule "ufw route allow proto $proto from $ip to $container_target port $container_port comment '$FWD_MARKER $container_target:$container_port from $ip'"; then
                    echo -e " ${GREEN}✓${NC} $proto $ip → $container_target:$container_port"
                    rules_added=$((rules_added + 1))
                else
                    echo -e " ${RED}✗${NC} $proto $ip → $container_target:$container_port"
                    rules_failed=$((rules_failed + 1))
                fi
            done
        done
    done
    
    echo -e "\n${GREEN}Добавлено правил для контейнеров: $rules_added${NC}"
    if [ $rules_failed -gt 0 ]; then
        echo -e "${RED}Не удалось добавить: $rules_failed${NC}"
    fi
    log_info "Правил для контейнеров: добавлено=$rules_added, failed=$rules_failed"
}

# ============================================
# ФУНКЦИЯ СОЗДАНИЯ DNS ПРАВИЛ (ОТДЕЛЬНО!)
# ============================================

create_dns_rules() {
    echo -e "\n${YELLOW}═══ DNS правила для контейнеров (отдельные) ═══${NC}"
    echo -e "${BLUE}Настройка DNS на портах 53 и 443${NC}"
    log_info "=== Настройка DNS правил (отдельно) ==="
    
    if [ ${#DOCKER_NETWORKS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ DOCKER_NETWORKS пуст, пропуск DNS${NC}"
        log_warning "Массив DOCKER_NETWORKS пуст"
        return 0
    fi
    
    if [ ${#DNS_SERVERS[@]} -eq 0 ]; then
        echo -e "${YELLOW}⚠ DNS_SERVERS пуст, пропуск DNS${NC}"
        log_warning "Массив DNS_SERVERS пуст"
        return 0
    fi
    
    local dns_rules_added=0
    
    # ★★★ ВАЖНО: DNS правила создаются ВСЕГДА отдельно для каждой сети ★★★
    echo -e "${CYAN}DNS правила создаются отдельно для каждой сети (без оптимизации)${NC}"
    
    for network in "${DOCKER_NETWORKS[@]}"; do
        echo -e "\n${BLUE}Сеть: $network${NC}"
        
        for dns in "${DNS_SERVERS[@]}"; do
            echo -e " ${CYAN}DNS сервер: $dns${NC}"
            
            # ★★★ Порт 53 - ОТДЕЛЬНЫЕ правила для каждого направления и протокола ★★★
            
            # UDP 53: сеть → DNS
            if safe_add_rule "ufw route allow proto udp from $network to $dns port 53 comment '$DNS_MARKER DNS:53 UDP $network→$dns'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} UDP $network → $dns:53"
            fi
            
            # TCP 53: сеть → DNS
            if safe_add_rule "ufw route allow proto tcp from $network to $dns port 53 comment '$DNS_MARKER DNS:53 TCP $network→$dns'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} TCP $network → $dns:53"
            fi
            
            # UDP 53: DNS → сеть (обратное направление)
            if safe_add_rule "ufw route allow proto udp from $dns port 53 to $network comment '$DNS_MARKER DNS:53 UDP $dns→$network'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} UDP $dns:53 → $network"
            fi
            
            # TCP 53: DNS → сеть (обратное направление)
            if safe_add_rule "ufw route allow proto tcp from $dns port 53 to $network comment '$DNS_MARKER DNS:53 TCP $dns→$network'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} TCP $dns:53 → $network"
            fi
            
            # ★★★ Порт 443 (DoH/DoT) - ОТДЕЛЬНЫЕ правила ★★★
            
            # TCP 443: сеть → DNS
            if safe_add_rule "ufw route allow proto tcp from $network to $dns port 443 comment '$DNS_MARKER DoH:443 TCP $network→$dns'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} TCP DoH $network → $dns:443"
            fi
            
            # UDP 443: сеть → DNS (DoQ - DNS over QUIC)
            if safe_add_rule "ufw route allow proto udp from $network to $dns port 443 comment '$DNS_MARKER DoH:443 UDP $network→$dns'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} UDP DoQ $network → $dns:443"
            fi
            
            # TCP 443: DNS → сеть (обратное направление)
            if safe_add_rule "ufw route allow proto tcp from $dns port 443 to $network comment '$DNS_MARKER DoH:443 TCP $dns→$network'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} TCP DoH $dns:443 → $network"
            fi
            
            # UDP 443: DNS → сеть (обратное направление)
            if safe_add_rule "ufw route allow proto udp from $dns port 443 to $network comment '$DNS_MARKER DoH:443 UDP $dns→$network'"; then
                dns_rules_added=$((dns_rules_added + 1))
                echo -e "   ${GREEN}✓${NC} UDP DoQ $dns:443 → $network"
            fi
        done
    done
    
    echo -e "\n${GREEN}Добавлено DNS правил: $dns_rules_added${NC}"
    echo -e "${YELLOW}Примечание: DNS правила созданы отдельно для каждой сети и направления${NC}"
    log_info "Добавлено DNS правил: $dns_rules_added (отдельные правила)"
}

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================

main() {
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}  UFW Docker Security Script v${SCRIPT_VERSION} (+ RUSTDESK)${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${NC}"
    echo ""
    
    log_info "=== Запуск скрипта v${SCRIPT_VERSION} ==="
    log_info "Пользователь: $(whoami), PID: $$"
    
    # Проверка требований
    check_requirements
    
    # Валидация конфигурации
    validate_configuration
    
    # ============================================
    # ВЫБОР РЕЖИМА РАБОТЫ
    # ============================================
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              ВЫБЕРИТЕ РЕЖИМ РАБОТЫ                    ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}1)${NC} Удалить старые правила и создать новые (полная настройка)"
    echo -e "${YELLOW}2)${NC} Только удалить правила без создания новых"
    echo -e "${BLUE}3)${NC} Только создать новые правила (не удаляя старые)"
    echo -e "${MAGENTA}4)${NC} DRY-RUN режим (показать что будет сделано)"
    echo -e "${RED}5)${NC} Выход"
    echo ""
    read -p "Ваш выбор (1-5): " mode_choice
    
    case $mode_choice in
        1)
            echo -e "${GREEN}Выбран режим: Полная настройка (удаление + создание)${NC}"
            MODE="full"
            log_info "Выбран режим: full"
            ;;
        2)
            echo -e "${YELLOW}Выбран режим: Только удаление${NC}"
            log_info "Выбран режим: cleanup_only"
            cleanup_only
            ;;
        3)
            echo -e "${BLUE}Выбран режим: Только создание${NC}"
            MODE="create"
            log_info "Выбран режим: create"
            ;;
        4)
            echo -e "${MAGENTA}Выбран режим: DRY-RUN${NC}"
            MODE="full"
            DRY_RUN=true
            log_info "Выбран режим: dry-run"
            echo -e "${YELLOW}⚠ Изменения НЕ будут применены, только показаны${NC}"
            ;;
        5)
            echo -e "${RED}Выход из скрипта${NC}"
            log_info "Выход по запросу пользователя"
            exit 0
            ;;
        *)
            echo -e "${RED}Неверный выбор. Выход.${NC}"
            log_error "Неверный выбор режима: $mode_choice"
            exit 1
            ;;
    esac
    
    # ============================================
    # ОПРЕДЕЛЕНИЕ ТЕКУЩЕГО SSH СОЕДИНЕНИЯ
    # ============================================
    
    echo -e "\n${CYAN}=== Определение текущего SSH соединения ===${NC}"
    
    CURRENT_IP=""
    
    if [ -n "$SSH_CLIENT" ]; then
        CURRENT_IP=$(echo $SSH_CLIENT | awk '{print $1}')
        echo -e "${BLUE}IP определён через SSH_CLIENT: $CURRENT_IP${NC}"
    elif [ -n "$SSH_CONNECTION" ]; then
        CURRENT_IP=$(echo $SSH_CONNECTION | awk '{print $1}')
        echo -e "${BLUE}IP определён через SSH_CONNECTION: $CURRENT_IP${NC}"
    fi
    
    if [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "127.0.0.1" ]; then
        if validate_ip "$CURRENT_IP"; then
            echo -e "${GREEN}✓ Текущий IP: $CURRENT_IP${NC}"
            log_info "Текущий SSH IP: $CURRENT_IP"
        else
            echo -e "${YELLOW}⚠ Невалидный IP: $CURRENT_IP, сброшен${NC}"
            CURRENT_IP=""
        fi
    else
        CURRENT_IP=""
    fi
    
    IS_SSH=false
    if [ -n "$SSH_CLIENT" ] || [ -n "$SSH_TTY" ] || [ -n "$SSH_CONNECTION" ]; then
        IS_SSH=true
        echo -e "${BLUE}Обнаружено SSH подключение${NC}"
        log_info "Обнаружено SSH подключение"
    else
        echo -e "${YELLOW}SSH подключение не обнаружено (локальная сессия?)${NC}"
        log_info "SSH подключение не обнаружено"
    fi
    
    # ============================================
    # РЕЖИМ FULL: ОЧИСТКА СУЩЕСТВУЮЩИХ ПРАВИЛ
    # ============================================
    
    if [ "$MODE" = "full" ]; then
        echo -e "\n${YELLOW}═══ Шаг 1: Подготовка к очистке правил UFW ═══${NC}"
        log_info "=== Начало очистки правил UFW ==="
        
        echo -e "\n${BLUE}Текущие правила UFW:${NC}"
        ufw status numbered | head -30
        total_rules=$(ufw status numbered 2>/dev/null | grep -c "^\[")
        if [ $total_rules -gt 30 ]; then
            echo -e "${BLUE}... и ещё $((total_rules - 30)) правил${NC}"
        fi
        
        # Добавляем временную защиту SSH
        if [ "$IS_SSH" = true ] && [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "127.0.0.1" ]; then
            echo -e "\n${BLUE}═══ КРИТИЧНО: Защита SSH соединения ═══${NC}"
            echo -e "${YELLOW}⚠ Обнаружено SSH подключение с IP: $CURRENT_IP${NC}"
            echo -e "${YELLOW}⚠ Добавляется временная защита SSH${NC}"
            
            if ! ufw status 2>/dev/null | grep -q "$CURRENT_IP.*$SSH_PORT/tcp"; then
                if [ "$DRY_RUN" = false ]; then
                    if ufw insert 1 allow from $CURRENT_IP to any port $SSH_PORT proto tcp comment "$TEMP_SSH_MARKER SSH from $CURRENT_IP" > /dev/null 2>&1; then
                        echo -e "${GREEN}✓ Добавлено временное SSH правило для $CURRENT_IP:$SSH_PORT${NC}"
                        log_success "Добавлено временное SSH правило для $CURRENT_IP"
                    else
                        echo -e "${RED}✗ Не удалось добавить временное SSH правило!${NC}"
                        log_error "Не удалось добавить временное SSH правило"
                    fi
                else
                    echo -e " ${BLUE}[DRY-RUN]${NC} ufw insert 1 allow from $CURRENT_IP to any port $SSH_PORT"
                fi
            fi
        fi
        
        # Подтверждение удаления
        echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║ ВНИМАНИЕ: Сейчас начнется удаление правил UFW!        ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
        
        if [ "$DRY_RUN" = false ]; then
            read -p "Подтвердите начало очистки (yes/no): " confirm
            if [ "$confirm" != "yes" ]; then
                echo -e "${YELLOW}Отмена.${NC}"
                log_info "Очистка отменена пользователем"
                exit 1
            fi
        fi
        
        echo -e "\n${YELLOW}═══ Шаг 2: Удаление правил UFW ═══${NC}"
        
        delete_rules_by_comment "$SSH_MARKER" "SSH правила скрипта"
        delete_rules_by_comment "$FWD_MARKER" "FWD правила для контейнеров"
        delete_rules_by_comment "$DNS_MARKER" "DNS правила"
        delete_rules_by_comment "$RUSTDESK_MARKER" "RustDesk правила"
        
        echo -e "\n${GREEN}✓ Очистка правил завершена${NC}"
        log_success "Очистка правил завершена"
        
        # Установка политик
        echo -e "\n${YELLOW}═══ Шаг 3: Установка политик по умолчанию ═══${NC}"
        if [ "$DRY_RUN" = false ]; then
            ufw --force default deny incoming
            ufw --force default allow outgoing
            ufw --force default deny forward
            ufw --force default deny routed
            echo -e "${GREEN}✓ Политики установлены${NC}"
            log_success "Политики установлены"
        else
            echo -e " ${BLUE}[DRY-RUN]${NC} Установка политик"
        fi
    fi
    
    # ============================================
    # СОЗДАНИЕ НОВЫХ ПРАВИЛ
    # ============================================
    
    if [ "$MODE" = "full" ] || [ "$MODE" = "create" ]; then
        
        echo -e "\n${YELLOW}═══ Шаг 4: Создание новых правил ═══${NC}"
        
        # 1. SSH правила (отдельный список IP)
        create_ssh_rules
        
        # Применяем SSH правила перед удалением временной защиты
        if [ "$MODE" = "full" ] && [ "$DRY_RUN" = false ]; then
            echo -e "\n${YELLOW}Применение SSH правил...${NC}"
            if ufw reload > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Правила применены${NC}"
                sleep 2
            fi
        fi
        
        # Удаляем временное правило
        if [ "$MODE" = "full" ] && [ "$IS_SSH" = true ] && [ "$DRY_RUN" = false ]; then
            echo -e "\n${YELLOW}Удаление временного SSH правила...${NC}"
            temp_rule=$(ufw status numbered 2>/dev/null | grep "$TEMP_SSH_MARKER" | head -1 | grep -oE '^\[[0-9]+\]' | tr -d '[]')
            if [ -n "$temp_rule" ]; then
                if safe_delete_rule $temp_rule; then
                    echo -e "${GREEN}✓ Временное правило удалено безопасно${NC}"
                fi
            fi
        fi
        
        # Проверка текущего IP в белом списке SSH
        if [ "$IS_SSH" = true ] && [ -n "$CURRENT_IP" ] && [ "$CURRENT_IP" != "127.0.0.1" ]; then
            echo -e "\n${CYAN}Проверка вашего IP в SSH белом списке...${NC}"
            IP_IN_SSH_WHITELIST=false
            
            for ip in "${SSH_ALLOWED_IPS[@]}"; do
                if [[ $ip == *"/"* ]]; then
                    if check_ip_in_subnet "$CURRENT_IP" "$ip"; then
                        IP_IN_SSH_WHITELIST=true
                        echo -e "${GREEN}✓ Ваш IP ($CURRENT_IP) в SSH белом списке (подсеть $ip)${NC}"
                        break
                    fi
                else
                    if [ "$CURRENT_IP" = "$ip" ]; then
                        IP_IN_SSH_WHITELIST=true
                        echo -e "${GREEN}✓ Ваш IP ($CURRENT_IP) в SSH белом списке${NC}"
                        break
                    fi
                fi
            done
            
            if [ "$IP_IN_SSH_WHITELIST" = false ]; then
                echo -e "\n${RED}╔════════════════════════════════════════════════════════╗${NC}"
                echo -e "${RED}║ ⚠ ПРЕДУПРЕЖДЕНИЕ: IP НЕ В SSH БЕЛОМ СПИСКЕ!          ║${NC}"
                echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
                echo -e "${YELLOW}Ваш IP: $CURRENT_IP не в SSH_ALLOWED_IPS!${NC}"
                echo -e "${YELLOW}Добавляется временное правило${NC}"
                
                if safe_add_rule "ufw insert 1 allow from $CURRENT_IP to any port $SSH_PORT proto tcp comment '$TEMP_SSH_MARKER CURRENT SSH $CURRENT_IP'"; then
                    echo -e "${GREEN}✓ Временное SSH правило добавлено${NC}"
                    echo -e "${RED}⚠ ДОБАВЬТЕ $CURRENT_IP в SSH_ALLOWED_IPS!${NC}"
                fi
            fi
        fi
        
        # 2. RustDesk правила (отдельный список IP, входящие)
        create_rustdesk_rules
        
        # 3. Правила для контейнеров (отдельный список IP)
        create_container_rules
        
        # 4. DNS правила (ВСЕГДА отдельно!)
        create_dns_rules
        
        # ============================================
        # ВКЛЮЧЕНИЕ И ПЕРЕЗАГРУЗКА UFW
        # ============================================
        
        echo -e "\n${YELLOW}═══ Шаг 5: Включение UFW ═══${NC}"
        if [ "$DRY_RUN" = false ]; then
            if ufw --force enable > /dev/null 2>&1; then
                echo -e "${GREEN}✓ UFW включен${NC}"
                log_success "UFW включен"
            fi
        else
            echo -e " ${BLUE}[DRY-RUN]${NC} ufw --force enable"
        fi
        
        echo -e "\n${YELLOW}═══ Шаг 6: Перезагрузка правил ═══${NC}"
        if [ "$DRY_RUN" = false ]; then
            if ufw reload > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Правила перезагружены${NC}"
                log_success "Правила перезагружены"
            fi
        else
            echo -e " ${BLUE}[DRY-RUN]${NC} ufw reload"
        fi
        
        # ============================================
        # ИТОГОВАЯ ИНФОРМАЦИЯ
        # ============================================
        
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║          НАСТРОЙКА УСПЕШНО ЗАВЕРШЕНА                  ║${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        if [ "$DRY_RUN" = true ]; then
            echo -e "${MAGENTA}═══ DRY-RUN: Изменения НЕ применены ═══${NC}\n"
        fi
        
        total_final_rules=$(ufw status numbered 2>/dev/null | grep -c "^\[")
        
        echo -e "${BLUE}Статистика:${NC}"
        echo -e " ${GREEN}✓${NC} Всего правил UFW: $total_final_rules"
        echo -e " ${GREEN}✓${NC} IP для SSH: ${#SSH_ALLOWED_IPS[@]}"
        echo -e " ${GREEN}✓${NC} IP для RustDesk: ${#RUSTDESK_ALLOWED_IPS[@]}"
        echo -e " ${GREEN}✓${NC} Портов RustDesk: ${#RUSTDESK_PORTS[@]}"
        echo -e " ${GREEN}✓${NC} IP для Docker: ${#DOCKER_ALLOWED_IPS[@]}"
        echo -e " ${GREEN}✓${NC} DNS серверов: ${#DNS_SERVERS[@]}"
        echo -e " ${GREEN}✓${NC} Docker сетей: ${#DOCKER_NETWORKS[@]}"
        echo -e " ${GREEN}✓${NC} Контейнеров: ${#CONTAINERS[@]}"
        echo ""
        
        echo -e "${YELLOW}--- Правила UFW (первые 50) ---${NC}"
        ufw status numbered | head -50
        if [ $total_final_rules -gt 50 ]; then
            echo -e "${BLUE}... всего правил: $total_final_rules${NC}"
        fi
        echo ""
        
        # Важные замечания
        echo -e "${RED}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${RED}║                ВАЖНЫЕ ЗАМЕЧАНИЯ                       ║${NC}"
        echo -e "${RED}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}⚠ SSH порт: $SSH_PORT${NC}"
        echo -e "${YELLOW}⚠ SSH белый список: ${#SSH_ALLOWED_IPS[@]} IP${NC}"
        echo -e "${YELLOW}⚠ RustDesk белый список: ${#RUSTDESK_ALLOWED_IPS[@]} IP${NC}"
        echo -e "${YELLOW}⚠ Docker белый список: ${#DOCKER_ALLOWED_IPS[@]} IP${NC}"
        echo -e "${YELLOW}⚠ DNS правила созданы ОТДЕЛЬНО для каждой сети${NC}"
        if [ -n "$CURRENT_IP" ]; then
            echo -e "${YELLOW}⚠ Ваш SSH IP: $CURRENT_IP${NC}"
        fi
        echo -e "${YELLOW}⚠ КРИТИЧНО: Проверьте SSH в новой сессии!${NC}"
        echo ""
        
        echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║          КЛЮЧЕВЫЕ УЛУЧШЕНИЯ v3.1                      ║${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${GREEN}✓${NC} Раздельные списки IP для SSH, RustDesk и Docker"
        echo -e "${GREEN}✓${NC} Настраиваемые порты RustDesk (21115-21117 по умолчанию)"
        echo -e "${GREEN}✓${NC} RustDesk правила создаются как входящие (не route)"
        echo -e "${GREEN}✓${NC} DNS правила создаются ОТДЕЛЬНО (не дублируются)"
        echo -e "${GREEN}✓${NC} Режим только удаления (опция 2)"
        echo -e "${GREEN}✓${NC} Режим удаление + создание (опция 1)"
        echo -e "${GREEN}✓${NC} Режим только создание (опция 3)"
        echo ""
    fi
    
    echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║             СКРИПТ ЗАВЕРШЁН УСПЕШНО                   ║${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "=== Скрипт завершён успешно ==="
    
    if [ "$DRY_RUN" = false ]; then
        echo -e "${GREEN}✓ Лог сохранён: $LOG_FILE${NC}"
    fi
    echo ""
}

# ============================================
# ЗАПУСК ГЛАВНОЙ ФУНКЦИИ
# ============================================

main "$@"
