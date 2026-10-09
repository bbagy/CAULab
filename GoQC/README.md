# GoQC

Examples use `/data` as the mounted data disk. Before running analysis commands:

```bash
source /data/kpark-pipelines/kpark.env
mkdir -p /data/projects/ProjectA
cd /data/projects/ProjectA
```

For DB, Docker, and Conda storage setup, see [installation notes](../INSTALL_KParkLab.md#data-disk-setup).

Paired-end FASTQ QC and host read depletion for K-park Lab shotgun workflows.

Outputs follow the legacy `GoQC.smk` contract:

```text
<output_dir>/
  filtered_fastq/
    <sample>_R1_filtered.fastq.gz
    <sample>_R2_filtered.fastq.gz
    <sample>_fastp.json
    <sample>_fastp.html
  host_filtered_fastq/
    <sample>_R1_nohuman.fastq.gz
    <sample>_R2_nohuman.fastq.gz
  QC_summary.csv
  logs/
```

## Build

```bash
cd "$KPARK_PIPELINES/GoQC"
docker build -t goqc:kpark .
```

On Apple Silicon Mac, if the normal build fails while solving Bioconda packages, build and run the amd64 image:

```bash
docker build --platform linux/amd64 -t goqc:kpark .
export DOCKER_PLATFORM=linux/amd64
```

## Run

```bash
Go_QC.sh \
  -i /data/projects/ProjectA/fastq \
  -o ProjectA_QC \
  -d /data/db/host/hg38/bowtie2/hg38 \
  -s "$KPARK_PIPELINES/GoQC" \
  -m goqc:kpark \
  -K
```

Use `ProjectA_QC/host_filtered_fastq` as the input for HUMAnN or MAG assembly.

## File Layout

```text
GoQC/
  Dockerfile
  Go_QC.sh
  Go_QC_V1.smk
  README.md
```

`Go_QC.sh` looks for `Go_QC.smk` first, then falls back to `Go_QC_V1.smk`, matching the KBracken wrapper structure.
