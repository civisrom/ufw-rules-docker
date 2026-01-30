#!/usr/bin/env python3
"""
Диагностика ASN в MaxMind CSV базах
"""

import csv
import os
from pathlib import Path

# Найдем CSV файлы
cache_dir = Path(".cache/csv/GeoLite2-ASN-CSV")

print("=" * 60)
print("Поиск MaxMind ASN CSV файлов...")
print("=" * 60)

if not cache_dir.exists():
    print(f"❌ Директория {cache_dir} не существует")
    print("\nЗапустите сначала: ./generate-ips.sh")
    exit(1)

# Найдем CSV файл с блоками ASN
blocks_csv = None
for root, dirs, files in os.walk(cache_dir):
    for file in files:
        if "ASN" in file and file.endswith(".csv"):
            print(f"✓ Найден CSV файл: {file}")
            if "Blocks" in file and "IPv4" in file:
                blocks_csv = Path(root) / file
                print(f"  → Используется для анализа: {blocks_csv}")

if not blocks_csv or not blocks_csv.exists():
    print("\n❌ CSV файл с ASN блоками не найден!")
    exit(1)

print("\n" + "=" * 60)
print("Анализ структуры CSV файла...")
print("=" * 60)

# Читаем первые 5 строк для анализа
with open(blocks_csv, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f)
    print(f"\nКолонки в CSV файле: {reader.fieldnames}")

    print("\nПервые 5 записей:")
    for i, row in enumerate(reader):
        if i >= 5:
            break
        print(f"\n  Запись {i+1}:")
        for key, value in row.items():
            print(f"    {key}: {value}")

print("\n" + "=" * 60)
print("Поиск ваших ASN...")
print("=" * 60)

# Проверяем каждый ASN
test_asns = ["48004", "201776", "48000", "8359", "29194", "203451", "203561"]

for asn in test_asns:
    count = 0
    sample_ips = []

    with open(blocks_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            # Проверяем разные варианты
            asn_value = row.get('autonomous_system_number', '')

            # Убираем 'AS' префикс если есть и сравниваем
            if asn_value:
                asn_clean = str(asn_value).replace('AS', '').replace('as', '').strip()
                if asn_clean == asn:
                    count += 1
                    if len(sample_ips) < 3:
                        sample_ips.append(row.get('network', 'N/A'))

    if count > 0:
        print(f"\n✓ AS{asn}: найдено {count} IP блоков")
        print(f"  Примеры: {', '.join(sample_ips[:3])}")
    else:
        print(f"\n❌ AS{asn}: НЕ НАЙДЕНО (0 блоков)")

print("\n" + "=" * 60)
print("Поиск популярных ASN для сравнения...")
print("=" * 60)

popular_asns = [
    ("13335", "Cloudflare"),
    ("15169", "Google"),
    ("16509", "Amazon AWS"),
]

for asn, name in popular_asns:
    count = 0
    with open(blocks_csv, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f)
        for row in reader:
            asn_value = str(row.get('autonomous_system_number', '')).replace('AS', '').replace('as', '').strip()
            if asn_value == asn:
                count += 1

    print(f"AS{asn} ({name}): {count} IP блоков")

print("\n" + "=" * 60)
print("Готово!")
print("=" * 60)
