#!/bin/bash
# ============================================
# IP Generator Script v1.0
# ============================================
# Генерирует списки IP адресов из различных источников:
# - ASN (Autonomous System Numbers)
# - Страны (Countries)
# - Города (Cities)
# - Прямые IP/CIDR
# ============================================

set -e  # Остановка при ошибках

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Глобальные переменные
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-${SCRIPT_DIR}/ip-config.yml}"
OUTPUT_DIR="${OUTPUT_DIR:-${SCRIPT_DIR}/generated-ips}"
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/.cache}"
MAXMIND_LICENSE_KEY="${MAXMIND_LICENSE_KEY:-}"

# Создаем директории
mkdir -p "$OUTPUT_DIR"
mkdir -p "$CACHE_DIR"

# ============================================
# ФУНКЦИИ ЛОГИРОВАНИЯ
# ============================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# ============================================
# ПРОВЕРКА ЗАВИСИМОСТЕЙ
# ============================================

check_dependencies() {
    log_info "Проверка зависимостей..."

    local deps_ok=true

    # Обязательные зависимости
    for cmd in curl jq python3; do
        if ! command -v "$cmd" &> /dev/null; then
            log_error "Команда '$cmd' не найдена. Установите её."
            deps_ok=false
        else
            log_success "✓ $cmd установлен"
        fi
    done

    # Опциональные зависимости
    if ! command -v yq &> /dev/null; then
        log_warning "yq не найден. Используется python для парсинга YAML."
    fi

    if [ "$deps_ok" = false ]; then
        log_error "Не все зависимости установлены. Выход."
        exit 1
    fi

    log_success "Все зависимости установлены"
}

# ============================================
# ПАРСИНГ YAML КОНФИГУРАЦИИ
# ============================================

parse_yaml_with_python() {
    local yaml_file=$1
    local section=$2
    local key=$3

    python3 << EOF
import yaml
import sys
import json

try:
    with open('$yaml_file', 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)

    if '$section' and '$key':
        result = data.get('$section', {}).get('$key', [])
    elif '$section':
        result = data.get('$section', {})
    else:
        result = data

    if isinstance(result, list):
        for item in result:
            print(item)
    elif isinstance(result, dict):
        print(json.dumps(result))
    else:
        print(result)

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    sys.exit(1)
EOF
}

get_config_value() {
    local section=$1
    local key=$2

    if command -v yq &> /dev/null; then
        yq eval ".${section}.${key}[]" "$CONFIG_FILE" 2>/dev/null || echo ""
    else
        parse_yaml_with_python "$CONFIG_FILE" "$section" "$key"
    fi
}

# ============================================
# СКАЧИВАНИЕ GEOIP БАЗ
# ============================================

download_geoip_databases() {
    log_info "Скачивание GeoIP баз данных..."

    if [ -z "$MAXMIND_LICENSE_KEY" ]; then
        log_warning "MAXMIND_LICENSE_KEY не установлен. Пропуск скачивания GeoIP баз."
        return 0
    fi

    local databases=("GeoLite2-Country" "GeoLite2-City" "GeoLite2-ASN")

    for db in "${databases[@]}"; do
        local db_file="${CACHE_DIR}/${db}.mmdb"

        # Проверяем возраст файла (обновляем если старше 7 дней)
        if [ -f "$db_file" ]; then
            local file_age=$(($(date +%s) - $(stat -c %Y "$db_file" 2>/dev/null || stat -f %m "$db_file" 2>/dev/null)))
            if [ $file_age -lt 604800 ]; then
                log_info "База $db актуальна (возраст: $((file_age / 86400)) дней)"
                continue
            fi
        fi

        log_info "Скачивание ${db}..."
        local url="https://download.maxmind.com/app/geoip_download?edition_id=${db}&license_key=${MAXMIND_LICENSE_KEY}&suffix=tar.gz"

        if curl -sSL "$url" | tar -xzf - -C "$CACHE_DIR" --strip-components=1 "*.mmdb" 2>/dev/null; then
            log_success "✓ ${db} скачан"
        else
            log_warning "Не удалось скачать ${db}"
        fi
    done
}

# ============================================
# ПОЛУЧЕНИЕ IP ПО ASN
# ============================================

get_ips_from_asn() {
    local asn=$1
    local output_file=$2

    # Удаляем префикс AS если есть
    asn=${asn#AS}
    asn=${asn#as}

    log_info "Получение IP для ASN: AS${asn}..."

    # Пробуем несколько источников
    local sources=(
        "https://api.bgpview.io/asn/${asn}/prefixes"
        "https://stat.ripe.net/data/announced-prefixes/data.json?resource=AS${asn}"
    )

    local temp_file="${CACHE_DIR}/asn_${asn}_temp.json"

    for source in "${sources[@]}"; do
        log_info "Запрос к ${source}..."

        if curl -sSL -m 30 "$source" -o "$temp_file" 2>/dev/null; then
            # Парсим JSON и извлекаем IPv4 префиксы
            if grep -q "prefixes" "$temp_file" 2>/dev/null; then
                jq -r '.data.ipv4_prefixes[]?.prefix // empty' "$temp_file" 2>/dev/null >> "$output_file" && break
                jq -r '.data.prefixes[]?.prefix // empty' "$temp_file" 2>/dev/null | grep -E '^[0-9]+\.' >> "$output_file" && break
            fi
        fi
    done

    rm -f "$temp_file"

    local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
    log_success "✓ Получено $count IP префиксов для AS${asn}"
}

# ============================================
# ПОЛУЧЕНИЕ IP ПО СТРАНЕ
# ============================================

get_ips_from_country() {
    local country=$1
    local output_file=$2

    log_info "Получение IP для страны: ${country}..."

    # Используем несколько источников
    local sources=(
        "https://raw.githubusercontent.com/herrbischoff/country-ip-blocks/master/ipv4/${country,,}.cidr"
        "https://www.ipdeny.com/ipblocks/data/aggregated/${country,,}-aggregated.zone"
    )

    for source in "${sources[@]}"; do
        log_info "Запрос к ${source}..."

        if curl -sSL -m 30 "$source" >> "$output_file" 2>/dev/null; then
            local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
            if [ "$count" -gt 0 ]; then
                log_success "✓ Получено $count IP блоков для страны ${country}"
                return 0
            fi
        fi
    done

    log_warning "Не удалось получить IP для страны ${country}"
    return 1
}

# ============================================
# ПОЛУЧЕНИЕ IP ПО ГОРОДУ (требуется GeoLite2)
# ============================================

get_ips_from_city() {
    local city_spec=$1
    local output_file=$2

    log_info "Получение IP для города: ${city_spec}..."

    # Для городов нужна GeoLite2-City база
    local city_db="${CACHE_DIR}/GeoLite2-City.mmdb"

    if [ ! -f "$city_db" ]; then
        log_warning "GeoLite2-City.mmdb не найдена. Пропуск города ${city_spec}."
        return 1
    fi

    # Здесь нужен mmdblookup или аналогичный инструмент
    # Для простоты пропускаем (требует дополнительных зависимостей)
    log_warning "Поиск по городам требует дополнительных инструментов (mmdblookup/geoiplookup)"
    log_warning "Пропуск города: ${city_spec}"

    return 1
}

# ============================================
# ОПТИМИЗАЦИЯ И ДЕДУПЛИКАЦИЯ IP
# ============================================

optimize_ip_list() {
    local input_file=$1
    local output_file=$2

    log_info "Оптимизация и дедупликация IP адресов..."

    if [ ! -f "$input_file" ] || [ ! -s "$input_file" ]; then
        log_warning "Входной файл пустой или не существует: $input_file"
        touch "$output_file"
        return 0
    fi

    python3 << EOF
import ipaddress
import sys

def optimize_cidrs(cidrs):
    """Объединяет и оптимизирует CIDR блоки"""
    try:
        # Преобразуем в объекты ipaddress
        networks = []
        for cidr in cidrs:
            cidr = cidr.strip()
            if not cidr or cidr.startswith('#'):
                continue
            try:
                # Если это одиночный IP, добавляем /32
                if '/' not in cidr:
                    cidr = f"{cidr}/32"
                networks.append(ipaddress.ip_network(cidr, strict=False))
            except ValueError as e:
                print(f"Пропуск невалидного CIDR: {cidr}", file=sys.stderr)
                continue

        # Сортируем и объединяем
        if not networks:
            return []

        networks = sorted(set(networks))
        collapsed = list(ipaddress.collapse_addresses(networks))

        return [str(net) for net in collapsed]
    except Exception as e:
        print(f"Ошибка оптимизации: {e}", file=sys.stderr)
        return []

# Читаем входной файл
try:
    with open('$input_file', 'r') as f:
        cidrs = f.readlines()

    optimized = optimize_cidrs(cidrs)

    # Записываем результат
    with open('$output_file', 'w') as f:
        for cidr in optimized:
            f.write(f"{cidr}\n")

    print(f"Оптимизировано: {len(cidrs)} → {len(optimized)} CIDR блоков", file=sys.stderr)
except Exception as e:
    print(f"Ошибка: {e}", file=sys.stderr)
    sys.exit(1)
EOF

    local input_count=$(wc -l < "$input_file" 2>/dev/null || echo 0)
    local output_count=$(wc -l < "$output_file" 2>/dev/null || echo 0)

    log_success "✓ Оптимизировано: $input_count → $output_count IP блоков"
}

# ============================================
# ГЕНЕРАЦИЯ IP ДЛЯ ОДНОГО СПИСКА
# ============================================

generate_ip_list() {
    local list_name=$1
    local config_section=$2

    log_info "=========================================="
    log_info "Генерация списка: ${list_name}"
    log_info "=========================================="

    local temp_file="${OUTPUT_DIR}/${list_name}_temp.txt"
    local raw_file="${OUTPUT_DIR}/${list_name}_raw.txt"
    local final_file="${OUTPUT_DIR}/${list_name}.txt"

    > "$temp_file"
    > "$raw_file"

    # 1. Добавляем прямые IP адреса
    log_info "Обработка прямых IP адресов..."
    local direct_ips=$(get_config_value "$config_section" "direct_ips")
    if [ -n "$direct_ips" ]; then
        echo "$direct_ips" | while read -r ip; do
            [ -n "$ip" ] && echo "$ip" >> "$raw_file"
        done
        local count=$(echo "$direct_ips" | grep -c . || echo 0)
        log_success "✓ Добавлено $count прямых IP"
    fi

    # 2. Обработка ASN
    log_info "Обработка ASN..."
    local asns=$(get_config_value "$config_section" "asn")
    if [ -n "$asns" ]; then
        echo "$asns" | while read -r asn; do
            if [ -n "$asn" ]; then
                get_ips_from_asn "$asn" "$raw_file"
            fi
        done
    fi

    # 3. Обработка стран
    log_info "Обработка стран..."
    local countries=$(get_config_value "$config_section" "countries")
    if [ -n "$countries" ]; then
        echo "$countries" | while read -r country; do
            if [ -n "$country" ]; then
                get_ips_from_country "$country" "$raw_file"
            fi
        done
    fi

    # 4. Обработка городов
    log_info "Обработка городов..."
    local cities=$(get_config_value "$config_section" "cities")
    if [ -n "$cities" ]; then
        echo "$cities" | while read -r city; do
            if [ -n "$city" ]; then
                get_ips_from_city "$city" "$raw_file"
            fi
        done
    fi

    # 5. Оптимизация и дедупликация
    if [ -f "$raw_file" ] && [ -s "$raw_file" ]; then
        optimize_ip_list "$raw_file" "$final_file"
    else
        log_warning "Нет IP адресов для оптимизации"
        touch "$final_file"
    fi

    # Очистка временных файлов
    rm -f "$temp_file" "$raw_file"

    local final_count=$(wc -l < "$final_file" 2>/dev/null || echo 0)
    log_success "=========================================="
    log_success "Список ${list_name}: $final_count IP блоков"
    log_success "Сохранено в: $final_file"
    log_success "=========================================="
    echo ""
}

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================

main() {
    echo -e "${GREEN}=========================================="
    echo -e "  IP Generator v1.0"
    echo -e "==========================================${NC}"
    echo ""

    # Проверка зависимостей
    check_dependencies

    # Проверка конфигурационного файла
    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Конфигурационный файл не найден: $CONFIG_FILE"
        exit 1
    fi

    log_info "Используется конфигурация: $CONFIG_FILE"
    log_info "Выходная директория: $OUTPUT_DIR"
    log_info "Кеш директория: $CACHE_DIR"
    echo ""

    # Скачивание GeoIP баз
    download_geoip_databases
    echo ""

    # Генерация списков IP
    generate_ip_list "ssh_allowed_ips" "ssh_allowed_ips"
    generate_ip_list "docker_allowed_ips" "docker_allowed_ips"
    generate_ip_list "rustdesk_allowed_ips" "rustdesk_allowed_ips"

    # Итоговая статистика
    echo -e "${GREEN}=========================================="
    echo -e "  ГЕНЕРАЦИЯ ЗАВЕРШЕНА"
    echo -e "==========================================${NC}"
    echo ""

    log_info "Сгенерированные файлы:"
    for list in ssh_allowed_ips docker_allowed_ips rustdesk_allowed_ips; do
        local file="${OUTPUT_DIR}/${list}.txt"
        if [ -f "$file" ]; then
            local count=$(wc -l < "$file")
            log_success "✓ ${list}.txt: $count IP блоков"
        fi
    done

    echo ""
    log_success "Все списки IP сгенерированы успешно!"
    log_info "Используйте update-ufw-script.sh для обновления основного скрипта"
}

# ============================================
# ЗАПУСК
# ============================================

main "$@"
