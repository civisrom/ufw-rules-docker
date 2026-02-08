# UFW Rules Docker - Документация по IPv6

## Обзор

Система UFW Rules Docker поддерживает **dual-stack** работу с IPv4 и IPv6 адресами. Из одной конфигурации `ip-config.yml` автоматически генерируются списки как для IPv4, так и для IPv6.

## Структура файлов с IP адресами

Скрипт `generate-ips.sh` автоматически создает **парные файлы** для каждого списка:

```
generated-ips/
├── ssh_allowed_ips.txt         # IPv4 адреса для SSH
├── ssh_allowed_ips_ipv6.txt    # IPv6 адреса для SSH
├── docker_allowed_ips.txt      # IPv4 адреса для Docker
├── docker_allowed_ips_ipv6.txt # IPv6 адреса для Docker
├── rustdesk_allowed_ips.txt    # IPv4 адреса для RustDesk
└── rustdesk_allowed_ips_ipv6.txt # IPv6 адреса для RustDesk
```

## UFW скрипты

Система использует два скрипта для управления правилами:

- **ufw-docker-rules-v4.sh** - использует IPv4 списки (`*_allowed_ips.txt`)
- **ufw-docker-rules-v6.sh** - использует IPv6 списки (`*_allowed_ips_ipv6.txt`)

Оба скрипта обновляются из одной конфигурации `ip-config.yml`.

## Конфигурация

В `ip-config.yml` указывается **ОДИН** набор источников (ASN/страны/города), из которого автоматически извлекаются как IPv4, так и IPv6 адреса:

```yaml
ssh_allowed_ips:
  asn:
    - "AS48004"  # Автоматически генерирует IPv4 И IPv6 адреса
  countries:
    - "US"       # Автоматически генерирует IPv4 И IPv6 адреса
  cities:
    - "RU/Moscow" # Автоматически генерирует IPv4 И IPv6 адреса
```

### Источники данных MaxMind

Система использует следующие CSV базы от MaxMind:

**Для IPv4:**
- `GeoLite2-ASN-Blocks-IPv4.csv`
- `GeoLite2-Country-Blocks-IPv4.csv`
- `GeoLite2-City-Blocks-IPv4.csv`

**Для IPv6:**
- `GeoLite2-ASN-Blocks-IPv6.csv`
- `GeoLite2-Country-Blocks-IPv6.csv`
- `GeoLite2-City-Blocks-IPv6.csv`

## Команды

### Генерация IP списков

```bash
# Генерирует ВСЕ списки (IPv4 + IPv6) автоматически
./generate-ips.sh
```

Эта команда создаст 6 файлов в `generated-ips/`:
- 3 файла с IPv4 адресами
- 3 файла с IPv6 адресами

### Обновление UFW скриптов

```bash
# Обновить ТОЛЬКО ufw-docker-rules-v4.sh (IPv4)
./update-ufw-script.sh --v4

# Обновить ТОЛЬКО ufw-docker-rules-v6.sh (IPv6)
./update-ufw-script.sh --v6

# Обновить ОБА скрипта (рекомендуется)
./update-ufw-script.sh --both
```

### Полный цикл обновления

```bash
# 1. Генерация всех списков
./generate-ips.sh

# 2. Обновление обоих скриптов
./update-ufw-script.sh --both

# 3. Применение правил (по необходимости)
sudo ./ufw-docker-rules-v4.sh
sudo ./ufw-docker-rules-v6.sh
```

## GitHub Actions

Workflow `.github/workflows/update-ips.yml` полностью автоматизирован:

1. **Генерация списков**: Выполняет `generate-ips.sh` для создания IPv4 и IPv6 списков
2. **Обновление скриптов**: Выполняет `update-ufw-script.sh --both` для обновления обоих UFW скриптов
3. **Валидация**: Проверяет корректность всех IPv4 и IPv6 адресов
4. **Коммит**: Автоматически коммитит изменения в репозиторий

### Триггеры запуска

Workflow запускается автоматически:
- **По расписанию**: Каждый день в 2:00 UTC
- **При изменении конфигурации**: Push в `ip-config.yml`, `generate-ips.sh`, `update-ufw-script.sh`, `extract-ips-from-maxmind.py`
- **Вручную**: Через интерфейс GitHub Actions

## Архитектура

### Процесс генерации

1. **extract-ips-from-maxmind.py**:
   - Принимает параметр `--ipv6` для выбора версии IP
   - Использует соответствующие CSV файлы (IPv4 или IPv6)
   - Извлекает IP блоки по ASN, странам, городам

2. **generate-ips.sh**:
   - Функция `generate_ip_list_version()` генерирует списки для одной версии
   - Функция `generate_ip_list()` вызывает `generate_ip_list_version()` дважды:
     - С `ipv6=false` для IPv4 версии
     - С `ipv6=true` для IPv6 версии
   - Каждый вызов создает отдельный файл

3. **update-ufw-script.sh**:
   - Режим `--v4`: обновляет `ufw-docker-rules-v4.sh` из `*_allowed_ips.txt`
   - Режим `--v6`: обновляет `ufw-docker-rules-v6.sh` из `*_allowed_ips_ipv6.txt`
   - Режим `--both`: обновляет оба скрипта

### Оптимизация

Система автоматически оптимизирует IP блоки:
- **Дедупликация**: Удаляет дубликаты
- **Консолидация**: Объединяет соседние CIDR блоки
- **Валидация**: Проверяет корректность всех адресов

## Примеры использования

### Пример 1: Разрешить SSH только с российских IPv4 и IPv6

```yaml
ssh_allowed_ips:
  countries:
    - "RU"
```

Результат:
- `ssh_allowed_ips.txt` - все российские IPv4 блоки
- `ssh_allowed_ips_ipv6.txt` - все российские IPv6 блоки

### Пример 2: Docker доступ для Cloudflare (dual-stack)

```yaml
docker_allowed_ips:
  asn:
    - "AS13335"  # Cloudflare
```

Результат:
- `docker_allowed_ips.txt` - IPv4 диапазоны Cloudflare
- `docker_allowed_ips_ipv6.txt` - IPv6 диапазоны Cloudflare

### Пример 3: Комбинированная конфигурация

```yaml
ssh_allowed_ips:
  direct_ips:
    - "10.0.0.0/8"  # Только IPv4 (прямой IP)
  asn:
    - "AS48004"     # IPv4 + IPv6 из ASN
  countries:
    - "RU"          # IPv4 + IPv6 из страны
```

## Важные замечания

1. **Прямые IP адреса** (`direct_ips`) НЕ дублируются - они добавляются только в основной файл
2. **ASN, страны, города** автоматически извлекаются для обеих версий IP
3. **Оба скрипта работают независимо** - можно применять правила отдельно для v4 и v6
4. **MaxMind базы** кешируются в `maxmind-data/` и обновляются только при изменении

## Troubleshooting

### Не генерируются IPv6 адреса

Проверьте наличие IPv6 баз MaxMind:
```bash
ls -la maxmind-data/GeoLite2-*/
```

Должны быть файлы:
- `GeoLite2-ASN-Blocks-IPv6.csv`
- `GeoLite2-Country-Blocks-IPv6.csv`
- `GeoLite2-City-Blocks-IPv6.csv`

### Проверка сгенерированных списков

```bash
# Проверить количество IPv4 блоков
wc -l generated-ips/*_allowed_ips.txt

# Проверить количество IPv6 блоков
wc -l generated-ips/*_allowed_ips_ipv6.txt
```

### Валидация IP адресов

```bash
# Проверить валидность IPv4
python3 -c "
import ipaddress
for line in open('generated-ips/ssh_allowed_ips.txt'):
    ipaddress.ip_network(line.strip())
print('IPv4: OK')
"

# Проверить валидность IPv6
python3 -c "
import ipaddress
for line in open('generated-ips/ssh_allowed_ips_ipv6.txt'):
    ipaddress.ip_network(line.strip())
print('IPv6: OK')
"
```
