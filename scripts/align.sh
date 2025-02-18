#!/bin/bash

set -e

trimmed_dir="../data/trimmed"
output_dir="../reports"
temp_dir="$output_dir/temp_coverage"
GENOME_SIZE=4000000
MAMBA_PATH="/home/paula/conda/bin/mamba"

mkdir -p "$output_dir" "$temp_dir"

process_sample() {
    local sample=$1
    local sample_dir="$trimmed_dir/${sample}"
    local temp_output="$temp_dir/${sample}_coverage.txt"
    local short_coverage=0
    local long_coverage=0
    local coverage=0
    
    local forward_reads=$(ls $sample_dir/*R1_paired_trimmed.fastq.gz 2>/dev/null || ls $sample_dir/*_1.fastq.gz 2>/dev/null || echo "")
    local reverse_reads=$(ls $sample_dir/*R2_paired_trimmed.fastq.gz 2>/dev/null || ls $sample_dir/*_2.fastq.gz 2>/dev/null || echo "")
    local long_reads=$(ls $sample_dir/*long_trimmed.fastq.gz 2>/dev/null || echo "")

    echo "Procesando muestra: $sample"
    
    if [ -n "$forward_reads" ] && [ -n "$reverse_reads" ]; then
        local short_bases=$($MAMBA_PATH run -n qc_env bash -c "zcat '$forward_reads' '$reverse_reads' | awk 'NR%4==2 {total+=length(\$0)} END {print total}'")
        short_coverage=$(echo "scale=4; $short_bases / $GENOME_SIZE" | bc)
        echo "Coverage paired-end: $short_coverage"
    fi
    
    if [ -n "$long_reads" ]; then
        local long_bases=$($MAMBA_PATH run -n qc_env bash -c "zcat '$long_reads' | awk 'NR%4==2 {total+=length(\$0)} END {print total}'")
        long_coverage=$(echo "scale=4; $long_bases / $GENOME_SIZE" | bc)
        echo "Coverage long reads: $long_coverage"
    fi
    
    if [ -z "$forward_reads" ] && [ -z "$long_reads" ]; then
        echo "ERROR: No se encontraron lecturas para $sample"
        return
    fi
    
    if [ -n "$forward_reads" ] && [ -n "$long_reads" ]; then
        coverage=$(echo "scale=4; $short_coverage + $long_coverage" | bc)
        echo "Coverage total: $coverage"
    elif [ -n "$forward_reads" ]; then
        coverage=$short_coverage
    else
        coverage=$long_coverage
    fi
    
    echo "Muestra: $sample" > "$temp_output"
    if [ -n "$forward_reads" ] && [ -n "$long_reads" ]; then
        echo "Tipo de lecturas: paired-end y long reads" >> "$temp_output"
        echo "Coverage paired-end: $short_coverage" >> "$temp_output"
        echo "Coverage long reads: $long_coverage" >> "$temp_output"
        echo "Coverage total: $coverage" >> "$temp_output"
    elif [ -n "$forward_reads" ]; then
        echo "Tipo de lecturas: paired-end" >> "$temp_output"
        echo "Coverage: $coverage" >> "$temp_output"
    else
        echo "Tipo de lecturas: long reads" >> "$temp_output"
        echo "Coverage: $coverage" >> "$temp_output"
    fi
    
    if [ -n "$forward_reads" ]; then
        echo "Forward: $(basename "$forward_reads")" >> "$temp_output"
        echo "Reverse: $(basename "$reverse_reads")" >> "$temp_output"
    fi
    if [ -n "$long_reads" ]; then
        echo "Long reads: $(basename "$long_reads")" >> "$temp_output"
    fi
    echo "" >> "$temp_output"
}

for sample_dir in "$trimmed_dir"/*_trimmed; do
    if [ -d "$sample_dir" ]; then
        process_sample "$(basename "$sample_dir")"
    fi
done

output_file="$output_dir/coverage_report.txt"
echo "Reporte de Coverage" > "$output_file"
echo "-------------------" >> "$output_file"

if ls "$temp_dir"/* 1> /dev/null 2>&1; then
    cat "$temp_dir"/* >> "$output_file"
else
    echo "No se encontraron resultados" >> "$output_file"
fi

cat "$output_file"
rm -rf "$temp_dir"