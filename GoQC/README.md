# GoQC

Paired-end FASTQ QC and host read depletion for CAULab shotgun workflows.

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
cd "$CAULAB_PIPELINES/GoQC"
docker build -t goqc:caulab .
```

On Apple Silicon Mac, if the normal build fails while solving Bioconda packages, build and run the amd64 image:

```bash
docker build --platform linux/amd64 -t goqc:caulab .
export DOCKER_PLATFORM=linux/amd64
```

## Run

```bash
Go_QC.sh \
  -i /data/projects/ProjectA/fastq \
  -o ProjectA_QC \
  -d /data/db/host/hg38/bowtie2/hg38 \
  -s "$CAULAB_PIPELINES/GoQC" \
  -m goqc:caulab \
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
