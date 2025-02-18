#!/bin/bash

set -euo pipefail

# Definir la ruta a la carpeta de reportes
REPORTS_DIR="../reports"
OUTPUT_FILE="${REPORTS_DIR}/combined_report.txt"
DEBUG_FILE="${REPORTS_DIR}/debug_output.txt"

# Crear encabezado del reporte combinado
printf "Sample\tShort Qual\tLong Qual\tShort Cov\tLong Cov\tTotal Cov\tShort GC%%\tLong GC%%\n" > "$OUTPUT_FILE"

# Inicializar archivo de debug
echo "Debug Log" > "$DEBUG_FILE"
echo "---------" >> "$DEBUG_FILE"

# Leer datos de calidad y coverage en arrays asociativos
declare -A quality_data
declare -A coverage_data

# Procesar archivo de quality
echo "Processing quality report..." >> "$DEBUG_FILE"
while IFS=$'\t' read -r sample short_gc short_qual long_gc long_qual; do
    # Saltar el encabezado
    if [ "$sample" = "Sample" ]; then continue; fi
    quality_data["$sample"]="$short_gc|$short_qual|$long_gc|$long_qual"
    echo "Quality data for $sample: ${quality_data[$sample]}" >> "$DEBUG_FILE"
done < "$REPORTS_DIR/sequencing_quality_report.txt"

# Procesar archivo de coverage
echo -e "\nProcessing coverage report..." >> "$DEBUG_FILE"
while IFS=$'\t' read -r sample short_cov long_cov total_cov rest; do
    # Saltar el encabezado
    if [ "$sample" = "Sample" ]; then continue; fi
    # Eliminar el sufijo _trimmed del nombre de la muestra
    clean_sample=$(echo "$sample" | sed 's/_trimmed$//')
    coverage_data["$clean_sample"]="$short_cov|$long_cov|$total_cov"
    echo "Coverage data for $clean_sample: ${coverage_data[$clean_sample]}" >> "$DEBUG_FILE"
done < "$REPORTS_DIR/comprehensive_coverage_report.txt"

# Combinar datos para cada muestra
echo -e "\nCombining reports..." >> "$DEBUG_FILE"

# Obtener lista única de muestras
samples=$(printf "%s\n" "${!quality_data[@]}" "${!coverage_data[@]}" | sort -u)

for sample in $samples; do
    echo "Processing sample: $sample" >> "$DEBUG_FILE"
    
    # Obtener datos de calidad
    short_gc="N/A"
    short_qual="N/A"
    long_gc="N/A"
    long_qual="N/A"
    if [ -n "${quality_data[$sample]:-}" ]; then
        IFS='|' read -r short_gc short_qual long_gc long_qual <<< "${quality_data[$sample]}"
    fi
    
    # Obtener datos de coverage
    short_cov="N/A"
    long_cov="N/A"
    total_cov="N/A"
    if [ -n "${coverage_data[$sample]:-}" ]; then
        IFS='|' read -r short_cov long_cov total_cov <<< "${coverage_data[$sample]}"
    fi
    
    # Convertir 0.00 a N/A en coverage
    [ "$short_cov" = "0.00" ] && short_cov="N/A"
    [ "$long_cov" = "0.00" ] && long_cov="N/A"
    
    # Escribir línea en el reporte
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$sample" "$short_qual" "$long_qual" "$short_cov" "$long_cov" "$total_cov" "$short_gc" "$long_gc" \
        >> "$OUTPUT_FILE"
    
    # Debug output
    echo "Written data for $sample:" >> "$DEBUG_FILE"
    echo "  Quality: short=$short_qual, long=$long_qual" >> "$DEBUG_FILE"
    echo "  Coverage: short=$short_cov, long=$long_cov, total=$total_cov" >> "$DEBUG_FILE"
    echo "  GC%: short=$short_gc, long=$long_gc" >> "$DEBUG_FILE"
    echo "" >> "$DEBUG_FILE"
done

echo "Combined report has been saved to $OUTPUT_FILE"
echo "Debug information has been saved to $DEBUG_FILE"