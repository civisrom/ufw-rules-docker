# UFW Rules Docker - Документация по работе с двумя скриптами

## Обзор

Система UFW Rules Docker поддерживает работу с **двумя независимыми UFW скриптами**: `ufw-docker-rules-v4.sh` и `ufw-docker-rules-v6.sh`.

### ⚠️ Важно понять:

- **v4 и v6 в названиях скриптов** - это просто названия, **НЕ** привязка к версии IP протокола
- **Каждый скрипт содержит И IPv4 И IPv6 адреса**
- Для каждого скрипта можно указать **свои собственные** ASN, страны и города
- Это позволяет настроить разные правила для разных сценариев использования

## Структура конфигурации (v3.1)

### Глобальные настройки

```yaml
generation:
  # Какие скрипты обновлять:
  # v4 - только ufw-docker-rules-v4.sh
  # v6 - только ufw-docker-rules-v6.sh
  # both - оба скрипта (рекомендуется)
  update_scripts: "both"

  # Глобальное включение/отключение IPv6
  ipv6_enabled: true
```

### Настройки для каждого скрипта

```yaml
# Настройки для ufw-docker-rules-v4.sh (первый скрипт)
ufw_v4_script:
  ssh_allowed_ips:
    ipv4:
      asn: ["AS48004"]      # IPv4 адреса для v4 скрипта
      countries: ["RU"]
    ipv6:
      enabled: true
      asn: ["AS48004"]      # IPv6 адреса для v4 скрипта
      countries: ["RU"]

# Настройки для ufw-docker-rules-v6.sh (второй скрипт)
ufw_v6_script:
  ssh_allowed_ips:
    ipv4:
      asn: ["AS13335"]      # ДРУГИЕ IPv4 адреса для v6 скрипта!
      countries: ["US"]     # ДРУГИЕ страны!
    ipv6:
      enabled: true
      asn: ["AS13335"]      # ДРУГИЕ IPv6 адреса для v6 скрипта!
      countries: ["US"]
```

## Структура генерируемых файлов

```
generated-ips/
# Файлы для ufw-docker-rules-v4.sh:
├── v4_ssh_allowed_ips.txt         # IPv4 для v4 скрипта, SSH
├── v4_ssh_allowed_ips_ipv6.txt    # IPv6 для v4 скрипта, SSH
├── v4_docker_allowed_ips.txt      # IPv4 для v4 скрипта, Docker
├── v4_docker_allowed_ips_ipv6.txt # IPv6 для v4 скрипта, Docker
├── v4_rustdesk_allowed_ips.txt
├── v4_rustdesk_allowed_ips_ipv6.txt

# Файлы для ufw-docker-rules-v6.sh:
├── v6_ssh_allowed_ips.txt         # IPv4 для v6 скрипта, SSH
├── v6_ssh_allowed_ips_ipv6.txt    # IPv6 для v6 скрипта, SSH
├── v6_docker_allowed_ips.txt      # IPv4 для v6 скрипта, Docker
├── v6_docker_allowed_ips_ipv6.txt # IPv6 для v6 скрипта, Docker
├── v6_rustdesk_allowed_ips.txt
└── v6_rustdesk_allowed_ips_ipv6.txt
```

## Команды

### Генерация IP списков

```bash
# Генерация списков согласно generation.update_scripts
./generate-ips.sh
```

Скрипт автоматически:
- Читает `generation.update_scripts` из `ip-config.yml`
- Генерирует файлы для соответствующих скриптов
- Для каждого скрипта создает И IPv4 И IPv6 файлы

### Обновление UFW скриптов

```bash
# Использовать generation.update_scripts из конфигурации (рекомендуется)
./update-ufw-script.sh

# ИЛИ переопределить режим вручную:

# Обновить ТОЛЬКО ufw-docker-rules-v4.sh
./update-ufw-script.sh --v4

# Обновить ТОЛЬКО ufw-docker-rules-v6.sh
./update-ufw-script.sh --v6

# Обновить ОБА скрипта
./update-ufw-script.sh --both
```

## Примеры использования

### Пример 1: Разные провайдеры для разных скриптов

```yaml
# v4 скрипт использует российских провайдеров
ufw_v4_script:
  ssh_allowed_ips:
    ipv4:
      asn: ["AS48004", "AS8359"]  # Российские ASN
    ipv6:
      enabled: true
      asn: ["AS48004", "AS8359"]

# v6 скрипт использует международные провайдеры
ufw_v6_script:
  ssh_allowed_ips:
    ipv4:
      asn: ["AS13335", "AS15169"]  # Cloudflare + Google
    ipv6:
      enabled: true
      asn: ["AS13335", "AS15169"]
```

**Результат:**
- `ufw-docker-rules-v4.sh` содержит IPv4 + IPv6 от российских провайдеров
- `ufw-docker-rules-v6.sh` содержит IPv4 + IPv6 от международных провайдеров

### Пример 2: Разные страны для разных скриптов

```yaml
# v4 скрипт для России
ufw_v4_script:
  docker_allowed_ips:
    ipv4:
      countries: ["RU"]
    ipv6:
      enabled: true
      countries: ["RU"]

# v6 скрипт для США
ufw_v6_script:
  docker_allowed_ips:
    ipv4:
      countries: ["US"]
    ipv6:
      enabled: true
      countries: ["US"]
```

### Пример 3: Один скрипт с IPv6, другой без

```yaml
# v4 скрипт БЕЗ IPv6
ufw_v4_script:
  ssh_allowed_ips:
    ipv4:
      asn: ["AS48004"]
    ipv6:
      enabled: false  # Отключить IPv6 для v4 скрипта

# v6 скрипт С IPv6
ufw_v6_script:
  ssh_allowed_ips:
    ipv4:
      asn: ["AS13335"]
    ipv6:
      enabled: true   # Включить IPv6 для v6 скрипта
      asn: ["AS13335"]
```

### Пример 4: Обновление только одного скрипта

```yaml
generation:
  update_scripts: "v4"  # Обновлять только ufw-docker-rules-v4.sh
  ipv6_enabled: true
```

## Сценарии использования

### Сценарий 1: Продакшн и тестовый сервер

- **ufw-docker-rules-v4.sh** - продакшн правила (строгие, только доверенные сети)
- **ufw-docker-rules-v6.sh** - тестовые правила (более широкие диапазоны)

### Сценарий 2: Разные регионы

- **ufw-docker-rules-v4.sh** - правила для России/СНГ
- **ufw-docker-rules-v6.sh** - правила для международного доступа

### Сценарий 3: Разные сервисы

- **ufw-docker-rules-v4.sh** - внутренние сервисы
- **ufw-docker-rules-v6.sh** - публичные API

## GitHub Actions

Workflow автоматически:

```yaml
- name: Generate IP lists
  run: ./generate-ips.sh  # Генерирует файлы для обоих скриптов

- name: Update UFW scripts
  run: ./update-ufw-script.sh  # Обновляет оба скрипта
```

### Как это работает:

1. `generate-ips.sh` читает `generation.update_scripts` из `ip-config.yml`
2. Если `update_scripts: "both"`:
   - Генерирует `v4_*` файлы из секции `ufw_v4_script`
   - Генерирует `v6_*` файлы из секции `ufw_v6_script`
3. `update-ufw-script.sh` обновляет соответствующие скрипты:
   - `ufw-docker-rules-v4.sh` ← читает `v4_*` файлы
   - `ufw-docker-rules-v6.sh` ← читает `v6_*` файлы

## Архитектура

### Процесс генерации

```
ip-config.yml
    ↓
generation.update_scripts = "both"
    ↓
    ├─→ ufw_v4_script.*  →  v4_*.txt  →  ufw-docker-rules-v4.sh
    └─→ ufw_v6_script.*  →  v6_*.txt  →  ufw-docker-rules-v6.sh
```

### Детальная схема

```
generate-ips.sh:
  1. Читает generation.update_scripts
  2. Если "v4" или "both":
     - Читает ufw_v4_script.ssh_allowed_ips.ipv4.* → v4_ssh_allowed_ips.txt
     - Читает ufw_v4_script.ssh_allowed_ips.ipv6.* → v4_ssh_allowed_ips_ipv6.txt
     - То же для docker и rustdesk
  3. Если "v6" или "both":
     - Читает ufw_v6_script.ssh_allowed_ips.ipv4.* → v6_ssh_allowed_ips.txt
     - Читает ufw_v6_script.ssh_allowed_ips.ipv6.* → v6_ssh_allowed_ips_ipv6.txt
     - То же для docker и rustdesk

update-ufw-script.sh:
  1. Читает generation.update_scripts
  2. Если "v4" или "both":
     - Обновляет ufw-docker-rules-v4.sh:
       * SSH_ALLOWED_IPS ← v4_ssh_allowed_ips.txt
       * SSH_ALLOWED_IPS_IPV6 ← v4_ssh_allowed_ips_ipv6.txt
       * То же для docker и rustdesk
  3. Если "v6" или "both":
     - Обновляет ufw-docker-rules-v6.sh:
       * SSH_ALLOWED_IPS ← v6_ssh_allowed_ips.txt
       * SSH_ALLOWED_IPS_IPV6 ← v6_ssh_allowed_ips_ipv6.txt
       * То же для docker и rustdesk
```

## Источники данных MaxMind

Для каждого списка (IPv4 и IPv6) используются соответствующие CSV базы:

**IPv4:**
- `GeoLite2-ASN-Blocks-IPv4.csv`
- `GeoLite2-Country-Blocks-IPv4.csv`
- `GeoLite2-City-Blocks-IPv4.csv`

**IPv6:**
- `GeoLite2-ASN-Blocks-IPv6.csv`
- `GeoLite2-Country-Blocks-IPv6.csv`
- `GeoLite2-City-Blocks-IPv6.csv`

## Troubleshooting

### Не генерируются файлы для v6 скрипта

**Проверьте:**

```yaml
generation:
  update_scripts: "both"  # Должно быть "both" или "v6"
```

### В скриптах нет IPv6 адресов

**Проверьте:**

1. Глобальная настройка:
   ```yaml
   generation:
     ipv6_enabled: true  # Должно быть true
   ```

2. Настройка конкретного списка:
   ```yaml
   ufw_v4_script:
     ssh_allowed_ips:
       ipv6:
         enabled: true  # Должно быть true
   ```

### Проверка сгенерированных файлов

```bash
# Для v4 скрипта
ls -lh generated-ips/v4_*

# Для v6 скрипта
ls -lh generated-ips/v6_*

# Проверить содержимое
wc -l generated-ips/v4_*.txt
wc -l generated-ips/v6_*.txt
```

### Валидация IP адресов

```bash
# Проверить IPv4 для v4 скрипта
python3 -c "
import ipaddress
for line in open('generated-ips/v4_ssh_allowed_ips.txt'):
    ipaddress.ip_network(line.strip())
print('v4 SSH IPv4: OK')
"

# Проверить IPv6 для v4 скрипта
python3 -c "
import ipaddress
for line in open('generated-ips/v4_ssh_allowed_ips_ipv6.txt'):
    ipaddress.ip_network(line.strip())
print('v4 SSH IPv6: OK')
"
```

## Лучшие практики

1. **Явно указывайте `generation.update_scripts`** в конфигурации
2. **Используйте осмысленные разделения**:
   - v4 скрипт - для одного назначения
   - v6 скрипт - для другого назначения
3. **Документируйте назначение** каждого скрипта в комментариях
4. **Тестируйте оба скрипта** перед применением в продакшне
5. **Коммитьте ip-config.yml** для автоматического обновления через GitHub Actions

## Миграция с версии 3.0

**Было (v3.0):**
```yaml
version: "3.0"
generation:
  mode: "both"

ssh_allowed_ips:
  ipv4: ...
  ipv6: ...
```

**Стало (v3.1):**
```yaml
version: "3.1"
generation:
  update_scripts: "both"

ufw_v4_script:
  ssh_allowed_ips:
    ipv4: ...
    ipv6: ...

ufw_v6_script:
  ssh_allowed_ips:
    ipv4: ...
    ipv6: ...
```

### Ключевые изменения:

- `generation.mode` → `generation.update_scripts`
- Одна секция `ssh_allowed_ips` → две секции `ufw_v4_script.ssh_allowed_ips` и `ufw_v6_script.ssh_allowed_ips`
- Файлы `ssh_allowed_ips.txt` → `v4_ssh_allowed_ips.txt` и `v6_ssh_allowed_ips.txt`
