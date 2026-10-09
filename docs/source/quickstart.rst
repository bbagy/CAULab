Quick Start
===========

Prerequisites
-------------

- Docker
- Linux shell
- Pipeline-specific input data and reference databases

Storage layout
--------------

Use a mounted data disk (examples: ``/data``). Before image builds, configure
Docker storage at ``/data/docker`` and containerd storage at ``/data/containerd``
when applicable. Install pipelines with ``--prefix /data/kpark-pipelines``;
store DBs at ``/data/kpark-db`` and inputs/results at ``/data/projects``.
Miniforge belongs in ``/data/miniforge3``; set ``CONDA_ENVS_PATH=/data/conda/envs``
and ``CONDA_PKGS_DIRS=/data/conda/pkgs`` before creating environments.
See the `installation and migration guide <https://bbagy.github.io/KParkLab/workstations.html#storage>`_.

Typical flow
------------

1. Move to a pipeline directory.
2. Build the Docker image.
3. Run a dry-run (`-n`) first.
4. Run production with `-K` (keep-going) when appropriate.
5. For longWGS, use `-M permissive` only when you want the summary workbook even if some late-stage jobs fail.

Example (shortWGS)
------------------

.. code-block:: bash

   source /data/kpark-pipelines/kpark.env
   cd /data/kpark-pipelines/shortWGS
   docker build --network=host -t shortwgs .
   mkdir -p /data/projects/ProjectA
   cd /data/projects/ProjectA
   Go_shortWGS.sh -i /data/projects/ProjectA/fastq -o out -d /data/kpark-db/shortWGS -k /data/kpark-db/kraken2/k2_pluspfp_16gb_latest -r "/data/kpark-pipelines/shortWGS" -n
   Go_shortWGS.sh -i /data/projects/ProjectA/fastq -o out -d /data/kpark-db/shortWGS -k /data/kpark-db/kraken2/k2_pluspfp_16gb_latest -r "/data/kpark-pipelines/shortWGS" -K
