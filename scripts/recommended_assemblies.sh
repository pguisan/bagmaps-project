#!/bin/bash

compare_float() {
    awk -v n1="$1" -v n2="$3" "BEGIN {exit !(n1 $2 n2)}"
    return $?
}

recommend_assembly() {
    local short_qual="$1"
    local short_cov="$2"
    local long_qual="$3"
    local long_cov="$4"
    local total_cov="$5"

    # Solo long reads
    if [ "$short_cov" = "NA" ] || [ "$short_cov" = "0" ]; then
        if compare_float "$long_cov" ">=" "50"; then
            echo "dragonflye --assembler flye --opts '--iterations 1'"
        elif compare_float "$long_cov" ">=" "30"; then
            echo "dragonflye --assembler flye --min-readlen 3000"
        else
            echo "dragonflye --assembler flye --opts '--iterations 2 --min-readlen 2000'"
        fi

    # Solo short reads  
    elif [ "$long_cov" = "NA" ] || [ "$long_cov" = "0" ]; then
        if compare_float "$short_cov" ">=" "70" && compare_float "$short_qual" ">=" "30"; then
            echo "unicycler_short_bold"
        else
            echo "unicycler_short_normal"
        fi

    # Hybrid
    else
        # Primero verificar alta cobertura de long reads
        if compare_float "$long_cov" ">=" "50"; then
            echo "dragonflye --assembler flye --polypolish 1"
        else
            # Calculate ratio between coverages
            ratio=$(awk -v short="$short_cov" -v long="$long_cov" 'BEGIN {printf "%.4f", short/long}')

            if compare_float "$ratio" ">" "2"; then
                # Dominan short reads
                if compare_float "$short_qual" ">=" "30" && compare_float "$total_cov" ">=" "50"; then
                    echo "unicycler_hybrid_bold"
                else
                    echo "unicycler_hybrid_normal" 
                fi
            elif compare_float "$ratio" "<" "0.5"; then
                # Dominan long reads
                if compare_float "$long_qual" ">=" "15"; then
                    echo "dragonflye --assembler flye --polypolish 2"
                else
                    echo "dragonflye --assembler flye --polypolish 1"
                fi
            else
                # Balance entre tipos
                if compare_float "$total_cov" ">=" "50" && compare_float "$short_qual" ">=" "30"; then
                    echo "unicycler_hybrid_bold"
                else
                    echo "unicycler_hybrid_normal"
                fi
            fi
        fi
    fi
}

REPORT_DIR="../reports"
INPUT_FILE="$REPORT_DIR/combined_report.txt"
OUTPUT_FILE="$REPORT_DIR/combined_report_with_recommendations.txt"

# Crear encabezado
echo -e "Sample\tShort Quality\tShort Coverage\tLong Quality\tLong Coverage\tTotal Coverage\tRecommended Assembly" > "$OUTPUT_FILE"

# Procesar cada línea y generar recomendaciones
while IFS=$'\t' read -r sample short_qual long_qual short_cov long_cov total_cov gc_short gc_long; do
    # Saltar la línea del encabezado
    if [ "$sample" = "Sample" ]; then
        continue
    fi
    
    # Convertir "N/A" a "0" para el procesamiento
    short_qual=${short_qual/N\/A/0}
    short_cov=${short_cov/N\/A/0}
    long_qual=${long_qual/N\/A/0}
    long_cov=${long_cov/N\/A/0}
    total_cov=${total_cov/N\/A/0}
    
    # Obtener recomendación
    recommendation=$(recommend_assembly "$short_qual" "$short_cov" "$long_qual" "$long_cov" "$total_cov")
    
    # Restaurar "N/A" para la salida
    [ "$short_qual" = "0" ] && short_qual="N/A"
    [ "$short_cov" = "0" ] && short_cov="N/A"
    [ "$long_qual" = "0" ] && long_qual="N/A"
    [ "$long_cov" = "0" ] && long_cov="N/A"
    [ "$total_cov" = "0" ] && total_cov="N/A"
    
    # Escribir al archivo de salida
    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$sample" "$short_qual" "$short_cov" "$long_qual" "$long_cov" "$total_cov" "$recommendation" >> "$OUTPUT_FILE"
done < "$INPUT_FILE"

echo "Process completed. Check $OUTPUT_FILE for recommendations."