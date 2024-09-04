#!/bin/bash

set -e

# Directorio base para los resultados
BASE_DIR="/mnt/d/PC/Descargas/Pipeline_acinetobacter/results"

# Directorio para los genomas de referencia
REF_DIR="${BASE_DIR}/reference_genomes"
mkdir -p "$REF_DIR"

# Ruta completa a mamba
MAMBA_PATH="/home/paula/conda/bin/mamba"

# NCBI Taxonomy ID para Acinetobacter
ACINETOBACTER_TAXID=469

# Obtener y procesar genomas de referencia de Acinetobacter
echo "Obteniendo genomas de referencia de Acinetobacter..."
$MAMBA_PATH run -n fastani_env datasets download genome taxon $ACINETOBACTER_TAXID \
    --reference --filename "${BASE_DIR}/acinetobacter_genomes.zip" \
    --include genome,seq-report

echo "Descomprimiendo y procesando genomas..."
unzip -o "${BASE_DIR}/acinetobacter_genomes.zip" -d "${REF_DIR}/temp"
find "${REF_DIR}/temp/ncbi_dataset/data" -name "*.fna" -exec mv {} "${REF_DIR}/" \;

# Generar metadatos basados en los encabezados de los archivos .fna
echo "Generando metadatos basados en los encabezados de los archivos .fna."
find "$REF_DIR" -name "*.fna" | while read -r file; do
    header=$(grep -m 1 "^>" "$file")
    filename=$(basename "$file")
    accession=$(echo "$filename" | cut -d '_' -f 1,2)
    species=$(echo "$header" | sed 's/^>[^ ]* //' | cut -d ',' -f 1)
    echo -e "${filename}\t${accession}\t${species}" >> "${BASE_DIR}/genome_metadata_map.tsv"
done

echo "Contenido final de genome_metadata_map.tsv (primeras 5 líneas):"
head -n 5 "${BASE_DIR}/genome_metadata_map.tsv"

# Crear una lista de genomas de referencia para FastANI
find "$REF_DIR" -name "*.fna" > "$BASE_DIR/reference_genome_list.txt"

echo "Extracción de genomas de referencia completada."