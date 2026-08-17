# Game of Life workload

This directory contains the portable image generator, Verilator profiling
harness, runner scripts, and checksum oracles used for the scaling workload.
Images and simulator binaries are generated locally and are not committed.

Expected checksums include 900 for 64x64, 3844 for 128x128, and 15876 for
256x256. Point the scripts at generated images with `GOL_WORKLOAD_DIR`, or build
inside this repository with `build_gol_profiling.sh`. The qualified final ROI
cycle counts are 463,868 for GOL128 and 1,880,884 for GOL256.
