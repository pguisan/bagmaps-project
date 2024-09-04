#!/usr/bin/env bash

set -euo pipefail

# Definir los parámetros
BASE_DIR="${1:-..}"
FASTQC_DIR="${BASE_DIR}/results/fastqc_after"
OUTPUT_DIR="${BASE_DIR}/reports"
OUTPUT_FILE="${OUTPUT_DIR}/sequencing_quality_report.txt"
DEBUG_FILE="${OUTPUT_DIR}/debug_report.txt"

# Función para imprimir mensajes de error
error() {
    echo "ERROR: $*" >&2
}

# Función para imprimir mensajes de depuración
debug() {
    echo "$*" >> "$DEBUG_FILE"
}

# Función para extraer datos de un archivo FastQC
extract_fastqc_data() {
    local zip_file="$1"
    debug "Procesando archivo: $zip_file"
    
    if [[ ! -f "$zip_file" ]]; then
        error "El archivo $zip_file no existe"
        return 1
    fi
    
    local fastqc_data
    fastqc_data=$(unzip -p "$zip_file" "*/fastqc_data.txt" 2>/dev/null) || {
        error "No se pudo extraer datos de $zip_file"
        return 1
    }
    
    local filename total_sequences sequence_length gc_content mean_quality
    filename=$(echo "$fastqc_data" | awk -F'\t' '/^Filename/ {print $2; exit}')
    total_sequences=$(echo "$fastqc_data" | awk -F'\t' '/^Total Sequences/ {print $2; exit}')
    sequence_length=$(echo "$fastqc_data" | awk -F'\t' '/^Sequence length/ {print $2; exit}')
    gc_content=$(echo "$fastqc_data" | awk -F'\t' '/^%GC/ {print $2; exit}')
    
    local quality_scores
    quality_scores=$(echo "$fastqc_data" | awk -F'\t' '/^>>Per base sequence quality/,/^>>END_MODULE/ {if (NR > 2 && $1 !~ /^#/) print $2}')
    mean_quality=$(echo "$quality_scores" | awk '{sum+=$1} END {printf "%.2f", sum/NR}')
    
    echo "$filename|$total_sequences|$sequence_length|$gc_content|$mean_quality"
}

main() {
    # Crear los directorios y archivos necesarios
    mkdir -p "$OUTPUT_DIR"
    : > "$OUTPUT_FILE"
    : > "$DEBUG_FILE"
    
    debug "Iniciando script. BASE_DIR=$BASE_DIR"
    debug "Buscando archivos FastQC en: $FASTQC_DIR"
    debug "Archivos encontrados:"
    ls -l "$FASTQC_DIR"/*.zip >> "$DEBUG_FILE" 2>&1
    
    # Procesar los archivos FastQC
    while IFS= read -r -d '' fastqc_zip; do
        debug "Procesando: $fastqc_zip"
        fastqc_data=$(extract_fastqc_data "$fastqc_zip")
        IFS='|' read -r filename total_sequences sequence_length gc_content mean_quality <<< "$fastqc_data"
        
        debug "Procesando: $filename"
        base_name="${filename%%_*}"
        
        if [[ "$filename" == *"_long_"* ]]; then
            read_type="long"
        elif [[ "$filename" == *"_R1_"* ]]; then
            read_type="short_R1"
        elif [[ "$filename" == *"_R2_"* ]]; then
            read_type="short_R2"
        else
            read_type="unknown"
        fi
        
        echo -e "$base_name\t$read_type\t$total_sequences\t$sequence_length\t$gc_content\t$mean_quality" >> "$OUTPUT_FILE"
    done < <(find "$FASTQC_DIR" -name "*.zip" -print0)
    
    echo "Informe generado en: $OUTPUT_FILE"
    echo "Registro de depuración generado en: $DEBUG_FILE"
}

main "$@"