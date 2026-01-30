#!/bin/bash
# ============================================
# UFW Script Updater v1.0
# ============================================
# Обновляет ufw-docker-rules-v4.sh с IP адресами из generated-ips/
# ============================================

set -e

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Глобальные переменные
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UFW_SCRIPT="${UFW_SCRIPT:-${SCRIPT_DIR}/ufw-docker-rules-v4.sh}"
IP_DIR="${IP_DIR:-${SCRIPT_DIR}/generated-ips}"
BACKUP_DIR="${BACKUP_DIR:-${SCRIPT_DIR}/backups}"

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
# СОЗДАНИЕ РЕЗЕРВНОЙ КОПИИ
# ============================================

create_backup() {
    local file=$1

    if [ ! -f "$file" ]; then
        log_error "Файл не найден: $file"
        return 1
    fi

    mkdir -p "$BACKUP_DIR"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="${BACKUP_DIR}/$(basename "$file").${timestamp}.backup"

    cp "$file" "$backup_file"
    log_success "Создана резервная копия: $backup_file"

    # Сохраняем только последние 10 бэкапов
    local backup_count=$(ls -1 "${BACKUP_DIR}/"*.backup 2>/dev/null | wc -l)
    if [ "$backup_count" -gt 10 ]; then
        ls -t "${BACKUP_DIR}/"*.backup | tail -n +11 | xargs rm -f
        log_info "Удалены старые резервные копии (оставлено 10)"
    fi
}

# ============================================
# ЧТЕНИЕ IP ИЗ ФАЙЛА
# ============================================

read_ips_from_file() {
    local file=$1

    if [ ! -f "$file" ]; then
        log_warning "Файл не найден: $file"
        return 1
    fi

    # Читаем файл, пропускаем пустые строки и комментарии
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$' || true
}

# ============================================
# ФОРМАТИРОВАНИЕ IP ДЛЯ BASH МАССИВА
# ============================================

format_ips_for_bash() {
    local ips=("$@")
    local indent="    "
    local output=""

    for ip in "${ips[@]}"; do
        if [ -n "$ip" ]; then
            output="${output}${indent}\"${ip}\"\n"
        fi
    done

    echo -e "$output"
}

# ============================================
# ОБНОВЛЕНИЕ СЕКЦИИ В СКРИПТЕ
# ============================================

update_section() {
    local script_file=$1
    local section_name=$2
    local ip_file=$3

    log_info "Обновление секции: $section_name"

    if [ ! -f "$ip_file" ]; then
        log_warning "Файл IP не найден: $ip_file. Пропуск."
        return 0
    fi

    # Читаем IP адреса
    local ips=()
    while IFS= read -r line; do
        [ -n "$line" ] && ips+=("$line")
    done < <(read_ips_from_file "$ip_file")

    local ip_count=${#ips[@]}
    log_info "Найдено IP адресов: $ip_count"

    # Создаем временный файл
    local temp_file=$(mktemp)

    # Используем awk для замены секции
    awk -v section="$section_name" -v ip_file="$ip_file" -v ip_count="$ip_count" '
    BEGIN {
        in_section = 0
        section_found = 0
        new_content_added = 0
    }

    # Начало секции
    /^[[:space:]]*'"$section_name"'[[:space:]]*=\(/ {
        in_section = 1
        section_found = 1
        print $0
        next
    }

    # Внутри секции - пропускаем старые IP
    in_section == 1 {
        # Конец секции (закрывающая скобка)
        if (/^[[:space:]]*\)/) {
            # Вставляем новые IP перед закрывающей скобкой
            if (new_content_added == 0) {
                if (ip_count > 0) {
                    # Если есть IP адреса - вставляем их
                    system("cat \"" ip_file "\" | grep -v \"^#\" | grep -v \"^[[:space:]]*$\" | awk '\''{print \"    \\\"\" $0 \"\\\"\"}'\''")
                }
                # Если IP адресов нет - просто оставляем пустой массив
                new_content_added = 1
            }
            print $0
            in_section = 0
            next
        }
        # Пропускаем старые IP (строки с кавычками)
        if (/^[[:space:]]*\".*\"/) {
            next
        }
        # Оставляем комментарии
        print $0
        next
    }

    # Все остальное копируем как есть
    {
        print $0
    }
    ' "$script_file" > "$temp_file"

    # Проверяем что замена прошла успешно
    if ! grep -q "${section_name}=(" "$temp_file"; then
        log_error "Не удалось найти секцию $section_name в скрипте"
        rm -f "$temp_file"
        return 1
    fi

    # Заменяем оригинальный файл
    mv "$temp_file" "$script_file"

    if [ "$ip_count" -eq 0 ]; then
        log_success "✓ Секция $section_name очищена (0 IP)"
    else
        log_success "✓ Секция $section_name обновлена ($ip_count IP)"
    fi
}

# ============================================
# ПРОВЕРКА СИНТАКСИСА BASH
# ============================================

check_bash_syntax() {
    local file=$1

    log_info "Проверка синтаксиса bash..."

    if bash -n "$file" 2>/dev/null; then
        log_success "✓ Синтаксис корректен"
        return 0
    else
        log_error "✗ Ошибка синтаксиса в $file"
        bash -n "$file"
        return 1
    fi
}

# ============================================
# ОТОБРАЖЕНИЕ СТАТИСТИКИ
# ============================================

show_statistics() {
    local script_file=$1

    log_info "=========================================="
    log_info "СТАТИСТИКА IP АДРЕСОВ В СКРИПТЕ"
    log_info "=========================================="

    # Подсчет IP в каждой секции
    for section in SSH_ALLOWED_IPS DOCKER_ALLOWED_IPS RUSTDESK_ALLOWED_IPS; do
        local count=$(grep -A 1000 "^${section}=(" "$script_file" | \
                     grep -B 1000 "^)" | \
                     grep '^\s*"' | \
                     wc -l)
        log_success "✓ $section: $count IP адресов"
    done

    log_info "=========================================="
}

# ============================================
# ГЛАВНАЯ ФУНКЦИЯ
# ============================================

main() {
    echo -e "${GREEN}=========================================="
    echo -e "  UFW Script Updater v1.0"
    echo -e "==========================================${NC}"
    echo ""

    # Проверка существования UFW скрипта
    if [ ! -f "$UFW_SCRIPT" ]; then
        log_error "UFW скрипт не найден: $UFW_SCRIPT"
        exit 1
    fi

    # Проверка директории с IP
    if [ ! -d "$IP_DIR" ]; then
        log_error "Директория с IP не найдена: $IP_DIR"
        log_info "Запустите сначала generate-ips.sh"
        exit 1
    fi

    log_info "UFW скрипт: $UFW_SCRIPT"
    log_info "Директория IP: $IP_DIR"
    log_info "Директория бэкапов: $BACKUP_DIR"
    echo ""

    # Создаем резервную копию
    create_backup "$UFW_SCRIPT"
    echo ""

    # Обновляем каждую секцию
    update_section "$UFW_SCRIPT" "SSH_ALLOWED_IPS" "${IP_DIR}/ssh_allowed_ips.txt"
    update_section "$UFW_SCRIPT" "DOCKER_ALLOWED_IPS" "${IP_DIR}/docker_allowed_ips.txt"
    update_section "$UFW_SCRIPT" "RUSTDESK_ALLOWED_IPS" "${IP_DIR}/rustdesk_allowed_ips.txt"
    echo ""

    # Проверка синтаксиса
    if ! check_bash_syntax "$UFW_SCRIPT"; then
        log_error "Обнаружена ошибка синтаксиса!"
        log_info "Восстановление из резервной копии..."

        local latest_backup=$(ls -t "${BACKUP_DIR}/"*.backup 2>/dev/null | head -1)
        if [ -n "$latest_backup" ]; then
            cp "$latest_backup" "$UFW_SCRIPT"
            log_success "Восстановлено из: $latest_backup"
        fi
        exit 1
    fi
    echo ""

    # Отображение статистики
    show_statistics "$UFW_SCRIPT"
    echo ""

    echo -e "${GREEN}=========================================="
    echo -e "  ОБНОВЛЕНИЕ ЗАВЕРШЕНО УСПЕШНО"
    echo -e "==========================================${NC}"
    echo ""

    log_success "Скрипт $UFW_SCRIPT обновлен!"
    log_info "Резервная копия сохранена в $BACKUP_DIR"
    log_info "Теперь вы можете запустить обновленный скрипт"
    echo ""
}

# ============================================
# ЗАПУСК
# ============================================

main "$@"
