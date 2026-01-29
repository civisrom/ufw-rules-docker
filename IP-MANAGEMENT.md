# 🔐 Управление IP адресами для UFW Docker Rules

Этот документ описывает систему автоматического управления IP адресами для скрипта `ufw-docker-rules-v4.sh`.

## 📋 Оглавление

- [Обзор](#обзор)
- [Файлы системы](#файлы-системы)
- [Быстрый старт](#быстрый-старт)
- [Настройка ip-config.yml](#настройка-ip-configyml)
- [Источники IP адресов](#источники-ip-адресов)
- [Локальное использование](#локальное-использование)
- [GitHub Actions автоматизация](#github-actions-автоматизация)
- [Примеры конфигураций](#примеры-конфигураций)
- [Troubleshooting](#troubleshooting)

---

## 🎯 Обзор

Система позволяет автоматически генерировать списки IP адресов из различных источников:

- **ASN** (Autonomous System Numbers) - все IP блоки, принадлежащие провайдеру
- **Страны** - все IP адреса страны (по ISO коду)
- **Города** - IP адреса конкретного города
- **Прямые IP/CIDR** - ваши собственные IP адреса

Сгенерированные IP автоматически добавляются в три списка:
- `SSH_ALLOWED_IPS` - доступ к SSH
- `DOCKER_ALLOWED_IPS` - доступ к Docker контейнерам
- `RUSTDESK_ALLOWED_IPS` - доступ к RustDesk

---

## 📁 Файлы системы

```
├── ip-config.yml              # Конфигурация источников IP
├── generate-ips.sh            # Генерация IP списков
├── update-ufw-script.sh       # Обновление основного скрипта
├── ufw-docker-rules-v4.sh     # Основной UFW скрипт
├── .github/workflows/
│   └── update-ips.yml         # GitHub Actions workflow
├── generated-ips/             # Сгенерированные списки (создается автоматически)
│   ├── ssh_allowed_ips.txt
│   ├── docker_allowed_ips.txt
│   └── rustdesk_allowed_ips.txt
├── backups/                   # Резервные копии (создается автоматически)
└── .cache/                    # Кеш GeoIP баз (создается автоматически)
```

---

## 🚀 Быстрый старт

### 1. Настройте конфигурацию

Отредактируйте `ip-config.yml`:

```yaml
ssh_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Ваш офисный IP
  asn:
    - "AS13335"            # Cloudflare
```

### 2. Локальный запуск (опционально)

```bash
# Генерация IP списков
./generate-ips.sh

# Обновление UFW скрипта
./update-ufw-script.sh

# Проверка результата
cat generated-ips/ssh_allowed_ips.txt
```

### 3. GitHub Actions (автоматически)

1. Добавьте секрет `MAXMIND_LICENSE_KEY` в GitHub (если используете GeoIP)
2. Коммит изменений в `ip-config.yml`
3. Workflow автоматически обновит скрипт

---

## ⚙️ Настройка ip-config.yml

### Структура конфигурации

```yaml
# Список для SSH доступа
ssh_allowed_ips:
  direct_ips:          # Прямые IP адреса
    - "IP/CIDR"
  asn:                 # ASN номера
    - "AS####"
  countries:           # ISO коды стран
    - "XX"
  cities:              # Города
    - "Страна/Город"

# Список для Docker контейнеров
docker_allowed_ips:
  # ... аналогично

# Список для RustDesk
rustdesk_allowed_ips:
  # ... аналогично

# Настройки
settings:
  maxmind_license_key: "${MAXMIND_LICENSE_KEY}"
  max_ips_per_list: 10000
  optimize_cidrs: true
  deduplicate: true
```

### Параметры настроек

| Параметр | Описание | Значение по умолчанию |
|----------|----------|----------------------|
| `maxmind_license_key` | Лицензионный ключ MaxMind | (из переменной среды) |
| `use_geoip_cache` | Использовать кеш GeoIP баз | `true` |
| `max_ips_per_list` | Максимум IP в одном списке | `10000` |
| `output_format` | Формат вывода (`cidr` или `individual`) | `cidr` |
| `optimize_cidrs` | Объединять соседние CIDR блоки | `true` |
| `deduplicate` | Удалять дубликаты | `true` |

---

## 🌍 Источники IP адресов

### 1. Прямые IP адреса (direct_ips)

Самый простой способ - указать IP напрямую:

```yaml
ssh_allowed_ips:
  direct_ips:
    - "203.0.113.10/32"        # Одиночный IP
    - "198.51.100.0/24"        # Подсеть /24
    - "192.0.2.0/25"           # Подсеть /25
```

**Когда использовать:**
- У вас есть статический IP адрес
- Нужен доступ из конкретной подсети

### 2. ASN (Autonomous System Numbers)

Получить все IP блоки провайдера или компании:

```yaml
docker_allowed_ips:
  asn:
    - "AS13335"    # Cloudflare
    - "AS15169"    # Google
    - "AS16509"    # Amazon AWS
    - "AS32934"    # Facebook
```

**Когда использовать:**
- Нужен доступ от конкретного провайдера
- Доступ к облачной инфраструктуре (AWS, Google Cloud, Azure)
- Доступ к CDN (Cloudflare, Akamai)

**Как найти ASN:**
- Сайт: https://bgp.he.net/
- Команда: `whois -h whois.cymru.com " -v your-ip-address"`
- Поиск: Google "company name ASN"

### 3. Страны (countries)

Разрешить доступ из целой страны:

```yaml
rustdesk_allowed_ips:
  countries:
    - "RU"    # Россия
    - "US"    # США
    - "DE"    # Германия
    - "GB"    # Великобритания
```

**⚠️ ВНИМАНИЕ:** Может добавить **ТЫСЯЧИ** IP адресов!

**ISO коды стран:** https://en.wikipedia.org/wiki/ISO_3166-1_alpha-2

**Когда использовать:**
- Сервис доступен только для определенных стран
- Геоблокировка контента
- Compliance требования

### 4. Города (cities)

Доступ из конкретного города:

```yaml
ssh_allowed_ips:
  cities:
    - "RU/Moscow"
    - "US/California/San Francisco"
    - "GB/England/London"
```

**Требуется:**
- MaxMind GeoLite2-City база данных
- Дополнительные инструменты (`mmdblookup`)

**Формат:** `Страна/Регион/Город` или `Страна/Город`

---

## 💻 Локальное использование

### Установка зависимостей

**Ubuntu/Debian:**
```bash
sudo apt-get update
sudo apt-get install -y curl jq python3 python3-pip
pip3 install PyYAML
```

**CentOS/RHEL:**
```bash
sudo yum install -y curl jq python3 python3-pip
pip3 install PyYAML
```

### Генерация IP списков

```bash
# Базовая генерация
./generate-ips.sh

# С переменными среды
MAXMIND_LICENSE_KEY="your_key" ./generate-ips.sh

# Кастомные пути
CONFIG_FILE="./my-config.yml" \
OUTPUT_DIR="./my-ips" \
./generate-ips.sh
```

### Обновление UFW скрипта

```bash
# Базовое обновление
./update-ufw-script.sh

# Кастомные пути
UFW_SCRIPT="./custom-ufw.sh" \
IP_DIR="./my-ips" \
./update-ufw-script.sh
```

### Проверка результатов

```bash
# Просмотр сгенерированных IP
cat generated-ips/ssh_allowed_ips.txt

# Подсчет IP блоков
wc -l generated-ips/*.txt

# Проверка резервных копий
ls -lh backups/
```

---

## 🤖 GitHub Actions автоматизация

### Настройка GitHub Secrets

1. Получите MaxMind License Key:
   - Зарегистрируйтесь: https://www.maxmind.com/en/geolite2/signup
   - Создайте License Key
   - Скопируйте ключ

2. Добавьте секрет в GitHub:
   - Перейдите: Settings → Secrets and variables → Actions
   - Нажмите: "New repository secret"
   - Имя: `MAXMIND_LICENSE_KEY`
   - Значение: ваш ключ

### Триггеры workflow

Workflow запускается автоматически:

1. **По расписанию** - каждый день в 2:00 UTC
   ```yaml
   schedule:
     - cron: '0 2 * * *'
   ```

2. **При изменении конфигурации** - при коммите в:
   - `ip-config.yml`
   - `generate-ips.sh`
   - `update-ufw-script.sh`

3. **Вручную** - через GitHub UI:
   - Actions → Update UFW IP Lists → Run workflow

### Мониторинг workflow

1. **Просмотр логов:**
   - Actions → Update UFW IP Lists → последний run

2. **Просмотр статистики:**
   - Проверьте "Summary" в workflow run

3. **Скачать артефакты:**
   - В workflow run → Artifacts → ip-lists-XXXXX

### Автоматические коммиты

При изменениях workflow создает коммит:
```
chore: автоматическое обновление IP списков

Обновлены IP адреса из настроенных источников:
- ssh_allowed_ips: 150 IP блоков
- docker_allowed_ips: 500 IP блоков
- rustdesk_allowed_ips: 200 IP блоков

Дата: 2025-01-29 02:00:00 UTC
```

---

## 📝 Примеры конфигураций

### Пример 1: Простой офисный доступ

```yaml
ssh_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Офисная сеть

docker_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Та же офисная сеть

rustdesk_allowed_ips:
  direct_ips:
    - "203.0.113.50/32"   # Только админский ПК
```

### Пример 2: AWS инфраструктура

```yaml
ssh_allowed_ips:
  asn:
    - "AS16509"           # Amazon AWS
  direct_ips:
    - "203.0.113.0/24"    # Офис как резерв

docker_allowed_ips:
  asn:
    - "AS16509"           # Amazon AWS
    - "AS15169"           # Google Cloud (для CI/CD)

rustdesk_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Только из офиса
```

### Пример 3: Международный доступ

```yaml
ssh_allowed_ips:
  countries:
    - "US"                # США
    - "GB"                # Великобритания
    - "DE"                # Германия
  direct_ips:
    - "10.0.0.0/8"        # Внутренняя сеть

docker_allowed_ips:
  asn:
    - "AS13335"           # Cloudflare CDN
  countries:
    - "US"

rustdesk_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Только админы
```

### Пример 4: Комбинированная конфигурация

```yaml
ssh_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Главный офис
    - "198.51.100.0/24"   # Филиал
  asn:
    - "AS13335"           # Cloudflare (для VPN)
  cities:
    - "RU/Moscow"         # Московский офис

docker_allowed_ips:
  asn:
    - "AS16509"           # AWS
    - "AS15169"           # Google Cloud
    - "AS13335"           # Cloudflare
  direct_ips:
    - "192.0.2.0/24"      # Партнеры

rustdesk_allowed_ips:
  direct_ips:
    - "203.0.113.100/32"  # Админ 1
    - "203.0.113.101/32"  # Админ 2
```

---

## 🔧 Troubleshooting

### Проблема: "MAXMIND_LICENSE_KEY not set"

**Решение:**
```bash
# Локально
export MAXMIND_LICENSE_KEY="your_key_here"
./generate-ips.sh

# В GitHub Actions
# Добавьте секрет MAXMIND_LICENSE_KEY в репозиторий
```

### Проблема: "No IP addresses generated"

**Причины:**
1. Неправильный формат ASN (должен быть `AS12345`)
2. Неправильный ISO код страны (должен быть 2 буквы)
3. Сетевые проблемы при запросах к API

**Решение:**
```bash
# Проверка логов
./generate-ips.sh 2>&1 | tee generation.log

# Проверка конфигурации
cat ip-config.yml
```

### Проблема: "Bash syntax error in ufw-docker-rules-v4.sh"

**Причины:**
1. Некорректная обработка специальных символов
2. Проблемы с кодировкой

**Решение:**
```bash
# Восстановление из бэкапа
cp backups/ufw-docker-rules-v4.sh.*.backup ufw-docker-rules-v4.sh

# Проверка синтаксиса
bash -n ufw-docker-rules-v4.sh
```

### Проблема: "Too many IP addresses"

**Причины:**
- Добавление целой страны с большим количеством IP

**Решение:**
```yaml
# В ip-config.yml установите лимит
settings:
  max_ips_per_list: 5000  # Уменьшите лимит
```

### Проблема: "Rate limit exceeded" при запросах ASN

**Причины:**
- Слишком много запросов к API

**Решение:**
```bash
# Используйте кеш
export USE_GEOIP_CACHE=true

# Добавьте задержку между запросами
# (модифицируйте generate-ips.sh при необходимости)
```

---

## 📚 Дополнительные ресурсы

### Полезные ссылки

- **ASN информация:**
  - https://bgp.he.net/
  - https://www.peeringdb.com/
  - https://ipinfo.io/AS{number}

- **GeoIP базы:**
  - https://www.maxmind.com/en/geoip2-databases
  - https://dev.maxmind.com/geoip/geolite2-free-geolocation-data

- **IP блоки по странам:**
  - https://github.com/herrbischoff/country-ip-blocks
  - https://www.ipdeny.com/ipblocks/

### Документация UFW

- Основной README: `README.md`
- UFW мануал: `man ufw`
- Docker networking: https://docs.docker.com/network/

---

## 🆘 Поддержка

Если у вас возникли проблемы:

1. Проверьте логи: `cat /var/log/ufw-docker-setup.log`
2. Проверьте GitHub Actions логи
3. Создайте issue с описанием проблемы

---

## 📄 Лицензия

Этот проект распространяется под той же лицензией, что и основной скрипт.

---

**Последнее обновление:** 2025-01-29
