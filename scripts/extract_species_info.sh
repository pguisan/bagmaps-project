#!/bin/bash

set -e

# Configuración base
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"
REF_DIR="${BASE_DIR}/reference_genomes"
ACCEPTED_SPECIES_FILE="/mnt/d/PC/Descargas/Pipeline_acinetobacter/acinetobacter_accepted.txt"
MAMBA_PATH="/home/paula/conda/bin/mamba"
ACINETOBACTER_TAXID=469

# Crear directorios necesarios
mkdir -p "$REF_DIR"

# Verificar que existe el archivo de especies aceptadas
if [ ! -f "$ACCEPTED_SPECIES_FILE" ]; then
    echo "Error: No se encuentra el archivo de especies aceptadas en $ACCEPTED_SPECIES_FILE"
    exit 1
fi

# Descargar genomas
echo "Obteniendo genomas de referencia de Acinetobacter..."
$MAMBA_PATH run -n fastani_env datasets download genome taxon $ACINETOBACTER_TAXID \
    --reference --filename "${BASE_DIR}/acinetobacter_genomes.zip" \
    --include genome,seq-report

# Descomprimir
echo "Descomprimiendo genomas..."
unzip -o "${BASE_DIR}/acinetobacter_genomes.zip" -d "${REF_DIR}/temp"

# Inicializar archivo de metadata
echo -e "Filename\tAccession\tSpecies\tOriginal_Header" > "${BASE_DIR}/genome_metadata_map.tsv"

# Procesar y validar genomas
echo "Procesando y validando genomas..."
find "${REF_DIR}/temp/ncbi_dataset/data" -name "*.fna" | while read -r file; do
    header=$(head -n 1 "$file")
    filename=$(basename "$file")
    accession=$(echo "$header" | cut -d ' ' -f 1 | sed 's/>//')
    
    # Extraer exactamente las dos primeras palabras después del ID
    species=$(echo "$header" | awk '{print $2, $3}')
    
    echo "Procesando: $filename"
    echo "Header: $header"
    echo "Especie encontrada: $species"
    
    if grep -q "^$species$" "$ACCEPTED_SPECIES_FILE"; then
        echo "Especie válida: $species -> $accession"
        # Mover archivo al directorio final
        mv "$file" "${REF_DIR}/"
        # Guardar metadata
        echo -e "${filename}\t${accession}\t${species}\t${header}" >> "${BASE_DIR}/genome_metadata_map.tsv"
    else
        echo "Especie no válida: $species -> $accession (ignorando)"
    fi
done

# Limpiar archivos temporales
rm -rf "${REF_DIR}/temp"
rm -f "${BASE_DIR}/acinetobacter_genomes.zip"

# Crear lista de genomas validados para FastANI
find "$REF_DIR" -name "*.fna" > "$BASE_DIR/reference_genome_list.txt"

# Resumen final
total_genomas=$(wc -l < "${BASE_DIR}/genome_metadata_map.tsv")
echo -e "\nProceso completado:"
echo "Total de genomas válidos: $((total_genomas-1))"  # Restamos 1 por el encabezado
echo "Metadata guardada en: ${BASE_DIR}/genome_metadata_map.tsv"
echo "Lista de genomas para FastANI guardada en: ${BASE_DIR}/reference_genome_list.txt"

# Mostrar las primeras líneas del archivo de metadata
echo -e "\nPrimeras entradas del archivo de metadata:"
head -n 5 "${BASE_DIR}/genome_metadata_map.tsv"