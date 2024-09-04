#!/bin/bash

# Directorio de informes
REPORT_DIR="../reports"

# Archivo de entrada
INPUT_FILE="$REPORT_DIR/combined_report.txt"

# Archivo de salida
OUTPUT_FILE="$REPORT_DIR/combined_report_with_recommendations.txt"

# Función para verificar si un valor es numérico
is_numeric() {
    case "$1" in
        ''|*[!0-9.]*) return 1 ;;
        *) return 0 ;;
    esac
}

# Función para recomendar el ensamblaje
recommend_assembly() {
    local short_qual=$1
    local long_qual=$2
    local short_cov=$3
    local long_cov=$4
    local comb_cov=$5

    if ! is_numeric "$short_qual"; then short_qual=0; fi
    if ! is_numeric "$long_qual"; then long_qual=0; fi
    if ! is_numeric "$short_cov"; then short_cov=0; fi
    if ! is_numeric "$long_cov"; then long_cov=0; fi
    if ! is_numeric "$comb_cov"; then comb_cov=0; fi

    if [ "$long_cov" = "0" ] && [ "$short_cov" != "0" ]; then
        if (( $(echo "$short_cov >= 100" | bc -l) )); then
            echo "unicycler_short_bold_cov"
        elif (( $(echo "$short_cov > 30" | bc -l) )); then
            echo "unicycler_short_normal"
        elif (( $(echo "$short_cov >= 20" | bc -l) )) && (( $(echo "$short_qual >= 30" | bc -l) )); then
            echo "unicycler_short_normal"
        else
            echo "unicycler_short_conservative"
        fi
    elif [ "$short_cov" = "0" ] && [ "$long_cov" != "0" ]; then
        if (( $(echo "$long_cov >= 100" | bc -l) )); then
            echo "dragonflye_long_only_high_cov"
        elif (( $(echo "$long_qual >= 15" | bc -l) )); then
            echo "dragonflye_long_only_normal"
        else
            echo "dragonflye_long_only_conservative"
        fi
    elif [ "$short_cov" != "0" ] && [ "$long_cov" != "0" ]; then
        local short_long_ratio
        if (( $(echo "$long_cov > 0" | bc -l) )); then
            short_long_ratio=$(echo "$short_cov / $long_cov" | bc -l)
        else
            short_long_ratio=0
        fi
        if (( $(echo "$comb_cov >= 100" | bc -l) )) && (( $(echo "$short_qual >= 30" | bc -l) )) && (( $(echo "$long_qual >= 20" | bc -l) )); then
            echo "unicycler_hybrid_bold_cov"
        elif (( $(echo "$long_cov >= 50" | bc -l) )); then
            echo "dragonflye_polish_high_cov"
        elif (( $(echo "$long_cov >= 30" | bc -l) )); then
            echo "dragonflye_polish"
        elif (( $(echo "$comb_cov >= 50" | bc -l) )); then
            echo "unicycler_hybrid_bold_cov"
        elif (( $(echo "$comb_cov > 20" | bc -l) )); then
            if (( $(echo "$short_long_ratio > 2" | bc -l) )); then
                echo "unicycler_hybrid_normal_short_biased"
            elif (( $(echo "$short_long_ratio < 0.5" | bc -l) )); then
                echo "unicycler_hybrid_normal_long_biased"
            else
                echo "unicycler_hybrid_normal"
            fi
        else
            echo "unicycler_hybrid_conservative"
        fi
    else
        echo "insufficient_coverage"
    fi
}

# Verificar si el archivo de entrada existe
if [ ! -f "$INPUT_FILE" ]; then
    echo "Error: El archivo de entrada $INPUT_FILE no existe."
    exit 1
fi

# Leer el encabezado y escribirlo en el archivo de salida
head -n 1 "$INPUT_FILE" | awk '{print $0 "\tRecommended Assembly"}' > "$OUTPUT_FILE"

# Procesar cada línea del archivo de entrada
tail -n +2 "$INPUT_FILE" | while read -r line
do
    # Extraer los valores de cada columna
    sample=$(echo "$line" | awk '{print $1}')
    short_qual=$(echo "$line" | awk '{print $2}')
    long_qual=$(echo "$line" | awk '{print $3}')
    short_cov=$(echo "$line" | awk '{print $4}')
    long_cov=$(echo "$line" | awk '{print $5}')
    comb_cov=$(echo "$line" | awk '{print $6}')

    # Obtener la recomendación
    recommendation=$(recommend_assembly "$short_qual" "$long_qual" "$short_cov" "$long_cov" "$comb_cov")

    # Escribir la línea original más la recomendación en el archivo de salida, asegurando la tabulación
    printf "%-15s %-15s %-15s %-15s %-15s %-15s %-35s\n" "$sample" "$short_qual" "$long_qual" "$short_cov" "$long_cov" "$comb_cov" "$recommendation" >> "$OUTPUT_FILE"
done

echo "Proceso completado. Revisa $OUTPUT_FILE para ver las recomendaciones."