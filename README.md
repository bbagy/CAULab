# CAULab Pipelines

Snakemake pipelines for Illumina and ONT data.
Bacterial Genome, Metagenome, RNA-seq, and 16S/ITS analysis.

## Pipelines

| Pipeline | Analysis |
|---|---|
| GoQC | Paired-end FASTQ QC and host read removal |
| longWGS | ONT assembly, polishing, QC, and annotation |
| shortWGS | Illumina typing: MLST, ARG, plasmids, and TETyper |
| KBracken | Kraken2 / Bracken taxonomic profiling |
| Humannake | HUMAnN3 / MetaPhlAn4 functional profiling |
| RNake | Bacterial RNA-seq trimming, mapping, and gene counts |
| daDake2 | DADA2 16S/ITS analysis and RDS checkpoints |
| MAGs (testing) | Metagenome QC, assembly, binning, and annotation |

## Install

Requirements: Git and a running Docker Engine. Default platform: Ubuntu server.

```bash
git clone https://github.com/bbagy/CAULab.git "$HOME/CAULab"
cd "$HOME/CAULab"
bash install_docker_env.sh --build-all
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

- Code: `$HOME/CAULab`
- Installation: `$HOME/caulab-pipelines`
- Commands on PATH: `$HOME/caulab-pipelines/bin`
- `--build-all`: all 9 Docker images; MAGs uses 3 images.
- `--build-core`: GoQC, KBracken, and Humannake images.
- daDake2: host Mamba/Conda, Snakemake, R/DADA2, phyloseq, and QIIME 2; FIGARO setup on first `-A` run.
- DB downloads: separate from installation.
- Custom installation: `--prefix /path/to/caulab-pipelines`
- Target architecture: `--platform linux/amd64`

New terminal:

```bash
source "$HOME/caulab-pipelines/caulab.env"
```

## Update

```bash
cd "$HOME/CAULab"
git pull --ff-only
bash install_docker_env.sh --update --build-all
source "$HOME/caulab-pipelines/caulab.env"
```

Local settings preserved: `config/lab_paths.sh` and `config/lab_paths.yaml`.
DBs and analysis outputs stored outside the repository.

## Docker / Apptainer

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
source "$HOME/caulab-pipelines/caulab.env"
DB_ROOT="$HOME/caulab-db"
bash "$HOME/caulab-pipelines/download_databases.sh" --db-root "$DB_ROOT" --tools all --threads 8
source "$HOME/caulab-pipelines/config/lab_paths.sh"
```

- Included: CHM13 host index, Kraken2/Bracken, HUMAnN/MetaPhlAn.
- Other references: [DB preparation guide](https://bbagy.github.io/CAULab/workstations.html#databases).
- Local DB paths: `config/lab_paths.sh`.

## Documentation

- [Documentation Portal — Korean](https://bbagy.github.io/CAULab/)
- [Installation guide](INSTALL_CAULab.md)
- [Docker / Conda environments](https://bbagy.github.io/CAULab/environments.html)
- [Container guide](common/README.md)
- Command list: `caulab_usage.sh`

Repository documentation: English. Web documentation: Korean.
GitHub Pages: `main` → `/docs`; static files with `docs/.nojekyll`.

## Maintainer

Heekuk Park
