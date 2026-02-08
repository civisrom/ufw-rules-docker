# UFW Rules Docker - Документация по IPv6

## Обзор

Система UFW Rules Docker поддерживает **dual-stack** работу с IPv4 и IPv6 адресами с полным контролем над каждой версией протокола.

### Основные возможности:

- **Раздельная конфигурация**: Можно указать разные ASN, страны и города для IPv4 и IPv6
- **Индивидуальное управление**: Каждый список (SSH, Docker, RustDesk) может иметь свои настройки IPv6
- **Гибкое отключение**: IPv6 можно отключить глобально или для конкретного списка
- **Режимы работы**: Генерация только IPv4, только IPv6, или обоих одновременно

## Структура конфигурации (v3.0)

### Глобальные настройки

```yaml
generation:
  # Режим работы: v4, v6, или both
  mode: "both"

  # Глобальное включение/отключение IPv6
  ipv6_enabled: true
```

### Настройки списков IP

Каждый список имеет **отдельные** секции для IPv4 и IPv6:

```yaml
ssh_allowed_ips:
  # ========== IPv4 конфигурация ==========
  ipv4:
    asn:
      - "AS48004"
    countries:
      - "RU"
    cities:
      - "RU/Moscow"
    direct_ips:
      - "192.168.1.0/24"

  # ========== IPv6 конфигурация ==========
  ipv6:
    enabled: true  # Можно отключить для конкретного списка
    asn:
      - "AS48004"  # Можно указать другие ASN, отличные от IPv4
    countries:
      - "US"  # Можно указать другие страны
    cities:
      - "US/California/San Francisco"  # Другие города
    direct_ips:
      - "2001:db8::/32"
```

## Структура файлов с IP адресами

Скрипт `generate-ips.sh` создает парные файлы для каждого списка:

```
generated-ips/
├── ssh_allowed_ips.txt         # IPv4 адреса для SSH
├── ssh_allowed_ips_ipv6.txt    # IPv6 адреса для SSH
├── docker_allowed_ips.txt      # IPv4 адреса для Docker
├── docker_allowed_ips_ipv6.txt # IPv6 адреса для Docker
├── rustdesk_allowed_ips.txt    # IPv4 адреса для RustDesk
└── rustdesk_allowed_ips_ipv6.txt # IPv6 адреса для RustDesk
```

**Примечание**: Если IPv6 отключен для списка, соответствующий `*_ipv6.txt` файл будет пустым.

## UFW скрипты

Система использует два скрипта для управления правилами:

- **ufw-docker-rules-v4.sh** - использует IPv4 списки (`*_allowed_ips.txt`)
- **ufw-docker-rules-v6.sh** - использует IPv6 списки (`*_allowed_ips_ipv6.txt`)

## Команды

### Генерация IP списков

```bash
# Генерация списков в соответствии с generation.mode из конфигурации
./generate-ips.sh
```

Скрипт автоматически:
- Читает `generation.mode` из `ip-config.yml`
- Генерирует только IPv4, только IPv6, или оба
- Уважает `ipv6.enabled` для каждого списка

### Обновление UFW скриптов

```bash
# Использовать generation.mode из конфигурации (рекомендуется)
./update-ufw-script.sh

# ИЛИ переопределить режим вручную:

# Обновить ТОЛЬКО ufw-docker-rules-v4.sh
./update-ufw-script.sh --v4

# Обновить ТОЛЬКО ufw-docker-rules-v6.sh
./update-ufw-script.sh --v6

# Обновить ОБА скрипта
./update-ufw-script.sh --both
```

### Полный цикл обновления

```bash
# 1. Генерация всех списков согласно конфигурации
./generate-ips.sh

# 2. Обновление скриптов согласно конфигурации
./update-ufw-script.sh

# 3. Применение правил (по необходимости)
sudo ./ufw-docker-rules-v4.sh  # Если generation.mode = "v4" или "both"
sudo ./ufw-docker-rules-v6.sh  # Если generation.mode = "v6" или "both"
```

## Режимы работы

### Режим 1: Только IPv4

```yaml
generation:
  mode: "v4"
  ipv6_enabled: false  # Глобально отключить IPv6
```

Результат:
- Генерируются только `*_allowed_ips.txt` файлы
- Обновляется только `ufw-docker-rules-v4.sh`

### Режим 2: Только IPv6

```yaml
generation:
  mode: "v6"
  ipv6_enabled: true
```

Результат:
- Генерируются только `*_allowed_ips_ipv6.txt` файлы
- Обновляется только `ufw-docker-rules-v6.sh`

### Режим 3: Dual-stack (рекомендуется)

```yaml
generation:
  mode: "both"
  ipv6_enabled: true
```

Результат:
- Генерируются все файлы (IPv4 + IPv6)
- Обновляются оба скрипта

## Примеры конфигураций

### Пример 1: Одинаковые источники для IPv4 и IPv6

```yaml
generation:
  mode: "both"
  ipv6_enabled: true

ssh_allowed_ips:
  ipv4:
    asn: ["AS48004"]
  ipv6:
    enabled: true
    asn: ["AS48004"]  # Те же ASN
```

### Пример 2: Разные источники для IPv4 и IPv6

```yaml
generation:
  mode: "both"
  ipv6_enabled: true

docker_allowed_ips:
  ipv4:
    countries: ["RU"]  # Россия для IPv4
  ipv6:
    enabled: true
    countries: ["US"]  # США для IPv6
```

### Пример 3: IPv6 отключен для конкретного списка

```yaml
generation:
  mode: "both"
  ipv6_enabled: true

rustdesk_allowed_ips:
  ipv4:
    asn: ["AS13335"]
  ipv6:
    enabled: false  # Не генерировать IPv6 для RustDesk
```

### Пример 4: Прямые IP адреса + ASN

```yaml
ssh_allowed_ips:
  ipv4:
    direct_ips:
      - "192.168.1.0/24"
      - "10.0.0.0/8"
    asn:
      - "AS48004"
  ipv6:
    enabled: true
    direct_ips:
      - "2001:db8::/32"
      - "fd00::/8"
    asn:
      - "AS13335"  # Другой ASN для IPv6
```

## GitHub Actions

Workflow `.github/workflows/update-ips.yml` полностью автоматизирован и уважает настройки конфигурации:

```yaml
- name: Generate IP lists
  run: ./generate-ips.sh  # Использует generation.mode

- name: Update UFW scripts
  run: ./update-ufw-script.sh  # Использует generation.mode
```

### Триггеры запуска

- **По расписанию**: Каждый день в 2:00 UTC
- **При изменении конфигурации**: Push в `ip-config.yml`
- **Вручную**: Через интерфейс GitHub Actions

## Источники данных MaxMind

Система использует следующие CSV базы от MaxMind:

**Для IPv4:**
- `GeoLite2-ASN-Blocks-IPv4.csv`
- `GeoLite2-Country-Blocks-IPv4.csv`
- `GeoLite2-City-Blocks-IPv4.csv`

**Для IPv6:**
- `GeoLite2-ASN-Blocks-IPv6.csv`
- `GeoLite2-Country-Blocks-IPv6.csv`
- `GeoLite2-City-Blocks-IPv6.csv`

Базы автоматически скачиваются и кешируются в `maxmind-data/`.

## Архитектура

### Процесс генерации

1. **generate-ips.sh**:
   - Читает `generation.mode` и `generation.ipv6_enabled` из конфигурации
   - Для каждого списка:
     - Если `mode = "v4"` или `"both"`: читает `{список}.ipv4.*` и генерирует IPv4 файл
     - Если `mode = "v6"` или `"both"` И `ipv6_enabled = true`: проверяет `{список}.ipv6.enabled`
     - Если `{список}.ipv6.enabled = true`: читает `{список}.ipv6.*` и генерирует IPv6 файл

2. **update-ufw-script.sh**:
   - Читает `generation.mode` из конфигурации (если не передан параметр)
   - Обновляет соответствующие скрипты

3. **extract-ips-from-maxmind.py**:
   - Принимает флаг `--ipv6` для выбора CSV баз
   - Извлекает IP блоки из соответствующих файлов MaxMind

## Troubleshooting

### Не генерируются IPv6 адреса

**Проверьте:**

1. Глобальная настройка:
   ```yaml
   generation:
     ipv6_enabled: true  # Должно быть true
   ```

2. Настройка конкретного списка:
   ```yaml
   ssh_allowed_ips:
     ipv6:
       enabled: true  # Должно быть true
   ```

3. Режим генерации:
   ```yaml
   generation:
     mode: "both"  # Или "v6"
   ```

4. Наличие IPv6 баз MaxMind:
   ```bash
   ls -la maxmind-data/GeoLite2-*/
   # Должны быть *-Blocks-IPv6.csv файлы
   ```

### Проверка режима работы

```bash
# Посмотреть какой режим в конфигурации
grep -A 2 "^generation:" ip-config.yml

# Проверить какие файлы сгенерированы
ls -lh generated-ips/
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

## Миграция с версии 2.0

Если у вас старая конфигурация (без секций `ipv4`/`ipv6`), нужно обновить структуру:

**Было (v2.0):**
```yaml
ssh_allowed_ips:
  asn:
    - "AS48004"
  countries:
    - "RU"
```

**Стало (v3.0):**
```yaml
generation:
  mode: "both"
  ipv6_enabled: true

ssh_allowed_ips:
  ipv4:
    asn:
      - "AS48004"
    countries:
      - "RU"
  ipv6:
    enabled: true
    asn:
      - "AS48004"
    countries:
      - "RU"
```

## Лучшие практики

1. **Всегда указывайте `generation.mode`** в конфигурации явно
2. **Используйте раздельные источники** для IPv4 и IPv6, если у провайдеров разные диапазоны
3. **Отключайте IPv6 выборочно** только для тех списков, где он действительно не нужен
4. **Проверяйте логи генерации** для понимания какие файлы создаются
5. **Коммитьте ip-config.yml** в репозиторий для автоматического обновления через GitHub Actions
