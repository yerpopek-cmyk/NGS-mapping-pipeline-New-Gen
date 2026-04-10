#!/usr/bin/env bash
# =============================================================================
# 08_multiqc.sh — Агрегировать все QC-отчёты в один HTML
# Лекция «Картирование II», раздел 12
#
# MultiQC автоматически находит и парсит:
#   FastQC отчёты (*_fastqc.zip)
#   samtools stats (*_stats.txt)
#   samtools flagstat (*_flagstat.txt)
#   Picard MarkDuplicates (*_dup_metrics.txt)
#   Picard InsertSizeMetrics (*_insert_size.txt)
#   Picard GcBiasMetrics (*_gc_bias.txt)
#   mosdepth (*.mosdepth.summary.txt)
#   preseq (*_complexity_curve.txt)
#   HISAT2 summary (*hisat2_summary.txt)
#   Qualimap (qualimap_bamqc/)
#
# Один HTML → легко поделиться с коллегами и в публикации
# =============================================================================
set -euo pipefail
conda activate QC_fastq

REPORT_DIR="results/multiqc_report"
mkdir -p "$REPORT_DIR"

echo "Сбор всех QC-отчётов в один MultiQC HTML..."
multiqc \
  results/ \          # сканировать всю папку results/
  --outdir "$REPORT_DIR" \
  --filename "multiqc_report.html" \
  --title "NGS Mapping QC — E. coli + S. cerevisiae" \
  --force \           # перезаписать если уже существует
  --verbose

echo ""
echo "Отчёт: $REPORT_DIR/multiqc_report.html"
echo ""
echo "Ключевые разделы в отчёте:"
echo "  General Statistics — сводная таблица всех образцов"
echo "  FastQC            — качество сырых ридов"
echo "  Picard            — дубликаты, insert size, GC-bias"
echo "  samtools          — % картировалось, покрытие"
echo "  mosdepth          — распределение покрытия"
echo "  preseq            — кривая насыщения"

# Создать архив для отправки:
zip -r "$REPORT_DIR/multiqc_report.zip" "$REPORT_DIR/" 2>/dev/null
echo ""
echo "Архив: $REPORT_DIR/multiqc_report.zip"
