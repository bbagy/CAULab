#!/usr/bin/env bash
set -euo pipefail
# Usage: bash check_humann_logs_example.sh OUTPUT_DIR SAMPLE_NAME
output_dir="${1:?Specify the Humannake output directory}"
sample="${2:?Specify the sample name}"
tail -n 100 "$output_dir/6_logs/$sample.humann.log" || true
echo
tail -n 100 "$output_dir/1_humann3_out/${sample}_humann_temp/$sample.log" || true
