# Build safety

- Build on ext4/xfs/btrfs, not NTFS/exFAT.
- Keep at least 450 GiB free before sync/build.
- With 16 GiB RAM, use about 32 GiB swap and `BUILD_JOBS=3`.
- The default `USE_CCACHE=0` avoids consuming another ~50 GiB on the first build.
- Docker is preferred to reduce old Android BSP host-package drift.
- Do not interrupt `repo sync` by deleting `.repo`; rerun `scripts/sync.sh` and it will retry missing projects.
- Do not run `repo sync` while manually editing upstream tracked files. This controller creates an untracked product/DTS and can regenerate both.
