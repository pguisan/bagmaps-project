#!/bin/bash

set -euo pipefail

# Definir la ruta a la carpeta de reportes
REPORTS_DIR="../reports"
OUTPUT_FILE="${REPORTS_DIR}/combined_report.txt"
DEBUG_FILE="${REPORTS_DIR}/debug_output.txt"

# Función para obtener las calidades de una muestra
get_qualities() {
    local sample=$1
    awk -v sample="$sample" '
    $1 == sample {
        if ($2 == "short_R1") short_qual_r1 = $6
        else if ($2 == "short_R2") short_qual_r2 = $6
        else if ($2 == "long") long_qual = $6
    }
    END {
        if (short_qual_r1 && short_qual_r2)
            print "short", (short_qual_r1 + short_qual_r2) / 2
        else if (long_qual)
            print "long", long_qual
        else
            print "none", "N/A"
    }
    ' "$REPORTS_DIR/sequencing_quality_report.txt"
}

# Función para obtener la cobertura de una muestra
get_coverage() {
    local sample=$1
    awk -v sample="$sample" '
        $1 == sample"_trimmed" {
            print $2, $3, $4
            exit
        }
    ' "$REPORTS_DIR/comprehensive_coverage_report.txt"
}

# Imprimir encabezado al archivo de salida
printf "%-20s %-15s %-15s %-15s %-15s %-15s\n" "Muestra" "Calidad(short)" "Calidad(long)" "Coverage(short)" "Coverage(long)" "Coverage(comb)" > "$OUTPUT_FILE"

# Limpiar el archivo de depuración
> "$DEBUG_FILE"

# Obtener todas las muestras únicas
samples=$(awk '{print $1}' "$REPORTS_DIR/sequencing_quality_report.txt" | sort -u)

# Procesar cada muestra y escribir al archivo de salida
for sample in $samples; do
    echo "Procesando muestra: $sample" >> "$DEBUG_FILE"
    
    qualities=$(get_qualities "$sample")
    echo "Calidades obtenidas: $qualities" >> "$DEBUG_FILE"
    read qual_type qual_value <<< "$qualities"
    
    coverage=$(get_coverage "$sample")
    echo "Coberturas obtenidas: $coverage" >> "$DEBUG_FILE"
    read cov_short cov_long cov_comb <<< "$coverage"
    
    # Manejar casos donde no hay datos
    qual_short="N/A"
    qual_long="N/A"
    if [ "$qual_type" = "short" ]; then
        qual_short="$qual_value"
    elif [ "$qual_type" = "long" ]; then
        qual_long="$qual_value"
    fi
    
    [ "$cov_short" = "0.00" ] && cov_short="N/A"
    [ "$cov_long" = "0.00" ] && cov_long="N/A"
    [ -z "$cov_short" ] && cov_short="N/A"
    [ -z "$cov_long" ] && cov_long="N/A"
    [ -z "$cov_comb" ] && cov_comb="N/A"
    
    echo "Valores finales:" >> "$DEBUG_FILE"
    echo "  Muestra: $sample" >> "$DEBUG_FILE"
    echo "  Calidad(short): $qual_short" >> "$DEBUG_FILE"
    echo "  Calidad(long): $qual_long" >> "$DEBUG_FILE"
    echo "  Coverage(short): $cov_short" >> "$DEBUG_FILE"
    echo "  Coverage(long): $cov_long" >> "$DEBUG_FILE"
    echo "  Coverage(comb): $cov_comb" >> "$DEBUG_FILE"
    echo "" >> "$DEBUG_FILE"
    
    printf "%-20s %-15s %-15s %-15s %-15s %-15s\n" "$sample" "$qual_short" "$qual_long" "$cov_short" "$cov_long" "$cov_comb" >> "$OUTPUT_FILE"
done

echo "El reporte combinado se ha guardado en $OUTPUT_FILE"
echo "La información de depuración se ha guardado en $DEBUG_FILE"