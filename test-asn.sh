#!/bin/bash
# Быстрый тест добавления ASN и обновления

echo "🔄 Тест системы обновления IP адресов"
echo "======================================"
echo ""

# Проверка MAXMIND_LICENSE_KEY
if [ -z "$MAXMIND_LICENSE_KEY" ]; then
    echo "❌ MAXMIND_LICENSE_KEY не установлен!"
    echo ""
    echo "Установите ключ:"
    echo "  export MAXMIND_LICENSE_KEY='ваш_ключ'"
    echo ""
    echo "Получить ключ: https://www.maxmind.com/en/geolite2/signup"
    exit 1
fi

echo "✅ MAXMIND_LICENSE_KEY установлен"
echo ""

# Создаем тестовую конфигурацию с ASN
echo "📝 Создание тестовой конфигурации с ASN Cloudflare (AS13335)..."
cat > ip-config-test.yml << 'EOF'
version: "2.0"

ssh_allowed_ips:
  direct_ips:
    - "2.56.24.0/23"
  asn:
    - "AS13335"  # Cloudflare - для теста

docker_allowed_ips:
  direct_ips:
    - "185.125.188.0/22"

rustdesk_allowed_ips:
  direct_ips:
    - "185.125.188.0/22"

settings:
  maxmind_license_key: "${MAXMIND_LICENSE_KEY}"
  use_geoip_cache: true
  max_ips_per_list: 10000
  optimize_cidrs: true
  deduplicate: true
  maxmind_databases:
    country: "GeoLite2-Country-CSV"
    city: "GeoLite2-City-CSV"
    asn: "GeoLite2-ASN-CSV"
EOF

echo "✅ Тестовая конфигурация создана: ip-config-test.yml"
echo ""

# Генерируем IP для теста
echo "🔄 Генерация IP адресов (это может занять 1-2 минуты)..."
CONFIG_FILE=ip-config-test.yml OUTPUT_DIR=generated-ips-test ./generate-ips.sh

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Генерация завершена!"
    echo ""
    echo "📊 Результаты:"
    echo "---"

    if [ -f generated-ips-test/ssh_allowed_ips.txt ]; then
        count=$(wc -l < generated-ips-test/ssh_allowed_ips.txt)
        echo "SSH IPs: $count блоков"
        echo "Первые 5 IP из Cloudflare ASN:"
        head -5 generated-ips-test/ssh_allowed_ips.txt | sed 's/^/  /'
        if [ $count -gt 5 ]; then
            echo "  ... и еще $((count - 5)) блоков"
        fi
    fi

    echo ""
    echo "✅ ТЕСТ УСПЕШЕН!"
    echo ""
    echo "📋 Что делать дальше:"
    echo "1. Отредактируйте ip-config.yml - раскомментируйте нужные ASN"
    echo "2. Запустите: ./generate-ips.sh"
    echo "3. Запустите: ./update-ufw-script.sh"
    echo ""
    echo "Очистка тестовых файлов..."
    rm -rf generated-ips-test ip-config-test.yml
else
    echo ""
    echo "❌ Ошибка при генерации"
    exit 1
fi
