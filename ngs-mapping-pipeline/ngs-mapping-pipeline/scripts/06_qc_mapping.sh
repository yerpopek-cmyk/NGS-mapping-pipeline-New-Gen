#!/usr/bin/env bash
# =============================================================================
# 06_qc_mapping.sh — Метрики качества выравнивания
# Лекция «Картирование II», разделы 5, 7, 9, 10, 11
#
# Инструменты:
#   samtools stats    — общая статистика (% картировалось, % дубликатов)
#   mosdepth          — покрытие (быстро, рекомендуется вместо samtools depth)
#   preseq            — кривая насыщения библиотеки
#   Picard InsertSize — распределение длин вставок
#   Picard GcBias     — GC-смещение покрытия
# =============================================================================
set -euo pipefail

DATA="data"; MAP="results/mapping"; QC_MAP="results/qc_mapping"; THREADS=4
mkdir -p "$QC_MAP"
SAMPLE="SRR292770"
BAM="$MAP/${SAMPLE}_markdup.bam"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[1/5] samtools flagstat — базовые флаги"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Показывает: % картировалось, % properly paired, % дубликатов
samtools flagstat "$BAM" | tee "$QC_MAP/${SAMPLE}_flagstat.txt"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[2/5] samtools stats — детальная статистика"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Многострочный отчёт. Ключевые строки (SN = Summary Numbers):
#   SN reads mapped:             → число картированных ридов
#   SN non-primary alignments:   → secondary alignments (мультикартирование)
#   SN average length:           → средняя длина рида
#   SN average quality:          → среднее качество
samtools stats "$BAM" > "$QC_MAP/${SAMPLE}_stats.txt"
grep "^SN" "$QC_MAP/${SAMPLE}_stats.txt" | \
  grep -E "reads (mapped|total)|non-primary|average (length|quality)" | \
  column -t

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[3/5] mosdepth — покрытие"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Формула покрытия: C = (N × L) / G
# mosdepth считает реальное покрытие по BAM (учитывает CIGAR)
# -n : не записывать per-base файл (намного быстрее для больших геномов)
# -F 1024 : исключить дубликаты из подсчёта покрытия
mosdepth -n --fast-mode -F 1024 \
  "$QC_MAP/${SAMPLE}" \
  "$BAM"

echo ""
echo "Результат покрытия:"
cat "$QC_MAP/${SAMPLE}.mosdepth.summary.txt" | column -t
echo ""
echo "Идеально для E. coli WGS: среднее покрытие > 50×"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[4/5] preseq — кривая насыщения библиотеки"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
# Оценивает: если секвенировать больше, сколько получим новых уникальных молекул?
# Плато → библиотека истощена, досеквенирование бессмысленно
# Линейный рост → библиотека богатая, можно секвенировать больше
preseq lc_extrap \
  -pe \
  -seg_len 100000 \
  -B "$BAM" \
  -o "$QC_MAP/${SAMPLE}_complexity_curve.txt" 2>/dev/null || \
  echo "  preseq не установлен, пропускаем"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "[5/5] Picard метрики"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Insert size distribution
# Ожидание для WGS Illumina: медиана 150-400 п.н.
# Если < 100: библиотека коротких фрагментов (деградация?)
# Если > 1000 и ориентация RF: возможно mate-pair библиотека
picard CollectInsertSizeMetrics \
  I="$BAM" \
  O="$QC_MAP/${SAMPLE}_insert_size.txt" \
  H="$QC_MAP/${SAMPLE}_insert_size.pdf" \
  2>/dev/null

echo "Insert size метрики:"
grep -A 2 "^MEDIAN_INSERT" "$QC_MAP/${SAMPLE}_insert_size.txt" | head -3

# GC bias
# NORMALIZED_COVERAGE ≈ 1.0 для всех GC → хорошо
# NORMALIZED_COVERAGE < 0.5 при высоком GC → ПЦР-проблема
picard CollectGcBiasMetrics \
  I="$BAM" \
  O="$QC_MAP/${SAMPLE}_gc_bias.txt" \
  CHART="$QC_MAP/${SAMPLE}_gc_bias.pdf" \
  S="$QC_MAP/${SAMPLE}_gc_summary.txt" \
  R="$DATA/U00096.fasta" \
  2>/dev/null

echo ""
echo "Все метрики: $QC_MAP/"
echo "Следующий шаг: bash scripts/08_multiqc.sh"
