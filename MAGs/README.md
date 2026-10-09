# MAGs

Examples use `/data` as the mounted data disk. Before running analysis commands:

```bash
source /data/kpark-pipelines/kpark.env
mkdir -p /data/projects/ProjectA
cd /data/projects/ProjectA
```

For DB, Docker, and Conda storage setup, see [installation notes](../INSTALL_KParkLab.md#data-disk-setup).

Modular MAG workflow collection for Uhlemann Lab metagenomics.

The modules are intentionally separated so QC, assembly/binning, inStrain, and annotation can be run independently.

## Layout

```text
MAGs/
  workflow/
    Go_MAGs_QC_V1.smk
    Go_MAGs_Assembly_V1.smk
    Go_MAGs_Annotation_V1.smk
  docker/
    Dockerfile.qc
    Dockerfile.assembly
    Dockerfile.annotation
  scripts/
    summarize_all_results.py
  Go_MAGs_QC.sh
  Go_MAGs_Assembly.sh
  Go_MAGs_Annotation.sh
  MAGs_pipeline.png
  MAGs_pipeline.pdf
```

## Workstation Layout

After installation with `--prefix /data/kpark-pipelines`:

```text
/data/kpark-pipelines/MAGs/
  Go_MAGs_Annotation.sh
  Go_MAGs_Assembly.sh
  Go_MAGs_QC.sh
  MAGs_pipeline.pdf
  MAGs_pipeline.png
  docker/
  scripts/
  workflow/
```

## QC Module

The QC workflow performs paired-end FASTQ QC and host read depletion:

```text
raw FASTQ
  -> fastp
  -> filtered_fastq/
  -> bowtie2 host filtering
  -> host_filtered_fastq/*_R1_nohuman.fastq.gz
  -> host_filtered_fastq/*_R2_nohuman.fastq.gz
  -> QC_summary.csv
```

### Build QC Image

Build from the workstation Docker directory:

```bash
cd /data/kpark-pipelines/MAGs/docker
docker build -f Dockerfile.qc -t mags-qc:1.0 .
```

### Build Assembly Image

Build from the workstation Docker directory:

```bash
cd /data/kpark-pipelines/MAGs/docker
docker build -f Dockerfile.assembly -t mags-assembly:1.0 .
```

### Build Annotation Image

Build from the workstation Docker directory:

```bash
cd /data/kpark-pipelines/MAGs/docker
docker build -f Dockerfile.annotation -t mags-annotation:1.0 .
```

### Run QC With Docker Wrapper

`-d` must be the Bowtie2 host index prefix, not just the directory.

```bash
./Go_MAGs_QC.sh \
  -i /data/projects/ProjectA/fastq \
  -o mags_qc_out \
  -d /data/kpark-db/host/bowtie2/chm13v2.0/chm13v2.0 \
  -c 8 \
  -j 4 \
  -K
```

### Direct Snakemake Run

```bash
fastq_dir="input_fastqs"
output_dir="mags_qc_out"
host_db="/data/kpark-db/host/bowtie2/chm13v2.0/chm13v2.0"

snakemake --snakefile /data/kpark-pipelines/MAGs/workflow/Go_MAGs_QC_V1.smk \
  --config fastq_dir="$fastq_dir" output_dir="$output_dir" host_db="$host_db" paired=2 threads=8 \
  --cores 8 --jobs 4 \
  --latency-wait 60 --rerun-incomplete
```

## QC Input Naming

Supported paired-end R1 naming patterns:

- `<sample>_L001_R1_001.fastq.gz`
- `<sample>_R1_001.fastq.gz`
- `<sample>_R1.fastq.gz`
- `<sample>.R1.fastq.gz`

Multiple lanes are concatenated per sample before `fastp`.

## QC Output

```text
mags_qc_out/
  filtered_fastq/
    <sample>_R1_filtered.fastq.gz
    <sample>_R2_filtered.fastq.gz
    <sample>_fastp.json
    <sample>_fastp.html
  host_filtered_fastq/
    <sample>_R1_nohuman.fastq.gz
    <sample>_R2_nohuman.fastq.gz
  intermediate/
  logs/
  QC_summary.csv
```

## Assembly And Binning Module

After QC is complete, use the QC `host_filtered_fastq` directory as the assembly input:

```bash
./Go_MAGs_Assembly.sh \
  -i mags_qc_out/host_filtered_fastq \
  -o mags_assembly_out \
  -d /data/kpark-db/checkm \
  -c 24 \
  -j 4 \
  -t 24 \
  -M 128000 \
  -K
```

Dry-run first:

```bash
./Go_MAGs_Assembly.sh \
  -i mags_qc_out/host_filtered_fastq \
  -o mags_assembly_out \
  -d /data/kpark-db/checkm \
  -c 24 \
  -j 4 \
  -n
```

### Direct Snakemake Run

```bash
snakemake --snakefile /data/kpark-pipelines/MAGs/workflow/Go_MAGs_Assembly_V1.smk \
  --config fastq_dir="mags_qc_out/host_filtered_fastq" output_dir="mags_assembly_out" \
  checkm_data_dir="/data/kpark-db/checkm" megahit_threads=24 megahit_memory=128000 binning_tools="concoct,metabat2,maxbin2" \
  --cores 24 --jobs 4 \
  --latency-wait 60 --rerun-incomplete --keep-going
```

### Assembly Output

```text
mags_assembly_out/
  1_MEGAHIT/
  2_Contigs/
  3_Binning/
  4_Mapping/
  5_Coverage/
  6_Mapped_Reads/
  7_DAS_tool_out/
  8_checkM_summary/
  9_Final_MAGs/
  assembly_summary.csv
  checkm_summary_combined.csv
```

## Annotation Module

The annotation workflow is also Docker-based. Provide a directory containing final MAG FASTA files (`*.fa` or `*.fasta`) plus the GTDB-Tk, EggNOG, and KofamScan database directories.

```bash
./Go_MAGs_Annotation.sh \
  -i mags_assembly_out/9_Final_MAGs \
  -o mags_annotation_out \
  -g /data/kpark-db/gtdbtk/release220 \
  -e /data/kpark-db/eggnog \
  -k /data/kpark-db/kofam \
  -c 24 \
  -j 4 \
  -K
```

Dry-run first:

```bash
./Go_MAGs_Annotation.sh \
  -i mags_assembly_out/9_Final_MAGs \
  -o mags_annotation_out \
  -g /data/kpark-db/gtdbtk/release220 \
  -e /data/kpark-db/eggnog \
  -k /data/kpark-db/kofam \
  -c 24 \
  -j 4 \
  -n
```

Expected mounted database layout inside Docker:

```text
/db/gtdbtk/
  mash_db/genomic_mash_db.msh
/db/eggnog/
  eggnog_proteins.dmnd
/db/kofam_scan/
  ko_list
  profiles/
```

## Container runtime

Shell launchers accept `--container docker|apptainer` (default: `docker`).
For HPC use `--container apptainer --container-image /path/to/pipeline.sif`
with the existing analysis options. See [shared runtime instructions](../README.md#docker--apptainer-selection)
for SIF preparation and deployment of `common/container.sh`.
