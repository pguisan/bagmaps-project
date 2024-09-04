#!/bin/bash

set -e

# Directorio base para los resultados
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"

# Obtener la fecha actual en formato DD_MM_YY
CURRENT_DATE=$(date +"%d_%m_%y")

# Función para seleccionar el directorio de ensamblaje
select_assembly_dir() {
    echo "Directorios de ensamblaje disponibles:"
    local dirs=($(ls -d ${BASE_DIR}/assembly_* 2>/dev/null | sort -r))
    if [ ${#dirs[@]} -eq 0 ]; then
        echo "No se encontraron directorios de ensamblaje."
        exit 1
    fi
    for i in "${!dirs[@]}"; do
        echo "[$((i+1))] $(basename "${dirs[$i]}")"
    done
    
    while true; do
        read -p "Seleccione el número del directorio que desea usar (1-${#dirs[@]}): " selection
        if [[ "$selection" =~ ^[0-9]+$ ]] && [ "$selection" -ge 1 ] && [ "$selection" -le "${#dirs[@]}" ]; then
            echo "${dirs[$((selection-1))]}"
            return 0
        else
            echo "Selección inválida. Por favor, elija un número entre 1 y ${#dirs[@]}."
        fi
    done
}

# Buscar el directorio de ensamblaje de hoy
TODAY_ASSEMBLY_DIR="${BASE_DIR}/assembly_${CURRENT_DATE}"
if [ -d "$TODAY_ASSEMBLY_DIR" ]; then
    echo "Se encontró el directorio de ensamblaje de hoy: $TODAY_ASSEMBLY_DIR"
    USER_ASSEMBLY_DIR="$TODAY_ASSEMBLY_DIR"
else
    echo "No se encontró un directorio de ensamblaje para la fecha de hoy."
    USER_ASSEMBLY_DIR=$(select_assembly_dir)
fi

echo "Usando el directorio de ensamblaje: $USER_ASSEMBLY_DIR"

# Directorio para los resultados del ANI
ANI_DIR="${BASE_DIR}/ani_results_${CURRENT_DATE}"
mkdir -p "$ANI_DIR"

# Ruta completa a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"

# Verificar que FastANI está instalado
if ! $MAMBA_PATH run -n fastani_env fastANI --version &> /dev/null
then
    echo "FastANI no está instalado en el entorno fastani_env. Por favor, instálalo e intenta de nuevo."
    exit 1
fi

# Crear una lista de ensamblajes del usuario para FastANI
find "$USER_ASSEMBLY_DIR" -name "*.fasta" > "$ANI_DIR/user_assembly_list.txt"

# Realizar análisis ANI con FastANI 
echo "Realizando análisis ANI con FastANI..."
$MAMBA_PATH run -n fastani_env fastANI \
    --ql "$ANI_DIR/user_assembly_list.txt" \
    --rl "$BASE_DIR/reference_genome_list.txt" \
    -o "$ANI_DIR/fastani_results.txt" \
    -t 8

# Generar un reporte filtrado (ANI > 95%) con múltiples coincidencias en columnas adicionales
echo "Generando reporte filtrado (ANI > 95%) con múltiples coincidencias..."
awk 'BEGIN {FS=OFS="\t"}
NR==FNR {metadata[$1] = $3; next}
$3 > 95 {
    split($1, a, "/");
    split($2, b, "/");
    user = a[length(a)];
    ref = b[length(b)];
    if (!(user in results)) {
        results[user] = "";
        order[++count] = user;
    }
    results[user] = results[user] sprintf("%s\t%.2f\t%s\t%s\t", ref, $3, metadata[ref], ref);
}
END {
    print "Genome_User\tReference_Genome_1\tANI_1\tSpecies_1\tAccession_1\tReference_Genome_2\tANI_2\tSpecies_2\tAccession_2\tReference_Genome_3\tANI_3\tSpecies_3\tAccession_3";
    for (i=1; i<=count; i++) {
        user = order[i];
        printf "%s\t%s\n", user, results[user];
    }
}' "${BASE_DIR}/genome_metadata_map.tsv" "$ANI_DIR/fastani_results.txt" | \
sed 's/\t$//' > "$ANI_DIR/ani_report_filtered.tsv"

echo "Analysis completed. The filtered report is located at $ANI_DIR/ani_report_filtered.tsv"