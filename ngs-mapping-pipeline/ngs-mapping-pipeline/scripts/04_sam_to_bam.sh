#!/usr/bin/env bash
# =============================================================================
# 04_sam_to_bam.sh — SAM → BAM + сортировка + индекс
# Лекция «Картирование I», слайд 60-61
#
# Зачем конвертировать:
#   SAM (~200 GB для WGS 30×) → BAM (~45 GB, в 4-5× меньше)
#   BAM = BGZF-сжатый SAM (Blocked GNU Zip Format)
#   BGZF позволяет произвольный доступ к позиции — нужен .bai индекс
#
# Зачем сортировать по координатам:
#   samtools tview, IGV, GATK, bcftools требуют отсортированный BAM
#   .bai индекс позволяет перейти к любой позиции за O(log N)
#
# Альтернатива: pipe от выравнивателя (экономит место на диске):
#   bwa-mem2 mem ... | samtools sort -o out.bam
# =============================================================================
set -euo pipefail
conda activate mapping

MAP="results/mapping"; THREADS=4
SAMPLE="SRR292770"

echo "SAM → BAM + сортировка по координатам..."
# -@ : число потоков
# -m : память на поток (для сортировки)
# -o : выходной файл
samtools sort -@ "$THREADS" -m 2G \
  -o "$MAP/${SAMPLE}_sorted.bam" \
  "$MAP/${SAMPLE}.sam"

echo "Индексирование BAM (.bai)..."
# .bai — бинарный индекс, позволяет jump к хромосоме/позиции
samtools index -@ "$THREADS" "$MAP/${SAMPLE}_sorted.bam"

echo ""
echo "Удаляем SAM (экономия места)..."
rm "$MAP/${SAMPLE}.sam"

echo ""
echo "Результаты:"
ls -lh "$MAP/${SAMPLE}_sorted.bam"*

echo ""
echo "Базовый просмотр:"
echo "  samtools view $MAP/${SAMPLE}_sorted.bam | head -3"
samtools view "$MAP/${SAMPLE}_sorted.bam" | head -3

echo ""
echo "Визуализация в терминале:"
echo "  samtools tview $MAP/${SAMPLE}_sorted.bam $DATA/U00096.fasta"
echo "  g → перейти к позиции, ? → помощь, q → выйти"
