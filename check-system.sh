#!/bin/bash
# Скрипт для проверки всех компонентов системы
# Проверяет синтаксис, зависимости и интеграцию

set -e

# Цвета
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=========================================="
echo -e "  Проверка системы UFW IP Management"
echo -e "==========================================${NC}\n"

ERRORS=0
WARNINGS=0

# Проверка синтаксиса Python скрипта
echo -e "${BLUE}[1/6]${NC} Проверка extract-ips-from-maxmind.py..."
if python3 -m py_compile extract-ips-from-maxmind.py 2>&1; then
    echo -e "  ${GREEN}✓${NC} Синтаксис корректен"
else
    echo -e "  ${RED}✗${NC} Ошибка синтаксиса"
    ERRORS=$((ERRORS + 1))
fi

# Проверка синтаксиса bash скриптов
echo -e "\n${BLUE}[2/6]${NC} Проверка generate-ips.sh..."
if bash -n generate-ips.sh 2>&1; then
    echo -e "  ${GREEN}✓${NC} Синтаксис корректен"
else
    echo -e "  ${RED}✗${NC} Ошибка синтаксиса"
    ERRORS=$((ERRORS + 1))
fi

echo -e "\n${BLUE}[3/6]${NC} Проверка update-ufw-script.sh..."
if bash -n update-ufw-script.sh 2>&1; then
    echo -e "  ${GREEN}✓${NC} Синтаксис корректен"
else
    echo -e "  ${RED}✗${NC} Ошибка синтаксиса"
    ERRORS=$((ERRORS + 1))
fi

echo -e "\n${BLUE}[4/6]${NC} Проверка ufw-docker-rules-v4.sh..."
if bash -n ufw-docker-rules-v4.sh 2>&1; then
    echo -e "  ${GREEN}✓${NC} Синтаксис корректен"
else
    echo -e "  ${RED}✗${NC} Ошибка синтаксиса"
    ERRORS=$((ERRORS + 1))
fi

# Проверка зависимостей
echo -e "\n${BLUE}[5/6]${NC} Проверка зависимостей..."

deps=(curl jq python3)
for cmd in "${deps[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} $cmd"
    else
        echo -e "  ${RED}✗${NC} $cmd не найден"
        ERRORS=$((ERRORS + 1))
    fi
done

# Проверка Python модулей
echo -e "\n${BLUE}[6/6]${NC} Проверка Python модулей..."

python3 << 'EOF'
import sys
modules = {
    'yaml': 'PyYAML',
    'ipaddress': 'ipaddress'
}

all_ok = True
for module, package in modules.items():
    try:
        __import__(module)
        print(f"  \033[0;32m✓\033[0m {package}")
    except ImportError:
        print(f"  \033[0;31m✗\033[0m {package} не установлен")
        all_ok = False

sys.exit(0 if all_ok else 1)
EOF

if [ $? -ne 0 ]; then
    ERRORS=$((ERRORS + 1))
fi

# Итоги
echo -e "\n${BLUE}=========================================="
echo -e "  Результаты проверки"
echo -e "==========================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✓ Все проверки пройдены успешно!${NC}"
    exit 0
else
    echo -e "${RED}✗ Найдено ошибок: $ERRORS${NC}"
    exit 1
fi
