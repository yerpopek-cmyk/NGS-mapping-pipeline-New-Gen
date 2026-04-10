#!/usr/bin/env bash
# =============================================================================
# 07_rnaseq_qc.sh — RNA-Seq специфичные метрики
# Лекция «Картирование II», раздел 13
#
# Зачем нужны специальные метрики для RNA-Seq:
#   В отличие от WGS, у RNA-Seq есть:
#   - Сплайсинг (интроны не должны содержать ридов → если много = ДНК-контам.)
#   - Стрэндированность (риды должны идти с определённой цепи гена)
#   - Неравномерное покрытие тела гена (3'-bias = деградация РНК)
#
# Инструменты:
#   RSeQC read_distribution.py → % ридов на экзоны/интроны/UTR
#   RSeQC geneBody_coverage.py → равномерность покрытия 5'→3'
#   Qualimap rnaseq            → комплексный отчёт
# =============================================================================
set -euo pipefail

DATA="data"; MAP="results/mapping"; QC_MAP="results/qc_mapping"
mkdir -p "$QC_MAP/rnaseq"

YEAST_BAM="$MAP/yeast_dedup.bam"   # физически дедуплицированный BAM

# ─────────────────────────────────────────────────────────────
# 0. Конвертация GTF → BED (требует UCSC инструменты)
# ─────────────────────────────────────────────────────────────
# RSeQC требует BED-формат, а не GTF/GFF
# GTF → GenePred → BED
echo "Конвертация аннотации GTF → BED..."
if [ -f "$DATA/GCF000146045.gtf" ]; then
  gtfToGenePred \
    -genePredExt \
    -ignoreGroupsWithoutExons \
    "$DATA/GCF000146045.gtf" \
    "$DATA/GCF000146045.genePred"

  genePredToBed \
    "$DATA/GCF000146045.genePred" \
    "$DATA/GCF000146045.bed"
fi

BED="$DATA/GCF000146045.bed"

# ─────────────────────────────────────────────────────────────
# 1. Распределение ридов по частям гена
# ─────────────────────────────────────────────────────────────
echo ""
echo "[1/3] read_distribution.py — куда падают риды?"
# Ожидание для poly-A RNA-Seq:
#   CDS_Exons:   ~60-70%  ← большинство ридов
#   5'UTR:       ~5-10%
#   3'UTR:       ~15-20%
#   Introns:     < 15%   ← если больше → ДНК-контаминация?
#   Intergenic:  < 5%
read_distribution.py \
  -r "$BED" \
  -i "$YEAST_BAM" \
  > "$QC_MAP/rnaseq/read_distribution.txt" 2>/dev/null || \
  echo "  RSeQC не установлен, пропускаем"

cat "$QC_MAP/rnaseq/read_distribution.txt" 2>/dev/null | head -20

# ─────────────────────────────────────────────────────────────
# 2. Покрытие тела гена (5' → 3')
# ─────────────────────────────────────────────────────────────
echo ""
echo "[2/3] geneBody_coverage.py — равномерность 5'→3'?"
# Идеально: плоская горизонтальная линия
# 3'-bias (правый конец высокий): деградация РНК или poly-A enrichment
# 5'-bias (левый конец высокий): cap-enriched библиотека
geneBody_coverage.py \
  -r "$BED" \
  -i "$YEAST_BAM" \
  -o "$QC_MAP/rnaseq/genebody" 2>/dev/null || \
  echo "  RSeQC не установлен, пропускаем"

# ─────────────────────────────────────────────────────────────
# 3. Qualimap — комплексный QC для RNA-Seq
# ─────────────────────────────────────────────────────────────
echo ""
echo "[3/3] Qualimap rnaseq — комплексный отчёт..."
# Qualimap bamqc: для WGS/WES/ChIP
# Qualimap rnaseq: специально для RNA-Seq (знает про интроны)
qualimap rnaseq \
  -bam "$YEAST_BAM" \
  -gtf "$DATA/GCF000146045.gtf" \
  -outdir "$QC_MAP/rnaseq/qualimap" \
  --java-mem-size=4G \
  2>/dev/null || echo "  Qualimap не установлен, пропускаем"

# Qualimap для WGS (E. coli):
echo ""
echo "Qualimap bamqc для WGS (E. coli)..."
qualimap bamqc \
  -bam "$MAP/SRR292770_markdup.bam" \
  -gff "$DATA/U00096.gff" \
  -outdir "$QC_MAP/qualimap_ecoli" \
  --java-mem-size=4G \
  -c \
  2>/dev/null || echo "  Qualimap не установлен, пропускаем"

echo ""
echo "Отчёты: $QC_MAP/rnaseq/"
