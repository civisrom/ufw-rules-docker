# UFW Rules for Docker with IP Management

Комплексная система для управления правилами UFW в Docker окружении с автоматической генерацией IP адресов из различных источников.

## 📋 Основные возможности

- **Автоматическое управление IP адресами** из ASN, стран, городов и CIDR
- **Раздельные белые списки** для SSH, Docker и RustDesk
- **GitHub Actions автоматизация** для ежедневного обновления IP
- **Настраиваемые порты** для всех сервисов
- **Резервное копирование** конфигураций
- **Валидация** IP адресов и синтаксиса
- **Оптимизация** CIDR блоков для эффективности

## 🚀 Быстрый старт

### 1. Клонирование репозитория

```bash
git clone https://github.com/yourusername/ufw-rules-docker.git
cd ufw-rules-docker
```

### 2. Настройка IP источников

Отредактируйте `ip-config.yml`:

```yaml
ssh_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"    # Ваш офис
  asn:
    - "AS13335"           # Cloudflare
  countries:
    - "RU"                # Россия
```

### 3. Генерация IP списков (локально)

```bash
# Установка зависимостей
sudo apt-get install -y curl jq python3 python3-pip
pip3 install PyYAML

# Генерация IP адресов
./generate-ips.sh

# Обновление UFW скрипта
./update-ufw-script.sh

# Запуск UFW скрипта
sudo ./ufw-docker-rules-v4.sh
```

### 4. GitHub Actions автоматизация

1. Добавьте секрет `MAXMIND_LICENSE_KEY` в репозиторий
2. Коммитьте изменения в `ip-config.yml`
3. Workflow автоматически обновит скрипт

## 📁 Структура проекта

```
├── ufw-docker-rules-v4.sh     # Основной UFW скрипт
├── ip-config.yml              # Конфигурация источников IP
├── generate-ips.sh            # Генератор IP списков
├── update-ufw-script.sh       # Обновление UFW скрипта
├── IP-MANAGEMENT.md           # Полная документация
├── .github/workflows/
│   ├── update-ips.yml         # Автообновление IP
│   └── GeoLite.yml            # GeoIP базы данных
├── generated-ips/             # Сгенерированные списки
├── backups/                   # Резервные копии
└── .cache/                    # Кеш GeoIP баз
```

## 📚 Документация

- **[IP-MANAGEMENT.md](IP-MANAGEMENT.md)** - Полное руководство по управлению IP адресами
  - Источники IP (ASN, страны, города, CIDR)
  - Примеры конфигураций
  - Локальное использование
  - GitHub Actions настройка
  - Troubleshooting

## 🔍 Источники IP адресов

### Прямые IP/CIDR
```yaml
direct_ips:
  - "203.0.113.0/24"
  - "198.51.100.10/32"
```

### ASN (Autonomous System Numbers)
```yaml
asn:
  - "AS13335"    # Cloudflare
  - "AS15169"    # Google
  - "AS16509"    # Amazon AWS
```

### Страны (ISO 3166-1)
```yaml
countries:
  - "RU"    # Россия
  - "US"    # США
  - "DE"    # Германия
```

### Города (требуется GeoLite2)
```yaml
cities:
  - "RU/Moscow"
  - "US/California/San Francisco"
```

## 🤖 GitHub Actions

Workflow автоматически:
- Генерирует IP списки из настроенных источников
- Оптимизирует и дедуплицирует IP адреса
- Обновляет `ufw-docker-rules-v4.sh`
- Создает коммит с изменениями
- Валидирует IP адреса

Запускается:
- Каждый день в 2:00 UTC
- При изменении `ip-config.yml`
- Вручную через GitHub UI

## ⚙️ Конфигурация UFW скрипта

Скрипт `ufw-docker-rules-v4.sh` поддерживает:

### SSH правила
- Настраиваемый порт
- Белый список IP адресов
- Автоматическая защита текущей сессии

### Docker контейнеры
- Правила для конкретных IP:PORT
- Правила для сетей (CIDR)
- Поддержка TCP/UDP протоколов

### RustDesk
- Настраиваемые порты (21115-21117 по умолчанию)
- Отдельный белый список IP
- Входящие правила (не route)

### DNS правила
- Автоматические правила для DNS серверов
- Поддержка DoH/DoT (порт 443)
- Двунаправленные правила

## 🛡️ Безопасность

- Все изменения логируются в `/var/log/ufw-docker-setup.log`
- Автоматические резервные копии перед изменениями
- Валидация IP адресов перед применением
- Проверка синтаксиса bash скриптов
- Защита от случайной блокировки SSH

## 🔧 Требования

- Ubuntu/Debian или CentOS/RHEL
- UFW установлен
- Docker (опционально)
- Python 3.6+ (для оптимизации IP)
- curl, jq (для генерации IP)

## 📝 Примеры использования

### Пример 1: Офисный доступ
```yaml
ssh_allowed_ips:
  direct_ips:
    - "203.0.113.0/24"
```

### Пример 2: AWS инфраструктура
```yaml
docker_allowed_ips:
  asn:
    - "AS16509"    # Amazon AWS
```

### Пример 3: Международная компания
```yaml
ssh_allowed_ips:
  countries:
    - "US"
    - "GB"
    - "DE"
  direct_ips:
    - "10.0.0.0/8"
```

## 🐛 Troubleshooting

См. секцию [Troubleshooting](IP-MANAGEMENT.md#troubleshooting) в IP-MANAGEMENT.md

## 📄 Лицензия

MIT License - см. файл LICENSE

## 🤝 Вклад в проект

Pull requests приветствуются!

## ⭐ Благодарности

- MaxMind за GeoLite2 базы данных
- Сообщество UFW и Docker