#!/bin/bash

set -e

# Configuración base
RESULTS_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"
MAMBA_PATH="/home/paula/conda/bin/mamba"
FASTANI_ENV="fastani_env"

# Obtener la fecha actual en formato DD_MM_YY
CURRENT_DATE=$(date +"%d_%m_%y")

# Verificar el directorio de ensamblaje de hoy
TODAY_ASSEMBLY_DIR="${RESULTS_DIR}/assembly_${CURRENT_DATE}"

if [ -d "$TODAY_ASSEMBLY_DIR" ]; then
    USER_ASSEMBLY_DIR="$TODAY_ASSEMBLY_DIR"
    echo "Se encontró el directorio de ensamblaje de hoy: $(basename "$USER_ASSEMBLY_DIR")"
else
    echo "No se encontró un directorio de ensamblaje para la fecha de hoy."
    echo "Buscando otros directorios de assembly..."
    
    # Encontrar todas las carpetas de assembly y almacenarlas
    assembly_dirs=()
    while IFS= read -r -d '' dir; do
        assembly_dirs+=("$dir")
    done < <(find "$RESULTS_DIR" -maxdepth 1 -type d -name "assembly_*" -print0 | sort -z)

    # Si no se encontraron carpetas
    if [ ${#assembly_dirs[@]} -eq 0 ]; then
        echo "No se encontraron carpetas de assembly en $RESULTS_DIR"
        exit 1
    fi

    # Selección de la carpeta
    if [ ${#assembly_dirs[@]} -eq 1 ]; then
        # Si solo hay una carpeta, usarla automáticamente
        USER_ASSEMBLY_DIR="${assembly_dirs[0]}"
        echo "Única carpeta de assembly encontrada, usando: $(basename "$USER_ASSEMBLY_DIR")"
    else
        # Si hay más de una carpeta, mostrar opciones
        echo "Carpetas de assembly disponibles:"
        for i in "${!assembly_dirs[@]}"; do
            echo "$((i+1))) $(basename "${assembly_dirs[$i]}")"
        done
        
        echo
        echo "Por favor, seleccione el número de la carpeta de assembly (1-${#assembly_dirs[@]}):"
        read -r selection
        
        # Validar la selección
        if ! [[ "$selection" =~ ^[0-9]+$ ]] || [ "$selection" -lt 1 ] || [ "$selection" -gt ${#assembly_dirs[@]} ]; then
            echo "Selección inválida: $selection"
            exit 1
        fi
        
        USER_ASSEMBLY_DIR="${assembly_dirs[$((selection-1))]}"
        echo "Seleccionada: $(basename "$USER_ASSEMBLY_DIR")"
    fi
fi

# Crear directorio para resultados de ANI
ANI_DIR="${USER_ASSEMBLY_DIR}/ani_results"
mkdir -p "$ANI_DIR"

# Crear listas de genomas
echo "Creando listas de genomas para FastANI..."
find "$USER_ASSEMBLY_DIR" -name "*_assembly.fasta" > "${ANI_DIR}/user_assembly_list.txt"
REF_GENOME_LIST="${RESULTS_DIR}/reference_genome_list.txt"

# Verificar que existan los archivos necesarios
if [ ! -f "$REF_GENOME_LIST" ]; then
    echo "Error: No se encuentra la lista de genomas de referencia. ¿Se ejecutó el script de descarga?"
    exit 1
fi

if [ ! -s "${ANI_DIR}/user_assembly_list.txt" ]; then
    echo "Error: No se encontraron ensamblajes en el directorio seleccionado"
    exit 1
fi

echo "Número de ensamblajes encontrados: $(wc -l < ${ANI_DIR}/user_assembly_list.txt)"
echo "Número de genomas de referencia: $(wc -l < $REF_GENOME_LIST)"

# Ejecutar FastANI
echo "Ejecutando FastANI..."
$MAMBA_PATH run -n $FASTANI_ENV fastANI \
    --ql "${ANI_DIR}/user_assembly_list.txt" \
    --rl "$REF_GENOME_LIST" \
    -o "${ANI_DIR}/fastani_results.txt" \
    --threads 8

# Generar reporte
echo "Generando reporte con las tres mejores coincidencias..."
{
    echo -e "User_Assembly\tReference_Genome_1\tANI_1\tSpecies_1\tReference_Genome_2\tANI_2\tSpecies_2\tReference_Genome_3\tANI_3\tSpecies_3"
    awk -v metadata_file="${RESULTS_DIR}/genome_metadata_map.tsv" '
    BEGIN {
        FS=OFS="\t"
        while ((getline < metadata_file) > 0) {
            split($0, a, "\t")
            metadata[a[1]] = a[3]  # Guardar especie para cada genoma
        }
    }
    {
        split($1, a, "/")
        split($2, b, "/")
        user = a[length(a)]
        ref = b[length(b)]
        ani = sprintf("%.2f", $3)
        
        if (!(user in results)) {
            count[user] = 0
            results[user] = ""
        }
        
        if (count[user] < 3) {
            if (count[user] > 0) results[user] = results[user] OFS
            species = (ref in metadata) ? metadata[ref] : "Unknown"
            results[user] = results[user] ref OFS ani OFS species
            count[user]++
        }
    }
    END {
        for (user in results) {
            printf "%s\t%s", user, results[user]
            for (i = count[user]; i < 3; i++) {
                printf "\tNA\tNA\tNA"
            }
            printf "\n"
        }
    }' "${ANI_DIR}/fastani_results.txt" | sort
} > "${ANI_DIR}/ani_report.tsv"

echo "Análisis completado. Los resultados se encuentran en:"
echo "  - Reporte ANI: ${ANI_DIR}/ani_report.tsv"
echo "  - Resultados completos: ${ANI_DIR}/fastani_results.txt"

# Mostrar las primeras líneas del reporte
echo -e "\nPrimeras líneas del reporte:"
head -n 5 "${ANI_DIR}/ani_report.tsv"