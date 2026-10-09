# K-park Lab Pipelines

Snakemake pipelines for Illumina and ONT data.
Bacterial Genome, Metagenome, RNA-seq, and 16S/ITS analysis.

## Documentation

[Documentation Portal](https://bbagy.github.io/KParkLab/)

## Pipelines

| Pipeline | Analysis |
|---|---|
| daDake2 | DADA2 16S/ITS analysis and RDS checkpoints |
| GoQC | Paired-end FASTQ QC and host read removal |
| KBracken | Kraken2 / Bracken taxonomic profiling |
| Humannake | HUMAnN3 / MetaPhlAn4 functional profiling |
| MAGs (testing) | Metagenome QC, assembly, binning, and annotation |
| longWGS | ONT assembly, polishing, QC, and annotation |
| shortWGS | Illumina typing: MLST, ARG, plasmids, and TETyper |
| RNake | Bacterial RNA-seq: fastp QC, Bowtie2 mapping, and HTSeq counts |

## Install

Requirements: Git and a running Docker Engine. Default platform: Ubuntu server. Prepare the mounted `/data` disk and Docker storage using [installation notes](INSTALL_KParkLab.md#data-disk-setup) before building.

```bash
git clone https://github.com/bbagy/KParkLab.git "/data/KParkLab"
cd "/data/KParkLab"
bash install_docker_env.sh --prefix /data/kpark-pipelines --update --build-all
source "/data/kpark-pipelines/kpark.env"
kpark_usage.sh
```

- Code: `/data/KParkLab`
- Installation: `/data/kpark-pipelines`
- Commands on PATH: `/data/kpark-pipelines/bin`
- `--build-all`: all 9 Docker images; MAGs uses 3 images.
- `--build-core`: GoQC, KBracken, and Humannake images.
- daDake2: host Mamba/Conda, Snakemake, R/DADA2, phyloseq, and QIIME 2; FIGARO setup on first `-A` run.
- DB downloads: separate from installation.
- Custom installation: `--prefix /path/to/kpark-pipelines`
- Target architecture: `--platform linux/amd64`

New terminal:

```bash
source "/data/kpark-pipelines/kpark.env"
```

## Storage layout

Use a mounted data disk; examples use `/data`. Configure Docker (`/data/docker`, plus `/data/containerd` when applicable) before building images. Install Miniforge in `/data/miniforge3`, and set `CONDA_ENVS_PATH=/data/conda/envs` and `CONDA_PKGS_DIRS=/data/conda/pkgs` before creating environments. Keep DBs in `/data/kpark-db`, and inputs/results in `/data/projects`.

Start with [data disk setup and migration](INSTALL_KParkLab.md#data-disk-setup), including directory permissions, persistent shell settings, and verified cleanup of old root-disk files. The installer still defaults to the home directory unless `--prefix` is supplied.

## Update

```bash
cd "/data/KParkLab"
git pull --ff-only
bash install_docker_env.sh --prefix /data/kpark-pipelines --update --build-all
source "/data/kpark-pipelines/kpark.env"
```

Local settings preserved: `config/lab_paths.sh` and `config/lab_paths.yaml`.
DBs and analysis outputs stored outside the repository.

## Docker / Apptainer

Docker-to-SIF conversion for HPC systems that use Apptainer.

- Local server: Docker
- HPC: Apptainer / SIF
- GoQC: Docker only
- daDake2: host environment

```bash
Go_shortWGS.sh --container docker [pipeline options]
Go_shortWGS.sh --container apptainer --container-image /shared/shortwgs.sif [pipeline options]
```

Image export and SIF conversion: [container guide](common/README.md).

## Reference DBs

```bash
source "/data/kpark-pipelines/kpark.env"
DB_ROOT="/data/kpark-db"
bash "/data/kpark-pipelines/download_databases.sh" --db-root "$DB_ROOT" --tools all --threads 8
source "/data/kpark-pipelines/config/lab_paths.sh"
```

- Included: CHM13 host index, Kraken2/Bracken, HUMAnN/MetaPhlAn.
- Other references: [DB preparation guide](https://bbagy.github.io/KParkLab/workstations.html#databases).
- Local DB paths: `config/lab_paths.sh`.

## Maintainer

Heekuk Park

## Existing CAULab or home-directory installations

The project is now K-park Lab; old clone URLs redirect. Migrate source code, DBs,
Conda environments, and Docker storage to `/data` using the
[verified migration procedure](INSTALL_KParkLab.md#move-an-existing-root-disk-installation).
Install with `--prefix /data/kpark-pipelines`; update both local DB configuration
files to the copied paths. Remove old root-disk copies only after verification.
