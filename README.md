# K-Park Lab Pipelines

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
git clone https://github.com/bbagy/KParkLab.git "$HOME/KParkLab"
cd "$HOME/KParkLab"
bash install_docker_env.sh --build-all
source "$HOME/kpark-pipelines/kpark.env"
kpark_usage.sh
```

- Code: `$HOME/KParkLab`
- Installation: `$HOME/kpark-pipelines`
- Commands on PATH: `$HOME/kpark-pipelines/bin`
- `--build-all`: all 9 Docker images; MAGs uses 3 images.
- `--build-core`: GoQC, KBracken, and Humannake images.
- daDake2: host Mamba/Conda, Snakemake, R/DADA2, phyloseq, and QIIME 2; FIGARO setup on first `-A` run.
- DB downloads: separate from installation.
- Custom installation: `--prefix /path/to/kpark-pipelines`
- Target architecture: `--platform linux/amd64`

New terminal:

```bash
source "$HOME/kpark-pipelines/kpark.env"
```

## Update

```bash
cd "$HOME/KParkLab"
git pull --ff-only
bash install_docker_env.sh --update --build-all
source "$HOME/kpark-pipelines/kpark.env"
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
source "$HOME/kpark-pipelines/kpark.env"
DB_ROOT="$HOME/kpark-db"
bash "$HOME/kpark-pipelines/download_databases.sh" --db-root "$DB_ROOT" --tools all --threads 8
source "$HOME/kpark-pipelines/config/lab_paths.sh"
```

- Included: CHM13 host index, Kraken2/Bracken, HUMAnN/MetaPhlAn.
- Other references: [DB preparation guide](https://bbagy.github.io/KParkLab/workstations.html#databases).
- Local DB paths: `config/lab_paths.sh`.

## Documentation

- [Documentation Portal — Korean](https://bbagy.github.io/KParkLab/)
- [Installation guide](INSTALL_KParkLab.md)
- [Docker / Conda environments](https://bbagy.github.io/KParkLab/environments.html)
- [Container guide](common/README.md)
- Command list: `kpark_usage.sh`

Repository documentation: English. Web documentation: Korean.
GitHub Pages: `main` → `/docs`; static files with `docs/.nojekyll`.

## Maintainer

Heekuk Park

## Updating an existing CAULab installation

The project is now K-Park Lab. GitHub repository redirects preserve old clone URLs.
To keep existing database paths and the installation directory:

```bash
cd "$HOME/CAULab"
git remote set-url origin https://github.com/bbagy/KParkLab.git
git pull --ff-only
bash install_docker_env.sh --prefix "$HOME/caulab-pipelines" --update --build-all
source "$HOME/caulab-pipelines/kpark.env"
```

New installations use `$HOME/kpark-pipelines`, `kpark.env`, and `KPARK_*` variables.
Existing database files stay in place.
