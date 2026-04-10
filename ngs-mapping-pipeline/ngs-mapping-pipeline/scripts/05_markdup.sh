#!/usr/bin/env bash
# =============================================================================
# 05_markdup.sh — Маркировка PCR-дубликатов (Picard MarkDuplicates)
# Лекция «Картирование II», раздел 6
#
# Типы дубликатов:
#   PCR-дубликаты:     несколько копий одной молекулы из-за амплификации
#   Оптические дубл.:  один кластер flow cell принят за два (NovaSeq чаще)
#
# Как Picard находит дубликаты:
#   Группирует риды с одинаковыми 5'-концами (обоих ридов пары)
#   В каждой группе: лучший по суммарному качеству = оригинал
#   Остальные → FLAG 0x400 (DUP)
#
# МАРКИРОВКА (не удаление):
#   Риды помечаются, но остаются в файле
#   Большинство инструментов (GATK, samtools mpileup) их автоматически игнорируют
#   Физическое удаление: samtools view -F 1024 если нужно
# =============================================================================
set -euo pipefail

MAP="results/mapping"
SAMPLE="SRR292770"

echo "Маркировка PCR-дубликатов (Picard MarkDuplicates)..."
picard MarkDuplicates \
  I="$MAP/${SAMPLE}_sorted.bam" \
  O="$MAP/${SAMPLE}_markdup.bam" \
  M="$MAP/${SAMPLE}_dup_metrics.txt" \
  OPTICAL_DUPLICATE_PIXEL_DISTANCE=2500 \
  CREATE_INDEX=true

echo ""
echo "Статистика дубликатов:"
grep -A 8 "^LIBRARY" "$MAP/${SAMPLE}_dup_metrics.txt" | head -5
echo ""
echo "  Норма:"
echo "    WGS/WES: PERCENT_DUPLICATION < 0.20 (< 20%)"
echo "    RNA-Seq: PERCENT_DUPLICATION < 0.50 (< 50%)"

# Для RNA-Seq: физически удалить для RSeQC (инструмент не понимает флаги)
if [ -f "$MAP/yeast_sorted.bam" ]; then
  echo ""
  echo "RNA-Seq (yeast): физическое удаление для RSeQC..."
  picard MarkDuplicates \
    I="$MAP/yeast_sorted.bam" \
    O="$MAP/yeast_markdup.bam" \
    M="$MAP/yeast_dup_metrics.txt"
  samtools index "$MAP/yeast_markdup.bam"

  # -F 1024 = исключить FLAG DUP (0x400)
  samtools view -h -b -F 1024 "$MAP/yeast_markdup.bam" \
    > "$MAP/yeast_dedup.bam"
  samtools index "$MAP/yeast_dedup.bam"
fi
