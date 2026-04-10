#!/usr/bin/env bash
# =============================================================================
# 03_align.sh — Картирование ридов на референс
# Лекция «Картирование I», слайды 51-53
# Лекция «Картирование II», раздел HISAT2
#
# Алгоритм BWA-MEM2 (seed-and-extend):
#   1. SEED:   FM-index ищет точные k-меры (~19 п.н.) за O(k)
#   2. EXTEND: Smith-Waterman расширяет seed с допуском ошибок
#   3. SELECT: выбираем лучшее выравнивание, считаем MAPQ
#
# Параметры bwa-mem2 mem:
#   -t INT   число потоков
#   -M       маркировать secondary alignments (FLAG 0x100)
#            нужно для совместимости с Picard/GATK
#   -Y       soft clipping вместо hard clipping на концах ридов
#            → нуклеотиды сохраняются в SEQ (важно для SV поиска)
#   -R STR   Read Group (@RG) — метаданные
#            Формат: @RG\tID:<id>\tSM:<sample>\tPL:<platform>\tLB:<lib>
#            ОБЯЗАТЕЛЬНО для GATK HaplotypeCaller!
#   -k INT   длина seed'а (по умолчанию 19)
#            меньше k → чувствительнее, медленнее
#            больше k → быстрее, пропустит дивергентные риды
# =============================================================================
set -euo pipefail
conda activate mapping

DATA="data"; MAP="results/mapping"; THREADS=4
mkdir -p "$MAP"

SAMPLE_ID="SRR292770"
SAMPLE_NAME="Ecoli_K12"

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "РЕЖИМ 1: BWA-MEM2 (ДНК, WGS/WES)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Формат Read Group:
# ID  — уникальный идентификатор (обычно SRA accession или lane)
# SM  — имя образца (важно: одинаковый SM объединяет несколько lane)
# PL  — платформа (ILLUMINA, PACBIO, NANOPORE)
# LB  — название библиотеки (для определения дубликатов между lane)
# PU  — platform unit (flow cell + lane)

bwa-mem2 mem \
  -t "$THREADS" \
  -M \
  -Y \
  -R "@RG\tID:${SAMPLE_ID}\tSM:${SAMPLE_NAME}\tPL:ILLUMINA\tLB:lib1\tPU:unit1" \
  "$DATA/ecoli_ref" \
  "$DATA/${SAMPLE_ID}_1.fastq.gz" \
  "$DATA/${SAMPLE_ID}_2.fastq.gz" \
  > "$MAP/${SAMPLE_ID}.sam"

echo "SAM создан: $(du -sh $MAP/${SAMPLE_ID}.sam | cut -f1)"

# ─────────────────────────────────────────────────────────────
# Оценка скорости локального выравнивания (из лекции II):
# water — реализация Smith-Waterman (EMBOSS)
# Позволяет понять, ПОЧЕМУ мы используем seed-and-extend,
# а не чистый Smith-Waterman для всего генома
# ─────────────────────────────────────────────────────────────
# water read.fasta U00096.fasta
# Попробуй: для одного рида vs E. coli занимает ~5 секунд
# Для 5M ридов: 5 × 5,000,000 / 3600 ≈ 7000 часов!
# BWA-MEM2 делает это за ~5 минут (seed-and-extend + FM-index)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "РЕЖИМ 2: HISAT2 (RNA-Seq, сплайсинг)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# HISAT2 отличия от BWA-MEM2:
# - Использует graph-based index для сплайс-сайтов
# - Автоматически ищет интроны (длинные N в CIGAR)
# - Требует --rna-strandness если библиотека стрэндированная
# - Не требует GTF (но с ним точнее для известных изоформ)

if [ -d "$DATA/s_cerevisiae" ]; then
  hisat2 \
    -p "$THREADS" \
    -x "$DATA/s_cerevisiae/genome" \
    -1 "$DATA/SRR36689450_1.fastq.gz" \
    -2 "$DATA/SRR36689450_2.fastq.gz" \
    --rna-strandness RF \   # для stranded библиотек (dUTP метод)
    --dta \                 # downstream transcriptome assembly совместимость
    -S "$MAP/yeast.sam" \
    2> "$MAP/hisat2_summary.txt"

  echo "HISAT2 summary:"
  cat "$MAP/hisat2_summary.txt"
fi
