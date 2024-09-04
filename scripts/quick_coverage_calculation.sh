#!/bin/bash

set -e  # Detiene el script si ocurre algún error

# Definir los parámetros
trimmed_dir="../data/trimmed"
output_dir="../reports"
genome_size=4000000  # Tamaño aproximado del genoma en pares de bases

# Función para verificar y crear el directorio de salida
check_and_create_output_dir() {
    if [ ! -d "$output_dir" ]; then
        echo "El directorio de salida no existe. Intentando crear $output_dir"
        if ! mkdir -p "$output_dir" 2>/dev/null; then
            echo "No se pudo crear $output_dir. Usando el directorio actual."
            output_dir="."
        fi
    elif [ ! -w "$output_dir" ]; then
        echo "No se tienen permisos de escritura en $output_dir. Usando el directorio actual."
        output_dir="."
    fi
    echo "Los resultados se guardarán en: $output_dir"
}

# Llamar a la función para verificar y crear el directorio de salida
check_and_create_output_dir

# Función para calcular el coverage
calculate_coverage() {
    local sample=$1
    local sample_dir="$trimmed_dir/${sample}"
    local forward_reads=$(ls $sample_dir/*R1_paired_trimmed.fastq.gz 2>/dev/null || ls $sample_dir/*_1.fastq.gz 2>/dev/null || echo "")
    local reverse_reads=$(ls $sample_dir/*R2_paired_trimmed.fastq.gz 2>/dev/null || ls $sample_dir/*_2.fastq.gz 2>/dev/null || echo "")
    local long_reads=$(ls $sample_dir/*long_trimmed.fastq.gz 2>/dev/null || ls $sample_dir/*long*.fastq.gz 2>/dev/null || echo "")

    local short_read_bases=0
    local short_read_count=0
    local long_read_bases=0
    local long_read_count=0
    local avg_short_read_length=0
    local avg_long_read_length=0

    # Calcular estadísticas para short reads
    if [ -n "$forward_reads" ] && [ -n "$reverse_reads" ]; then
        local short_read_stats=$(zcat "$forward_reads" | awk '
            NR%4==1 {count++}
            NR%4==2 {bases += length($0); total_length += length($0)}
            END {printf "%.0f %.0f %.3f", bases, count, (count > 0 ? total_length/count : 0)}
        ')
        short_read_bases=$(echo $short_read_stats | cut -d' ' -f1)
        short_read_count=$(echo $short_read_stats | cut -d' ' -f2)
        avg_short_read_length=$(echo $short_read_stats | cut -d' ' -f3)
        short_read_bases=$((2 * short_read_bases))  # Multiplicar por 2 para contar ambos extremos
        short_read_count=$((2 * short_read_count))  # Contar ambos extremos
    fi

    # Calcular estadísticas para long reads
    if [ -n "$long_reads" ]; then
        local long_read_stats=$(zcat "$long_reads" | awk '
            NR%4==1 {count++}
            NR%4==2 {bases += length($0); total_length += length($0)}
            END {printf "%.0f %.0f %.3f", bases, count, (count > 0 ? total_length/count : 0)}
        ')
        long_read_bases=$(echo $long_read_stats | cut -d' ' -f1)
        long_read_count=$(echo $long_read_stats | cut -d' ' -f2)
        avg_long_read_length=$(echo $long_read_stats | cut -d' ' -f3)
    fi

    # Calcular coverage
    local short_read_coverage=$(echo "scale=2; $short_read_bases / $genome_size" | bc)
    local long_read_coverage=$(echo "scale=2; $long_read_bases / $genome_size" | bc)
    local total_coverage=$(echo "scale=2; ($short_read_bases + $long_read_bases) / $genome_size" | bc)

    # Asegurarse de que al menos un tipo de read existe
    if [ "$short_read_count" -eq 0 ] && [ "$long_read_count" -eq 0 ]; then
        echo "Advertencia: No se encontraron reads para la muestra $sample" >&2
        return
    fi

    # Manejar casos donde solo hay long reads
    if [ "$short_read_count" -eq 0 ]; then
        short_read_coverage="0.00"
        avg_short_read_length="0.000"
    fi

    # Manejar casos donde solo hay short reads
    if [ "$long_read_count" -eq 0 ]; then
        long_read_coverage="0.00"
        avg_long_read_length="0.000"
    fi

    printf "%s\t%.2f\t%.2f\t%.2f\t%d\t%.3f\t%d\t%.3f\n" \
        "$sample" "$short_read_coverage" "$long_read_coverage" "$total_coverage" \
        "$short_read_count" "$avg_short_read_length" "$long_read_count" "$avg_long_read_length"
}

# Inicializar el archivo de salida
output_file="$output_dir/comprehensive_coverage_report.txt"
if ! touch "$output_file" 2>/dev/null; then
    echo "No se puede escribir en $output_file. Usando comprehensive_coverage_report.txt en el directorio actual."
    output_file="./comprehensive_coverage_report.txt"
fi

# Escribir el encabezado con formato tabular
printf "Muestra\tCoverage (Short Reads)\tCoverage (Long Reads)\tCoverage Total\tNúmero de Short Reads\tLongitud Media Short Reads\tNúmero de Long Reads\tLongitud Media Long Reads\n" > "$output_file"

# Contar el número total de muestras
total_samples=$(find "$trimmed_dir" -maxdepth 1 -type d | wc -l)
current_sample=0

# Procesar cada muestra
for sample_dir in "$trimmed_dir"/*; do
    if [ -d "$sample_dir" ]; then
        sample=$(basename "$sample_dir")
        current_sample=$((current_sample + 1))
        
        # Mostrar progreso
        echo -ne "Procesando muestra $current_sample de $total_samples: $sample\r"
        
        calculate_coverage "$sample" >> "$output_file"
    fi
done

echo -e "\nCálculo de coverage completado. Resultados en $output_file"

# Mostrar las primeras líneas del archivo de salida
echo "Primeras líneas del informe:"
head -n 5 "$output_file"