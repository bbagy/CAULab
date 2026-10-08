# CAULab Pipelines

![Snakemake](https://img.shields.io/badge/Snakemake-Workflow-039be5)
![Docker](https://img.shields.io/badge/Docker-Containerized-0db7ed)
![Status](https://img.shields.io/badge/Status-Active-2e7d32)

Sequencing pipelines using the UhlemannLab pipeline structure, with CAULab installation and database settings.
Container launchers share `common/container.sh` and support Docker or Apptainer. GoQC remains available for standalone metagenome QC.

## Pipeline Catalog

| Pipeline | Purpose |
|---|---|
| GoQC | Paired-end FASTQ QC and host read depletion |
| longWGS | ONT assembly, polishing, QC, and annotation |
| shortWGS | Illumina typing: MLST, ARG, plasmid, and TETyper |
| KBracken | Kraken2 + Bracken taxonomic profiling |
| Humann | HUMAnN3 + MetaPhlAn4 functional profiling |
| RNake | Bacterial RNA-seq trimming, mapping, and counts |
| daDake2 | DADA2 16S/ITS processing with project checkpoints |
| MAGs (in testing) | Metagenome QC, assembly/binning, and annotation |

## Install and Update

```bash
git clone https://github.com/bbagy/CAULab.git
cd CAULab
./install_mac.sh --build-core
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

All pipeline code is installed by default. `--build-core` builds GoQC, KBracken, and Humann; `--build-all` also builds longWGS, shortWGS, RNake, and the three MAGs images.
For an existing installation:

```bash
git pull
./install_mac.sh --update --build-core
source "$HOME/caulab-pipelines/caulab.env"
```

`--update` refreshes pipeline code, shared helpers, documentation, and command links while preserving `config/lab_paths.sh` and `config/lab_paths.yaml`.
Use `--prefix /path/to/caulab-pipelines` for another install location. Use `--platform linux/amd64` on Apple Silicon when needed, and `--no-cache` to rebuild a broken image.
`daDake2` runs on the host: install Snakemake, R with DADA2 and its required packages, and FIGARO as described in [its README](daDake2/README.md).
GoQC uses Docker; the other container launchers also accept Apptainer.

## Docker and Apptainer

```bash
Go_shortWGS.sh --container docker [pipeline options]
Go_shortWGS.sh --container apptainer --container-image /shared/shortwgs.sif [pipeline options]
```

See [the container image guide](common/README.md) for image export and SIF conversion.
Pipeline wrappers locate shared helpers and workflows relative to the repository, including when invoked through installed command links.
Inputs, databases, and outputs remain outside the repository. New pipelines use explicit database/reference flags; CAULab's existing KBracken and Humann database defaults are retained.

## Reference Databases

```bash
download_databases.sh --db-root /Volumes/CAULabDB --tools all --threads 8
source "$HOME/caulab-pipelines/caulab.env"
```

The downloader covers GoQC host filtering (CHM13/T2T), Kraken2/Bracken, and HUMAnN/MetaPhlAn. Other pipelines require their own references as documented in each pipeline README.
Local database settings belong in `config/lab_paths.sh`; databases and analysis outputs are not versioned.

## Documentation

- [Installation guide](INSTALL_CAULab.md)
- [Documentation portal source](docs/index.html)
- [Container guide](common/README.md)
- `caulab_usage.sh` lists installed commands and core examples.

문서 포털은 한글 소개와 CAULab 전용 디자인으로 구성되어 있습니다. [문서 소스](docs/index.html)를 참고하세요. GitHub Pages 배포는 저장소 요금제와 공개 설정을 확인한 뒤 별도로 설정해야 합니다.

## Maintainer

Heekuk Park
