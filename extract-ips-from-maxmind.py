#!/usr/bin/env python3
# ============================================
# MaxMind GeoLite2 IP Extractor v1.0
# ============================================
# Извлекает IP адреса из MaxMind GeoLite2 баз данных
# ============================================

import sys
import os
import gzip
import csv
import ipaddress
import argparse
from pathlib import Path
from typing import Set, List

# Цветной вывод
class Colors:
    RED = '\033[0;31m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    BLUE = '\033[0;34m'
    CYAN = '\033[0;36m'
    NC = '\033[0m'

def log_info(message):
    print(f"{Colors.BLUE}[INFO]{Colors.NC} {message}")

def log_success(message):
    print(f"{Colors.GREEN}[SUCCESS]{Colors.NC} {message}")

def log_warning(message):
    print(f"{Colors.YELLOW}[WARNING]{Colors.NC} {message}")

def log_error(message):
    print(f"{Colors.RED}[ERROR]{Colors.NC} {message}", file=sys.stderr)

class MaxMindExtractor:
    def __init__(self, cache_dir: str):
        self.cache_dir = Path(cache_dir)
        self.csv_dir = self.cache_dir / "csv"
        self.csv_dir.mkdir(parents=True, exist_ok=True)

    def extract_csv_from_mmdb(self, db_name: str) -> bool:
        """Извлекает CSV файлы из .mmdb базы данных"""
        log_info(f"Поиск CSV данных для {db_name}...")

        # MaxMind предоставляет CSV файлы отдельно
        # Нужно скачать CSV версию базы
        return False

    def download_csv_database(self, db_name: str, license_key: str) -> bool:
        """Скачивает CSV версию базы данных MaxMind"""
        import urllib.request
        import tarfile

        log_info(f"Скачивание CSV базы данных: {db_name}...")

        url = f"https://download.maxmind.com/app/geoip_download?edition_id={db_name}&license_key={license_key}&suffix=zip"

        try:
            zip_path = self.cache_dir / f"{db_name}.zip"

            # Проверяем возраст файла
            if zip_path.exists():
                import time
                file_age = time.time() - zip_path.stat().st_mtime
                if file_age < 7 * 24 * 3600:  # 7 дней
                    log_info(f"CSV база {db_name} актуальна (возраст: {int(file_age / 86400)} дней)")
                    return True

            # Скачиваем
            log_info(f"Загрузка {db_name} CSV...")
            urllib.request.urlretrieve(url, zip_path)

            # Распаковываем
            import zipfile
            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(self.csv_dir / db_name)

            log_success(f"✓ {db_name} CSV база загружена и распакована")
            return True

        except Exception as e:
            log_error(f"Ошибка загрузки {db_name}: {e}")
            return False

    def get_ips_by_country(self, country_code: str) -> Set[str]:
        """Получает IP блоки по коду страны"""
        log_info(f"Извлечение IP для страны: {country_code}")

        ips = set()

        # Ищем CSV файлы GeoLite2-Country
        country_csv = None
        blocks_csv = None

        for root, dirs, files in os.walk(self.csv_dir / "GeoLite2-Country"):
            for file in files:
                if file.endswith("Country-Locations-en.csv"):
                    country_csv = Path(root) / file
                elif file.endswith("Country-Blocks-IPv4.csv"):
                    blocks_csv = Path(root) / file

        if not country_csv or not blocks_csv:
            log_warning(f"CSV файлы GeoLite2-Country не найдены")
            return ips

        # Читаем locations для получения geoname_id
        geoname_ids = set()
        try:
            with open(country_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('country_iso_code') == country_code:
                        geoname_ids.add(row.get('geoname_id'))
        except Exception as e:
            log_error(f"Ошибка чтения {country_csv}: {e}")
            return ips

        if not geoname_ids:
            log_warning(f"Не найден geoname_id для страны {country_code}")
            return ips

        # Читаем blocks для получения IP
        try:
            with open(blocks_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('geoname_id') in geoname_ids or \
                       row.get('registered_country_geoname_id') in geoname_ids:
                        network = row.get('network')
                        if network:
                            ips.add(network)
        except Exception as e:
            log_error(f"Ошибка чтения {blocks_csv}: {e}")
            return ips

        log_success(f"✓ Найдено {len(ips)} IP блоков для {country_code}")
        return ips

    def get_ips_by_asn(self, asn: str) -> Set[str]:
        """Получает IP блоки по ASN"""
        # Удаляем префикс AS если есть
        asn_number = asn.replace('AS', '').replace('as', '')

        log_info(f"Извлечение IP для ASN: AS{asn_number}")

        ips = set()

        # Ищем CSV файлы GeoLite2-ASN
        blocks_csv = None

        for root, dirs, files in os.walk(self.csv_dir / "GeoLite2-ASN"):
            for file in files:
                if file.endswith("ASN-Blocks-IPv4.csv"):
                    blocks_csv = Path(root) / file

        if not blocks_csv:
            log_warning(f"CSV файлы GeoLite2-ASN не найдены")
            return ips

        # Читаем blocks
        try:
            with open(blocks_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('autonomous_system_number') == asn_number:
                        network = row.get('network')
                        if network:
                            ips.add(network)
        except Exception as e:
            log_error(f"Ошибка чтения {blocks_csv}: {e}")
            return ips

        log_success(f"✓ Найдено {len(ips)} IP блоков для AS{asn_number}")
        return ips

    def get_ips_by_city(self, city_spec: str) -> Set[str]:
        """Получает IP блоки по городу"""
        log_info(f"Извлечение IP для города: {city_spec}")

        # Парсим спецификацию города: "Страна/Город" или "Страна/Регион/Город"
        parts = city_spec.split('/')
        if len(parts) < 2:
            log_error(f"Неверный формат города: {city_spec}. Используйте: Страна/Город")
            return set()

        country = parts[0]
        city = parts[-1]

        ips = set()

        # Ищем CSV файлы GeoLite2-City
        city_csv = None
        blocks_csv = None

        for root, dirs, files in os.walk(self.csv_dir / "GeoLite2-City"):
            for file in files:
                if file.endswith("City-Locations-en.csv"):
                    city_csv = Path(root) / file
                elif file.endswith("City-Blocks-IPv4.csv"):
                    blocks_csv = Path(root) / file

        if not city_csv or not blocks_csv:
            log_warning(f"CSV файлы GeoLite2-City не найдены")
            return ips

        # Читаем locations для получения geoname_id
        geoname_ids = set()
        try:
            with open(city_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if (row.get('country_iso_code') == country and
                        row.get('city_name', '').lower() == city.lower()):
                        geoname_ids.add(row.get('geoname_id'))
        except Exception as e:
            log_error(f"Ошибка чтения {city_csv}: {e}")
            return ips

        if not geoname_ids:
            log_warning(f"Не найден geoname_id для города {city_spec}")
            return ips

        # Читаем blocks для получения IP
        try:
            with open(blocks_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    if row.get('geoname_id') in geoname_ids:
                        network = row.get('network')
                        if network:
                            ips.add(network)
        except Exception as e:
            log_error(f"Ошибка чтения {blocks_csv}: {e}")
            return ips

        log_success(f"✓ Найдено {len(ips)} IP блоков для {city_spec}")
        return ips

def optimize_cidrs(cidrs: Set[str]) -> List[str]:
    """Оптимизирует и объединяет CIDR блоки"""
    log_info("Оптимизация CIDR блоков...")

    try:
        networks = []
        for cidr in cidrs:
            try:
                networks.append(ipaddress.ip_network(cidr, strict=False))
            except ValueError:
                log_warning(f"Пропуск невалидного CIDR: {cidr}")
                continue

        if not networks:
            return []

        # Сортируем и объединяем
        networks = sorted(set(networks))
        collapsed = list(ipaddress.collapse_addresses(networks))

        log_success(f"✓ Оптимизировано: {len(cidrs)} → {len(collapsed)} CIDR блоков")

        return [str(net) for net in collapsed]

    except Exception as e:
        log_error(f"Ошибка оптимизации: {e}")
        return list(cidrs)

def main():
    parser = argparse.ArgumentParser(
        description='Извлечение IP адресов из MaxMind GeoLite2 баз данных'
    )
    parser.add_argument('--cache-dir', default='.cache',
                       help='Директория кеша (по умолчанию: .cache)')
    parser.add_argument('--license-key', required=True,
                       help='MaxMind License Key')
    parser.add_argument('--country', action='append',
                       help='ISO код страны (например: RU, US)')
    parser.add_argument('--asn', action='append',
                       help='ASN номер (например: AS13335)')
    parser.add_argument('--city', action='append',
                       help='Город в формате Страна/Город (например: RU/Moscow)')
    parser.add_argument('--output', '-o', required=True,
                       help='Выходной файл')
    parser.add_argument('--optimize', action='store_true',
                       help='Оптимизировать CIDR блоки')

    args = parser.parse_args()

    if not any([args.country, args.asn, args.city]):
        log_error("Укажите хотя бы один источник: --country, --asn или --city")
        sys.exit(1)

    print(f"{Colors.GREEN}========================================")
    print(f"  MaxMind GeoLite2 IP Extractor v1.0")
    print(f"========================================{Colors.NC}\n")

    extractor = MaxMindExtractor(args.cache_dir)
    all_ips = set()

    # Скачиваем необходимые базы
    databases_needed = set()
    if args.country:
        databases_needed.add('GeoLite2-Country-CSV')
    if args.asn:
        databases_needed.add('GeoLite2-ASN-CSV')
    if args.city:
        databases_needed.add('GeoLite2-City-CSV')

    for db in databases_needed:
        if not extractor.download_csv_database(db, args.license_key):
            log_error(f"Не удалось загрузить базу {db}")
            sys.exit(1)

    print()

    # Извлекаем IP по странам
    if args.country:
        for country in args.country:
            ips = extractor.get_ips_by_country(country.upper())
            all_ips.update(ips)

    # Извлекаем IP по ASN
    if args.asn:
        for asn in args.asn:
            ips = extractor.get_ips_by_asn(asn)
            all_ips.update(ips)

    # Извлекаем IP по городам
    if args.city:
        for city in args.city:
            ips = extractor.get_ips_by_city(city)
            all_ips.update(ips)

    if not all_ips:
        log_warning("Не найдено IP адресов")
        sys.exit(0)

    # Оптимизация
    if args.optimize:
        final_ips = optimize_cidrs(all_ips)
    else:
        final_ips = sorted(all_ips)

    # Сохраняем результат
    try:
        output_path = Path(args.output)
        output_path.parent.mkdir(parents=True, exist_ok=True)

        with open(output_path, 'w') as f:
            for ip in final_ips:
                f.write(f"{ip}\n")

        log_success(f"✓ Сохранено {len(final_ips)} IP блоков в {args.output}")

    except Exception as e:
        log_error(f"Ошибка сохранения: {e}")
        sys.exit(1)

    print(f"\n{Colors.GREEN}========================================")
    print(f"  Извлечение завершено успешно")
    print(f"========================================{Colors.NC}\n")

if __name__ == '__main__':
    main()
