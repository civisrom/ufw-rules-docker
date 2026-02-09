#!/bin/bash
# ============================================
# IP Generator Script v2.0 (MaxMind Primary)
# ============================================
# Генерирует списки IP адресов из MaxMind GeoLite2 баз данных:
# - ASN (Autonomous System Numbers) - из GeoLite2-ASN
# - Страны (Countries) - из GeoLite2-Country
# - Города (Cities) - из GeoLite2-City
# - Прямые IP/CIDR
#
# MaxMind используется как основной источник данных
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
CACHE_DIR="${CACHE_DIR:-${SCRIPT_DIR}/maxmind-data}"
MAXMIND_LICENSE_KEY="${MAXMIND_LICENSE_KEY:-}"

# Создаем директории
mkdir -p "$OUTPUT_DIR"
mkdir -p "$CACHE_DIR"
mkdir -p "$CACHE_DIR/.metadata"

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

get_config_scalar() {
    local path=$1

    if command -v yq &> /dev/null; then
        yq eval ".${path}" "$CONFIG_FILE" 2>/dev/null || echo ""
    else
        python3 << EOF
import yaml
try:
    with open('$CONFIG_FILE', 'r', encoding='utf-8') as f:
        data = yaml.safe_load(f)

    # Разбираем путь (например, "generation.mode")
    keys = '$path'.split('.')
    result = data
    for key in keys:
        result = result.get(key, '')

    print(result)
except Exception:
    print('')
EOF
    fi
}

# ============================================
# ВАЛИДАЦИЯ КОНФИГУРАЦИИ
# ============================================

validate_config() {
    log_info "Валидация ip-config.yml..."

    if [ ! -f "$CONFIG_FILE" ]; then
        log_error "Конфигурационный файл не найден: $CONFIG_FILE"
        return 1
    fi

    # Проверка YAML синтаксиса
    if ! python3 << EOF
import yaml
import sys

try:
    with open('$CONFIG_FILE', 'r', encoding='utf-8') as f:
        config = yaml.safe_load(f)

    # Проверяем базовую структуру
    if not isinstance(config, dict):
        print("ERROR: Конфигурация должна быть словарем")
        sys.exit(1)

    # Проверяем наличие секции generation
    if 'generation' not in config:
        print("ERROR: Отсутствует секция 'generation'")
        sys.exit(1)

    # Проверяем наличие хотя бы одного скрипта (ufw_v4_script или ufw_v6_script)
    if 'ufw_v4_script' not in config and 'ufw_v6_script' not in config:
        print("ERROR: Нет ни одной секции скрипта (ufw_v4_script или ufw_v6_script)")
        sys.exit(1)

    # Проверяем структуру секций скриптов
    for script_section in ['ufw_v4_script', 'ufw_v6_script']:
        if script_section in config:
            script_config = config[script_section]
            if not isinstance(script_config, dict):
                print(f"ERROR: Секция '{script_section}' должна быть словарем")
                sys.exit(1)

    print("OK")
    sys.exit(0)

except yaml.YAMLError as e:
    print(f"ERROR: Некорректный YAML: {e}")
    sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}")
    sys.exit(1)
EOF
    then
        log_error "Некорректный YAML в $CONFIG_FILE"
        return 1
    fi

    log_success "✓ Конфигурация валидна"
    return 0
}

# ============================================
# ПОЛУЧЕНИЕ IP ПО ASN (из MaxMind GeoLite2-ASN)
# ============================================

get_ips_from_asn() {
    local asn=$1
    local output_file=$2
    local ipv6=${3:-false}  # Третий параметр: IPv6 режим (по умолчанию false)

    local ip_ver="IPv4"
    local ipv6_flag=""
    if [ "$ipv6" = true ]; then
        ip_ver="IPv6"
        ipv6_flag="--ipv6"
    fi

    log_info "Получение $ip_ver для ASN: ${asn} из MaxMind GeoLite2-ASN..."

    if [ -z "$MAXMIND_LICENSE_KEY" ]; then
        log_error "MAXMIND_LICENSE_KEY не установлен. Невозможно получить IP для ASN."
        return 1
    fi

    # Используем Python скрипт для извлечения из MaxMind базы
    if python3 "${SCRIPT_DIR}/extract-ips-from-maxmind.py" \
        --cache-dir "$CACHE_DIR" \
        --license-key "$MAXMIND_LICENSE_KEY" \
        --asn "$asn" \
        --output "$output_file" \
        --optimize \
        $ipv6_flag 2>&1 | grep -v "^\["; then

        local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
        log_success "✓ Получено $count $ip_ver блоков для ${asn} из MaxMind"
    else
        log_error "Не удалось получить IP для ${asn}"
        return 1
    fi
}

# ============================================
# ПОЛУЧЕНИЕ IP ПО СТРАНЕ (из MaxMind GeoLite2-Country)
# ============================================

get_ips_from_country() {
    local country=$1
    local output_file=$2
    local ipv6=${3:-false}  # Третий параметр: IPv6 режим (по умолчанию false)

    local ip_ver="IPv4"
    local ipv6_flag=""
    if [ "$ipv6" = true ]; then
        ip_ver="IPv6"
        ipv6_flag="--ipv6"
    fi

    log_info "Получение $ip_ver для страны: ${country} из MaxMind GeoLite2-Country..."

    if [ -z "$MAXMIND_LICENSE_KEY" ]; then
        log_error "MAXMIND_LICENSE_KEY не установлен. Невозможно получить IP для страны."
        return 1
    fi

    # Используем Python скрипт для извлечения из MaxMind базы
    if python3 "${SCRIPT_DIR}/extract-ips-from-maxmind.py" \
        --cache-dir "$CACHE_DIR" \
        --license-key "$MAXMIND_LICENSE_KEY" \
        --country "$country" \
        --output "$output_file" \
        --optimize \
        $ipv6_flag 2>&1 | grep -v "^\["; then

        local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
        log_success "✓ Получено $count $ip_ver блоков для страны ${country} из MaxMind"
    else
        log_error "Не удалось получить IP для страны ${country}"
        return 1
    fi
}

# ============================================
# ПОЛУЧЕНИЕ IP ПО ГОРОДУ (из MaxMind GeoLite2-City)
# ============================================

get_ips_from_city() {
    local city_spec=$1
    local output_file=$2
    local ipv6=${3:-false}  # Третий параметр: IPv6 режим (по умолчанию false)

    local ip_ver="IPv4"
    local ipv6_flag=""
    if [ "$ipv6" = true ]; then
        ip_ver="IPv6"
        ipv6_flag="--ipv6"
    fi

    log_info "Получение $ip_ver для города: ${city_spec} из MaxMind GeoLite2-City..."

    if [ -z "$MAXMIND_LICENSE_KEY" ]; then
        log_error "MAXMIND_LICENSE_KEY не установлен. Невозможно получить IP для города."
        return 1
    fi

    # Используем Python скрипт для извлечения из MaxMind базы
    if python3 "${SCRIPT_DIR}/extract-ips-from-maxmind.py" \
        --cache-dir "$CACHE_DIR" \
        --license-key "$MAXMIND_LICENSE_KEY" \
        --city "$city_spec" \
        --output "$output_file" \
        --optimize \
        $ipv6_flag 2>&1 | grep -v "^\["; then

        local count=$(wc -l < "$output_file" 2>/dev/null || echo 0)
        if [ "$count" -gt 0 ]; then
            log_success "✓ Получено $count $ip_ver блоков для города ${city_spec} из MaxMind"
        else
            log_warning "Не найдено $ip_ver блоков для города ${city_spec}"
        fi
    else
        log_error "Не удалось получить IP для города ${city_spec}"
        return 1
    fi
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
# ГЕНЕРАЦИЯ IP ДЛЯ ОДНОГО СПИСКА (IPv4 или IPv6)
# ============================================

generate_ip_list_version() {
    local list_name=$1
    local config_section=$2
    local ipv6=${3:-false}  # Третий параметр: генерировать IPv6 (по умолчанию false)

    local ip_ver="IPv4"
    local subsection="ipv4"
    if [ "$ipv6" = true ]; then
        ip_ver="IPv6"
        subsection="ipv6"

        # Проверяем, включен ли IPv6 для этого списка
        local ipv6_enabled=$(get_config_scalar "${config_section}.ipv6.enabled")
        if [ "$ipv6_enabled" = "false" ]; then
            log_warning "IPv6 отключен для ${config_section}, пропускаем генерацию"
            # Создаем пустой файл
            touch "${OUTPUT_DIR}/${list_name}.txt"
            return 0
        fi
    fi

    log_info "=========================================="
    log_info "Генерация списка: ${list_name} ($ip_ver)"
    log_info "Секция: ${config_section}.${subsection}"
    log_info "=========================================="

    local temp_file="${OUTPUT_DIR}/${list_name}_temp.txt"
    local raw_file="${OUTPUT_DIR}/${list_name}_raw.txt"
    local final_file="${OUTPUT_DIR}/${list_name}.txt"

    > "$temp_file"
    > "$raw_file"

    # 1. Добавляем прямые IP адреса
    log_info "Обработка прямых IP адресов..."
    local direct_ips=$(get_config_value "${config_section}.${subsection}" "direct_ips")
    if [ -n "$direct_ips" ]; then
        echo "$direct_ips" | while read -r ip; do
            [ -n "$ip" ] && echo "$ip" >> "$raw_file"
        done
        local count=$(echo "$direct_ips" | grep -c . || echo 0)
        log_success "✓ Добавлено $count прямых IP"
    fi

    # 2. Обработка ASN
    log_info "Обработка ASN..."
    local asns=$(get_config_value "${config_section}.${subsection}" "asn")
    if [ -n "$asns" ]; then
        echo "$asns" | while read -r asn; do
            if [ -n "$asn" ]; then
                # Используем временный файл для каждого ASN, затем добавляем в raw_file
                local asn_temp="${OUTPUT_DIR}/${list_name}_asn_${asn}_temp.txt"
                if get_ips_from_asn "$asn" "$asn_temp" "$ipv6"; then
                    # Проверяем что файл существует перед добавлением
                    if [ -f "$asn_temp" ]; then
                        cat "$asn_temp" >> "$raw_file"
                        rm -f "$asn_temp"
                    fi
                fi
            fi
        done
    fi

    # 3. Обработка стран
    log_info "Обработка стран..."
    local countries=$(get_config_value "${config_section}.${subsection}" "countries")
    if [ -n "$countries" ]; then
        echo "$countries" | while read -r country; do
            if [ -n "$country" ]; then
                # Используем временный файл для каждой страны, затем добавляем в raw_file
                local country_temp="${OUTPUT_DIR}/${list_name}_country_${country}_temp.txt"
                if get_ips_from_country "$country" "$country_temp" "$ipv6"; then
                    # Проверяем что файл существует перед добавлением
                    if [ -f "$country_temp" ]; then
                        cat "$country_temp" >> "$raw_file"
                        rm -f "$country_temp"
                    fi
                fi
            fi
        done
    fi

    # 4. Обработка городов
    log_info "Обработка городов..."
    local cities=$(get_config_value "${config_section}.${subsection}" "cities")
    if [ -n "$cities" ]; then
        echo "$cities" | while read -r city; do
            if [ -n "$city" ]; then
                # Используем временный файл для каждого города, затем добавляем в raw_file
                local city_safe=$(echo "$city" | tr '/' '_')
                local city_temp="${OUTPUT_DIR}/${list_name}_city_${city_safe}_temp.txt"
                if get_ips_from_city "$city" "$city_temp" "$ipv6"; then
                    # Проверяем что файл существует перед добавлением
                    if [ -f "$city_temp" ]; then
                        cat "$city_temp" >> "$raw_file"
                        rm -f "$city_temp"
                    fi
                fi
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
    log_success "Список ${list_name}: $final_count IP блоков ($ip_ver)"
    log_success "Сохранено в: $final_file"
    log_success "=========================================="
    echo ""
}

# ============================================
# ГЕНЕРАЦИЯ ОБОИХ ВЕРСИЙ (IPv4 + IPv6)
# ============================================

generate_ip_list_for_script() {
    local script_prefix=$1  # v4 или v6
    local list_name=$2      # ssh_allowed_ips, docker_allowed_ips, rustdesk_allowed_ips
    local config_section=$3 # ufw_v4_script.ssh_allowed_ips или ufw_v6_script.ssh_allowed_ips
    local ipv6_globally_enabled=$4

    # Генерируем IPv4 версию (всегда)
    local ipv4_filename="${script_prefix}_${list_name}"
    generate_ip_list_version "$ipv4_filename" "$config_section" false

    # Генерируем IPv6 версию (если IPv6 включен глобально)
    if [ "$ipv6_globally_enabled" = "true" ]; then
        local ipv6_filename="${script_prefix}_${list_name}_ipv6"
        generate_ip_list_version "$ipv6_filename" "$config_section" true
    else
        log_warning "IPv6 глобально отключен, пропускаем IPv6 генерацию для ${script_prefix}_${list_name}"
    fi
}

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================

main() {
    echo -e "${GREEN}=========================================="
    echo -e "  IP Generator v2.0 (MaxMind)"
    echo -e "==========================================${NC}"
    echo ""

    # Проверка зависимостей
    check_dependencies
    echo ""

    # Валидация конфигурации
    if ! validate_config; then
        exit 1
    fi

    log_info "Используется конфигурация: $CONFIG_FILE"
    log_info "Выходная директория: $OUTPUT_DIR"
    log_info "Директория MaxMind данных: $CACHE_DIR"

    # Проверка MaxMind License Key
    if [ -z "$MAXMIND_LICENSE_KEY" ]; then
        log_error "MAXMIND_LICENSE_KEY не установлен!"
        log_error "Получите бесплатный ключ: https://www.maxmind.com/en/geolite2/signup"
        log_error "Установите: export MAXMIND_LICENSE_KEY=\"ваш_ключ\""
        exit 1
    fi
    log_success "✓ MAXMIND_LICENSE_KEY установлен"
    echo ""

    # Чтение настроек генерации из конфигурации
    local update_scripts=$(get_config_scalar "generation.update_scripts")
    local ipv6_enabled=$(get_config_scalar "generation.ipv6_enabled")

    # Значения по умолчанию
    update_scripts="${update_scripts:-both}"
    ipv6_enabled="${ipv6_enabled:-true}"

    log_info "=========================================="
    log_info "НАСТРОЙКИ ГЕНЕРАЦИИ"
    log_info "=========================================="
    log_info "Обновление скриптов: $update_scripts"
    log_info "IPv6 глобально: $ipv6_enabled"
    log_info "=========================================="
    echo ""

    # Валидация режима
    if [ "$update_scripts" != "v4" ] && [ "$update_scripts" != "v6" ] && [ "$update_scripts" != "both" ]; then
        log_error "Неверный generation.update_scripts: $update_scripts"
        log_error "Допустимые значения: v4, v6, both"
        exit 1
    fi

    # Генерация списков IP для ufw-docker-rules-v4.sh
    if [ "$update_scripts" = "v4" ] || [ "$update_scripts" = "both" ]; then
        log_info "=========================================="
        log_info "ГЕНЕРАЦИЯ ДЛЯ UFW-DOCKER-RULES-V4.SH"
        log_info "=========================================="
        echo ""

        generate_ip_list_for_script "v4" "ssh_allowed_ips" "ufw_v4_script.ssh_allowed_ips" "$ipv6_enabled"
        generate_ip_list_for_script "v4" "docker_allowed_ips" "ufw_v4_script.docker_allowed_ips" "$ipv6_enabled"
        generate_ip_list_for_script "v4" "rustdesk_allowed_ips" "ufw_v4_script.rustdesk_allowed_ips" "$ipv6_enabled"
    fi

    # Генерация списков IP для ufw-docker-rules-v6.sh
    if [ "$update_scripts" = "v6" ] || [ "$update_scripts" = "both" ]; then
        log_info "=========================================="
        log_info "ГЕНЕРАЦИЯ ДЛЯ UFW-DOCKER-RULES-V6.SH"
        log_info "=========================================="
        echo ""

        generate_ip_list_for_script "v6" "ssh_allowed_ips" "ufw_v6_script.ssh_allowed_ips" "$ipv6_enabled"
        generate_ip_list_for_script "v6" "docker_allowed_ips" "ufw_v6_script.docker_allowed_ips" "$ipv6_enabled"
        generate_ip_list_for_script "v6" "rustdesk_allowed_ips" "ufw_v6_script.rustdesk_allowed_ips" "$ipv6_enabled"
    fi

    # Итоговая статистика
    echo -e "${GREEN}=========================================="
    echo -e "  ГЕНЕРАЦИЯ ЗАВЕРШЕНА"
    echo -e "==========================================${NC}"
    echo ""

    log_info "Сгенерированные файлы:"

    # Файлы для ufw-docker-rules-v4.sh
    if [ "$update_scripts" = "v4" ] || [ "$update_scripts" = "both" ]; then
        log_info "Для ufw-docker-rules-v4.sh:"
        for list in ssh_allowed_ips docker_allowed_ips rustdesk_allowed_ips; do
            # IPv4 файл
            local file_v4="${OUTPUT_DIR}/v4_${list}.txt"
            if [ -f "$file_v4" ]; then
                local count_v4=$(wc -l < "$file_v4")
                log_success "  ✓ v4_${list}.txt: $count_v4 IPv4 блоков"
            fi

            # IPv6 файл
            local file_v6="${OUTPUT_DIR}/v4_${list}_ipv6.txt"
            if [ -f "$file_v6" ]; then
                local count_v6=$(wc -l < "$file_v6")
                log_success "  ✓ v4_${list}_ipv6.txt: $count_v6 IPv6 блоков"
            fi
        done
        echo ""
    fi

    # Файлы для ufw-docker-rules-v6.sh
    if [ "$update_scripts" = "v6" ] || [ "$update_scripts" = "both" ]; then
        log_info "Для ufw-docker-rules-v6.sh:"
        for list in ssh_allowed_ips docker_allowed_ips rustdesk_allowed_ips; do
            # IPv4 файл
            local file_v4="${OUTPUT_DIR}/v6_${list}.txt"
            if [ -f "$file_v4" ]; then
                local count_v4=$(wc -l < "$file_v4")
                log_success "  ✓ v6_${list}.txt: $count_v4 IPv4 блоков"
            fi

            # IPv6 файл
            local file_v6="${OUTPUT_DIR}/v6_${list}_ipv6.txt"
            if [ -f "$file_v6" ]; then
                local count_v6=$(wc -l < "$file_v6")
                log_success "  ✓ v6_${list}_ipv6.txt: $count_v6 IPv6 блоков"
            fi
        done
        echo ""
    fi

    log_success "Все списки IP сгенерированы успешно!"
    log_info "Используйте update-ufw-script.sh для обновления скриптов"
}

# ============================================
# ЗАПУСК
# ============================================

main "$@"
