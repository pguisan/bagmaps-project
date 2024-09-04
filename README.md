# bagmaps
**B**ioinformatics **A**pplied to **G**enomic **M**apping of **A**ntibiotic resistant bacterial **P**athogens, active **S**urveillance and national studies

PhD candidate: Paula Guijarro-Sánchez. Xunta de Galicia Predoctoral Student Grant – IN606A- 2021/021

## Supervisors:

- Dr. Alejandro Beceiro Casas (SERGAS)
- Dr. Carlos Fernandez-Lozano (UDC)

# 🧬 Pipeline de Análisis Genómico para Acinetobacter

Pipeline completo y semi-automático para el análisis genómico de especies de Acinetobacter, procesando lecturas cortas (Illumina) y largas (Nanopore).

## 📋 Tabla de Contenidos

- [Características Principales](#características-principales)
- [Estructura del Repositorio](#estructura-del-repositorio)
- [Requisitos](#requisitos)
- [Uso](#uso)
- [Personalización](#personalización)
- [Contribuciones](#contribuciones)

## ✨ Características Principales 

- 🧹 Preprocesamiento de lecturas (Trimmomatic, Porechop)
- 🔍 Evaluación de calidad (FastQC)
- 📊 Cálculo de cobertura genómica
- 🧩 Ensamblaje de genomas (Unicycler, Dragonflye)
- 📈 Evaluación de ensamblajes (QUAST, CheckM2)
- 🔬 Análisis de similitud genómica (FastANI)
- 📝 Anotación genómica (Bakta)
- 💊 Análisis de resistencia antimicrobiana (ResFinder, CARD-RGI)
- 📄 Generación de informes detallados

## 🗂 Estructura del Repositorio 
```
bagmaps/
├── scripts/
│   └── pipeline.sh
├── results/
└── data/
```

El repositorio está organizado en tres carpetas principales:

- `scripts/`: Contiene todos los scripts del pipeline, incluyendo el script principal `pipeline.sh`
- `results/`: Almacena los resultados generados por el pipeline
- `data/`: Directorio para los datos de entrada (no incluido en el repositorio)

## 🛠 Requisitos
- Bash
- Mamba/Conda
- Herramientas bioinformáticas: FastQC, Trimmomatic, Porechop, Unicycler, Dragonflye, QUAST, CheckM2, FastANI, Bakta, ResFinder, CARD-RGI
- Bases de datos actualizadas para Bakta, ResFinder y CARD

## 🚀 Uso

1. Clonar el repositorio:
```bash
git clone https://github.com/MALL-Machine-Learning-in-Live-Sciences/bagmaps.git
```

2. Coloque sus datos de secuenciación en la carpeta `data/input/`

3. Asegúrese de que todas las dependencias y bases de datos estén correctamente instaladas y configuradas

4. Ejecute el script principal para un análisis completo:

```
bash scripts/pipeline.sh
```


Alternativamente, puede ejecutar scripts individuales para análisis específicos, por ejemplo:
  ```
  bash scripts/preprocess.sh
  bash scripts/execute_assemblies.sh
  bash scripts/run_resistance_analysis.sh
  bash scripts/run_bakta_annotation.sh
  ```
  
5. Los resultados se almacenarán en la carpeta `results/` con subdirectorios para cada tipo de análisis

## ⚙️ Personalización
Revise los scripts individuales para ajustar parámetros específicos como tamaño del genoma, umbrales de calidad, etc.

## 👥 Contribuciones
¡Contribuciones son bienvenidas! Por favor, abra un issue para discutir cambios mayores.
