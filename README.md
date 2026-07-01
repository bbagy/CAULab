# CAULab Pipelines

![Snakemake](https://img.shields.io/badge/Snakemake-Workflow-039be5)
![Docker](https://img.shields.io/badge/Docker-Containerized-0db7ed)
![Status](https://img.shields.io/badge/Status-Active-2e7d32)

Containerized shotgun metagenomics pipelines for routine analysis in CAULab and other labs.
Each pipeline is self-contained with its own `Dockerfile`, workflow, wrapper script, and README.

---

## Pipeline Catalog

Available now (production-ready):

- `GoQC`: paired-end FASTQ QC and host read depletion
- `KBracken`: Kraken2 + Bracken profiling and merged MPA-style tables
- `Humann`: HUMAnN3 + MetaPhlAn4 functional profiling with KEGG orthology output

---

## Documentation

- CAULab setup notes: `INSTALL_CAULab.md`
- Command usage helper: `caulab_usage.sh`
- Public documentation can be added after the CAULab repository URL is finalized.

## Quick Install

```bash
git clone https://github.com/bbagy/CAULab.git
cd CAULab
./install_mac.sh --build-core
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

If `$HOME/caulab-pipelines` already exists, use the installed commands directly:

```bash
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

To refresh an existing install from a newly pulled clone:

```bash
cd CAULab
git pull
./install_mac.sh --update --build-core
source "$HOME/caulab-pipelines/caulab.env"
```

`--update` refreshes the installed `.sh` wrappers, Snakefiles, Dockerfiles, and `bin/` links while preserving `config/lab_paths.yaml`.

If Docker images are missing, make sure Docker Desktop is running, then rerun:

```bash
./install_mac.sh --update --build-core
docker image inspect goqc:caulab kbracken:caulab humann:caulab >/dev/null
```

On Apple Silicon Mac, if package solving fails during Docker build:

```bash
cd CAULab
./install_mac.sh --build-core --platform linux/amd64
source "$HOME/caulab-pipelines/caulab.env"
caulab_usage.sh
```

---

## Common Conventions

- Data and DB files are mounted from host paths.
- Outputs are written under user-defined output directories.
- Wrapper scripts auto-retry lock issues with Snakemake `--unlock`.
- Data, DB, and pipeline installation paths are lab-specific and must be passed as wrapper arguments.
- Keep a stable install root on each workstation, usually `$HOME/caulab-pipelines`; use another writable path if needed.
- Wrapper scripts, Snakefiles, and Dockerfiles live together in each pipeline directory.
- Common wrapper flags:
  - `-n` (or `-x` for `Go_Humann.sh`): dry-run (show execution plan only)
  - `-K`: keep-going (continue independent jobs even if some fail)

---

## Suggested Install Layout

```bash
caulab-pipelines/
  GoQC/
    Go_QC.sh
    Go_QC_V1.smk
    Dockerfile
  KBracken/
    Go_KBracken.sh
    Go_KBracken_V1.smk
    Dockerfile
  Humann/
    Go_Humann.sh
    Go_Humann_V1.smk
    Dockerfile
  config/lab_paths.yaml
```

---

## Notes

- Reference databases are not versioned in this repository.
- Local DB paths belong in `config/lab_paths.yaml`; commit only `config/lab_paths.example.yaml`.
- Large outputs should stay outside Git-tracked paths.

---

## Maintainer

Heekuk Park
