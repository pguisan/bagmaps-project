#!/bin/bash

# Definir los parámetros del informe
fastqc_dir="../results/fastqc_after"
output_file="../reports/sequencing_quality_report.txt"
debug_file="../reports/debug_report.txt"

# Crear el archivo de debug
echo "Debug Log" > "$debug_file"
echo "----------" >> "$debug_file"

# Función para extraer datos de un archivo FastQC
extract_fastqc_data() {
    local zip_file=$1
    echo "Processing file: $zip_file" >> "$debug_file"
    
    if [ ! -f "$zip_file" ]; then
        echo "File $zip_file does not exist" >> "$debug_file"
        return 1
    fi
    
    local fastqc_data=$(unzip -p "$zip_file" "*/fastqc_data.txt")
    if [ -z "$fastqc_data" ]; then
        echo "Could not extract data from $zip_file" >> "$debug_file"
        return 1
    fi
    
    local gc_content=$(echo "$fastqc_data" | awk -F'\t' '/^%GC/ {print $2}')
    local quality_scores=$(echo "$fastqc_data" | awk -F'\t' '/^>>Per base sequence quality/,/^>>END_MODULE/ {if (NR > 3 && $1 !~ /^#/) print $2}')
    local mean_quality=$(echo "$quality_scores" | awk '{sum+=$1} END {print sum/NR}')
    
    printf "%.2f %.2f" "$gc_content" "$mean_quality"
}

# Procesar los archivos FastQC
declare -A short_gc
declare -A short_qual
declare -A long_gc
declare -A long_qual
declare -A samples

# Encontrar todas las carpetas de muestras
for sample_dir in "$fastqc_dir"/*_trimmed/; do
    if [ -d "$sample_dir" ]; then
        sample=$(basename "$sample_dir" | sed 's/_trimmed$//')
        samples["$sample"]=1
        echo "Processing sample directory: $sample_dir" >> "$debug_file"
        
        # Procesar short reads si existen
        if ls "$sample_dir"/*R1_paired_trimmed_fastqc.zip >/dev/null 2>&1; then
            r1_data=$(extract_fastqc_data "$sample_dir"/*R1_paired_trimmed_fastqc.zip)
            r2_data=$(extract_fastqc_data "$sample_dir"/*R2_paired_trimmed_fastqc.zip)
            
            if [ $? -eq 0 ]; then
                read r1_gc r1_qual <<< "$r1_data"
                read r2_gc r2_qual <<< "$r2_data"
                
                # Calcular promedios
                short_gc["$sample"]=$(awk "BEGIN {printf \"%.2f\", ($r1_gc + $r2_gc) / 2}")
                short_qual["$sample"]=$(awk "BEGIN {printf \"%.2f\", ($r1_qual + $r2_qual) / 2}")
                echo "Short read metrics for $sample - GC: ${short_gc[$sample]}, Quality: ${short_qual[$sample]}" >> "$debug_file"
            fi
        fi
        
        # Procesar long reads si existen
        if ls "$sample_dir"/*long_trimmed_fastqc.zip >/dev/null 2>&1; then
            long_data=$(extract_fastqc_data "$sample_dir"/*long_trimmed_fastqc.zip)
            
            if [ $? -eq 0 ]; then
                read long_gc["$sample"] long_qual["$sample"] <<< "$long_data"
                echo "Long read metrics for $sample - GC: ${long_gc[$sample]}, Quality: ${long_qual[$sample]}" >> "$debug_file"
            fi
        fi
    fi
done

# Escribir el encabezado del archivo de salida en formato tabular
printf "Sample\tShort Read GC%%\tShort Read Quality\tLong Read GC%%\tLong Read Quality\n" > "$output_file"

# Escribir los resultados en formato tabular, ordenados por nombre de muestra
for sample in $(printf "%s\n" "${!samples[@]}" | sort); do
    short_gc_val="N/A"
    short_qual_val="N/A"
    long_gc_val="N/A"
    long_qual_val="N/A"
    
    # Obtener valores de short reads si existen
    if [ -n "${short_gc[$sample]:-}" ]; then
        short_gc_val="${short_gc[$sample]}"
        short_qual_val="${short_qual[$sample]}"
    fi
    
    # Obtener valores de long reads si existen
    if [ -n "${long_gc[$sample]:-}" ]; then
        long_gc_val="${long_gc[$sample]}"
        long_qual_val="${long_qual[$sample]}"
    fi
    
    printf "%s\t%s\t%s\t%s\t%s\n" \
        "$sample" "$short_gc_val" "$short_qual_val" "$long_gc_val" "$long_qual_val" >> "$output_file"
done

echo "Report generated in: $output_file"
echo "Debug log generated in: $debug_file"