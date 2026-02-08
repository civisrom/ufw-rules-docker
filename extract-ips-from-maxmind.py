#!/usr/bin/env python3
# ============================================
# MaxMind GeoLite2 IP Extractor v1.0
# ============================================
# Извлекает IP адреса из MaxMind GeoLite2 баз данных
# ============================================

import sys
import os
import csv
import ipaddress
import argparse
import urllib.request
import urllib.error
import zipfile
import time
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
    def __init__(self, cache_dir: str, ipv6: bool = False):
        self.cache_dir = Path(cache_dir).resolve()
        # Используем maxmind-data для хранения CSV баз
        self.csv_dir = self.cache_dir
        self.metadata_dir = self.cache_dir / ".metadata"
        self.ipv6 = ipv6  # IPv6 режим
        self.csv_dir.mkdir(parents=True, exist_ok=True)
        self.metadata_dir.mkdir(parents=True, exist_ok=True)

    def extract_csv_from_mmdb(self, db_name: str) -> bool:
        """Извлекает CSV файлы из .mmdb базы данных"""
        log_info(f"Поиск CSV данных для {db_name}...")

        # MaxMind предоставляет CSV файлы отдельно
        # Нужно скачать CSV версию базы
        return False

    def get_remote_etag(self, url: str) -> str:
        """Получает ETag удаленного файла через HEAD запрос"""
        try:
            req = urllib.request.Request(url, method='HEAD', headers={'User-Agent': 'Mozilla/5.0'})
            with urllib.request.urlopen(req, timeout=30) as response:
                etag = response.headers.get('ETag', '').strip('"')
                return etag
        except Exception as e:
            log_warning(f"Не удалось получить ETag: {e}")
            return ""

    def get_saved_etag(self, db_name: str) -> str:
        """Читает сохраненный ETag из метаданных"""
        etag_file = self.metadata_dir / f"{db_name}-etag.txt"
        if etag_file.exists():
            try:
                return etag_file.read_text().strip()
            except:
                return ""
        return ""

    def save_etag(self, db_name: str, etag: str):
        """Сохраняет ETag в метаданные"""
        etag_file = self.metadata_dir / f"{db_name}-etag.txt"
        try:
            etag_file.write_text(etag)
        except Exception as e:
            log_warning(f"Не удалось сохранить ETag: {e}")

    def download_csv_database(self, db_name: str, license_key: str) -> bool:
        """Скачивает CSV версию базы данных MaxMind с проверкой актуальности через ETag"""
        log_info(f"Проверка базы данных: {db_name}...")

        url = f"https://download.maxmind.com/app/geoip_download?edition_id={db_name}&license_key={license_key}&suffix=zip"
        zip_path = self.cache_dir / f"{db_name}.zip"
        extract_dir = self.csv_dir / db_name

        try:
            # Проверяем наличие распакованной базы
            if extract_dir.exists():
                # Получаем удаленный ETag
                log_info(f"Проверка актуальности {db_name}...")
                remote_etag = self.get_remote_etag(url)
                saved_etag = self.get_saved_etag(db_name)

                if remote_etag and saved_etag and remote_etag == saved_etag:
                    log_success(f"✓ {db_name} актуальна (ETag совпадает)")
                    return True
                elif remote_etag and saved_etag:
                    log_info(f"{db_name} устарела, обновление...")
                else:
                    log_info(f"{db_name} будет обновлена (ETag недоступен)")

            # Скачиваем с повторными попытками
            log_info(f"Загрузка {db_name} CSV...")
            max_retries = 3
            response_etag = ""

            for attempt in range(max_retries):
                try:
                    # Скачиваем с timeout
                    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
                    with urllib.request.urlopen(req, timeout=60) as response:
                        # Сохраняем ETag из ответа
                        response_etag = response.headers.get('ETag', '').strip('"')
                        with open(zip_path, 'wb') as out_file:
                            out_file.write(response.read())
                    break  # Успешно скачали
                except (urllib.error.URLError, urllib.error.HTTPError, TimeoutError) as e:
                    if attempt < max_retries - 1:
                        log_warning(f"Попытка {attempt + 1}/{max_retries} не удалась: {e}. Повтор...")
                        time.sleep(2 ** attempt)  # Exponential backoff: 1s, 2s, 4s
                    else:
                        raise  # Последняя попытка - прокидываем исключение

            # Распаковываем
            log_info(f"Распаковка {db_name}...")
            extract_dir.mkdir(parents=True, exist_ok=True)

            with zipfile.ZipFile(zip_path, 'r') as zip_ref:
                zip_ref.extractall(extract_dir)

            # Сохраняем ETag
            if response_etag:
                self.save_etag(db_name, response_etag)
                log_info(f"Сохранен ETag: {response_etag[:16]}...")

            # Удаляем временный ZIP файл для экономии места
            try:
                zip_path.unlink()
                log_info(f"Временный файл {zip_path.name} удален")
            except Exception:
                pass  # Не критично если не удалось удалить

            log_success(f"✓ {db_name} CSV база загружена и распакована")
            return True

        except urllib.error.HTTPError as e:
            if e.code == 401:
                log_error(f"Ошибка аутентификации: неверный License Key")
            else:
                log_error(f"HTTP ошибка {e.code}: {e.reason}")
            return False
        except urllib.error.URLError as e:
            log_error(f"Сетевая ошибка при загрузке {db_name}: {e.reason}")
            return False
        except zipfile.BadZipFile:
            log_error(f"Поврежденный ZIP файл: {db_name}")
            # Удаляем поврежденный файл
            try:
                zip_path.unlink()
            except:
                pass
            return False
        except Exception as e:
            log_error(f"Непредвиденная ошибка при загрузке {db_name}: {e}")
            return False

    def get_ips_by_country(self, country_code: str) -> Set[str]:
        """Получает IP блоки по коду страны"""
        ip_version = "IPv6" if self.ipv6 else "IPv4"
        log_info(f"Извлечение {ip_version} для страны: {country_code}")

        ips = set()

        # Ищем CSV файлы GeoLite2-Country
        country_csv = None
        blocks_csv = None
        blocks_file_pattern = "Country-Blocks-IPv6.csv" if self.ipv6 else "Country-Blocks-IPv4.csv"

        for root, dirs, files in os.walk(self.csv_dir / "GeoLite2-Country-CSV"):
            for file in files:
                if file.endswith("Country-Locations-en.csv"):
                    country_csv = Path(root) / file
                elif file.endswith(blocks_file_pattern):
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
                        # Конвертируем geoname_id в строку для надежного сравнения
                        gid = str(row.get('geoname_id', '')).strip()
                        if gid:
                            geoname_ids.add(gid)
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
                    # Конвертируем geoname_id в строку для сравнения
                    gid = str(row.get('geoname_id', '')).strip()
                    reg_gid = str(row.get('registered_country_geoname_id', '')).strip()
                    if gid in geoname_ids or reg_gid in geoname_ids:
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

        ip_version = "IPv6" if self.ipv6 else "IPv4"
        log_info(f"Извлечение {ip_version} для ASN: AS{asn_number}")

        ips = set()

        # Ищем CSV файлы GeoLite2-ASN
        blocks_csv = None
        blocks_file_pattern = "ASN-Blocks-IPv6.csv" if self.ipv6 else "ASN-Blocks-IPv4.csv"

        for root, dirs, files in os.walk(self.csv_dir / "GeoLite2-ASN-CSV"):
            for file in files:
                if file.endswith(blocks_file_pattern):
                    blocks_csv = Path(root) / file

        if not blocks_csv:
            log_warning(f"CSV файлы GeoLite2-ASN не найдены")
            return ips

        # Читаем blocks
        try:
            with open(blocks_csv, 'r', encoding='utf-8') as f:
                reader = csv.DictReader(f)
                for row in reader:
                    # MaxMind CSV хранит ASN как число, конвертируем в строку для сравнения
                    csv_asn = str(row.get('autonomous_system_number', '')).strip()
                    if csv_asn == asn_number:
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
        ip_version = "IPv6" if self.ipv6 else "IPv4"
        log_info(f"Извлечение {ip_version} для города: {city_spec}")

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
        blocks_file_pattern = "City-Blocks-IPv6.csv" if self.ipv6 else "City-Blocks-IPv4.csv"

        for root, dirs, files in os.walk(self.csv_dir / "GeoLite2-City-CSV"):
            for file in files:
                if file.endswith("City-Locations-en.csv"):
                    city_csv = Path(root) / file
                elif file.endswith(blocks_file_pattern):
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
                        # Конвертируем geoname_id в строку для надежного сравнения
                        gid = str(row.get('geoname_id', '')).strip()
                        if gid:
                            geoname_ids.add(gid)
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
                    # Конвертируем geoname_id в строку для сравнения
                    gid = str(row.get('geoname_id', '')).strip()
                    if gid in geoname_ids:
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
    parser.add_argument('--ipv6', action='store_true',
                       help='Извлекать IPv6 адреса (по умолчанию: IPv4)')

    args = parser.parse_args()

    if not any([args.country, args.asn, args.city]):
        log_error("Укажите хотя бы один источник: --country, --asn или --city")
        sys.exit(1)

    ip_version = "IPv6" if args.ipv6 else "IPv4"
    print(f"{Colors.GREEN}========================================")
    print(f"  MaxMind GeoLite2 IP Extractor v1.0 ({ip_version})")
    print(f"========================================{Colors.NC}\n")

    extractor = MaxMindExtractor(args.cache_dir, ipv6=args.ipv6)
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
