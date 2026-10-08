# shortWGS

![Illumina](https://img.shields.io/badge/Reads-Illumina-1f77b4)
![Workflow](https://img.shields.io/badge/Workflow-Snakemake-039be5)
![Container](https://img.shields.io/badge/Runtime-Docker-0db7ed)

Bacterial Illumina WGS workflow for QC, species inference, genotyping, and final summary reporting.

## Current Entrypoints

- Wrapper: `Go_shortWGS.sh`
- Snakefile (current): `Go_shortWGS_V10_docker.smk`
- Snakefile (legacy): `Go_shortWGS_V9_docker.smk`

## Pipeline

```mermaid
flowchart LR
  A[Paired FASTQ] --> B[Prefilter gzip + pair check]
  B --> C[fastp]
  C --> D[Kraken2 species + top1/2/3 + unclassified]
  D --> E[SRST2: MLST/ARG/Plasmid]
  E --> F[TETyper_modi]
  F --> G[MultiQC + CSV summary]
  G --> H[summary_report.html]
```

## Requirements

- Docker
- Linux shell
- Paired FASTQ files
- WGS DB root (`WGS_DB2` style)
- Kraken2 DB
- Report templates: bundled in `shortWGS/scripts/`; pass `-r "$HOME/kpark-pipelines/shortWGS"` for the legacy wrapper mount.

## Build

Build from `shortWGS` directory (Docker context must include `TETyper_modi.py`).

```bash
cd shortWGS
docker build --network=host -t shortwgs .
```

If `COPY TETyper_modi.py` fails, ensure this file exists in the same directory as Dockerfile.

## Docker Tool Layout

The image uses multi-environment setup:

- `wgs`: Snakemake, fastp, kraken2, R, multiqc, general tools
- `srst2`: `srst2` + required mapping tools
- `tetyper`: `TETyper_modi.py` dependencies (`spades`, `samtools`, `bcftools`, `blastn`, python libs)

The Snakefile runs tools via `micromamba run -n <env> ...`.

## Docker Tool Inventory

Representative tools included:

- `wgs` env: `snakemake`, `fastp`, `kraken2`, `multiqc`, `Rscript`, `bowtie2`, `samtools`, `bcftools`
- `srst2` env: `srst2` (+ required mapping tools)
- `tetyper` env: `python`, `spades.py`, `samtools`, `bcftools`, `blastn`, `TETyper_modi.py` dependencies

## Run A Single Tool From The Image

Examples (without conda on host):

```bash
# main env tools
docker run --rm shortwgs snakemake --version
docker run --rm shortwgs fastp --version
docker run --rm shortwgs kraken2 --version

# srst2 env
docker run --rm shortwgs micromamba run -n srst2 srst2 --help

# tetyper env
docker run --rm shortwgs micromamba run -n tetyper python /usr/local/bin/TETyper_modi.py --help
```

## Quick Start

```bash
./shortWGS/Go_shortWGS.sh \
  -i /path/to/fastq \
  -o /path/to/output \
  -d /path/to/WGS_DB2 \
  -k /path/to/kraken2_db \
  -c 8 \
  -K
```

## Options (`Go_shortWGS.sh`)

| Flag | Default | Description |
|---|---:|---|
| `-i` | - | Input FASTQ directory |
| `-o` | - | Output directory |
| `-d` | - | WGS DB root (`WGS_DB2`) |
| `-k` | - | Kraken2 DB directory |
| `-r` | script directory | Optional report directory override (`scripts/` contains Rmd and CSS) |
| `-s` | script directory | Optional Snakefile directory override |
| `-c` | `8` | Snakemake cores |
| `-m` | `shortwgs` | Docker image name |
| `-n` | off | Dry-run (`--dry-run`) |
| `-K` | off | Keep going (`--keep-going`) |
| `-P` | `1` | Progress monitor (`1` on, `0` off) |

## Input Layout

Supported FASTQ naming:

- `<sample>_R1_001.fastq.gz` / `<sample>_R2_001.fastq.gz`
- `<sample>_R1.fastq.gz` / `<sample>_R2.fastq.gz`
- `<sample>.R1.fastq.gz` / `<sample>.R2.fastq.gz`

Expected DB layout:

```text
WGS_DB2/
  CARD/                    (*.fasta)
  PlasmidFinder/           (*.fasta)
  MLST/
    e_coli/
    k_pneumoniae/
    ...
  tetyper/
    Tn4401b-1.fasta
    struct_profiles.txt
    snp_profiles.txt
```

## Output Layout

```text
OUT/
  1_fastp_out/
  2a_kraken2/
    <sample>.kreport
    <sample>.top_species.txt
    kraken2_summary.csv
    kraken2_db_info.txt
  2_ST_srst2_out/
  3_ARGs_srst2_out/
  4_Plasmid_srst2_out/
  5_TETyper/
  multiqc_report.html
  multiqc.done.txt
  summary_master.csv
  summary_report.html
  skip.log
  shortwgs.log
```

Key files:

- `2a_kraken2/kraken2_summary.csv` (Sample, Top1, Top2, Top3, Unclassified)
- `2a_kraken2/kraken2_db_info.txt` (DB path/name used in Kraken2)
- `2_ST_srst2_out/mlst_master.csv`
- `5_TETyper/tetyper_summary.json`
- `summary_master.csv`
- `summary_report.html`

Prefilter artifacts (sibling of input FASTQ dir):

```text
0_bad_fastqs/
  DONE.txt
  moved_bad_fastqs.tsv
```

## Operational Notes

- Wrapper prefilter runs before Snakemake:
  - `gzip -t` integrity check
  - R1/R2 pairing validation
  - bad files moved out of input directory
- V10 report adds `Kraken2 Result` section between `Master Summary table` and `MLST Result`.
- Kraken2 DB name is shown in the HTML report from runtime `kraken_db` setting.
- Progress is printed only when status changes.
- Lock errors are auto-handled (`--unlock` then retry).
- `INT/TERM` interrupt handling is enabled in wrapper.

## Common Runs

Dry-run:

```bash
./shortWGS/Go_shortWGS.sh -i IN -o OUT -d DB -k KRAKEN -n
```

Production run:

```bash
./shortWGS/Go_shortWGS.sh -i IN -o OUT -d DB -k KRAKEN -K
```

Use custom image tag:

```bash
./shortWGS/Go_shortWGS.sh -i IN -o OUT -d DB -k KRAKEN -m shortwgs
```

## Troubleshooting

- `COPY TETyper_modi.py` failed during build
  - ensure `shortWGS/TETyper_modi.py` exists in Docker build context
- `image not found shortwgs`
  - build with tag `shortwgs` or run wrapper with `-m <tag>`
- no summary report generated
  - check mounted `-r` path and Rmd template path in Snakefile

## Maintainer

Heekuk Park

## Container runtime

Shell launchers accept `--container docker|apptainer` (default: `docker`).
For HPC use `--container apptainer --container-image /path/to/pipeline.sif`
with the existing analysis options. See [shared runtime instructions](../README.md#docker--apptainer-selection)
for SIF preparation and deployment of `common/container.sh`.
