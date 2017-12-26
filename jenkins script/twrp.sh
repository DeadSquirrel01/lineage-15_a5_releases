#!/bin/bash
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$PATH
cd omni
.repo/repo/repo sync --force-sync
# Can also be added an entry in local manifest to use 8.0 and delete 7.1 sources (if using 7.1 tree)
# Soon we'll use 8.1 repo instead of 8.0
rm -rf bootable/recovery
git clone https://github.com/omnirom/android_bootable_recovery -b android-8.0 bootable/recovery --depth 1
# Cleanup
rm -f twrp_*_a5ultexx.tar
rm -rf out
export USE_CCACHE=1
# Ninja may cause problems
export USE_NINJA=false
export TWRP_VERSION=3.2.1
# Start building
source build/envsetup.sh
lunch omni_a5ultexx-eng
mka recoveryimage
# Create a tar
tar -cf twrp_$TWRP_VERSION_$(date +%Y%m%d)_a5ultexx.tar -C out/target/product/a5ultexx/ recovery.img
md5sum -t twrp_$TWRP_VERSION_$(date +%Y%m%d)_a5ultexx.tar >> twrp_$TWRP_VERSION_$(date +%Y%m%d)_a5ultexx.tar
sha256sum twrp_$TWRP_VERSION_$(date +%Y%m%d)_a5ultexx.tar >> ../../sha256sums_$(date +%Y%m%d).txt

# Publish to github
export GITHUB_TOKEN=# Secret :P

echo "Uploading the twrp tar into github release"
github-release upload --user DeadSquirrel01 --repo "lineage-15_a5_releases" --tag $(date +%Y%m%d) --name "twrp_$TWRP_VERSION_$(date +%Y%m%d)_a5ultexx.tar" --file "twrp_$TWRP_VERSION_$(date +%Y%m%d)_a5ultexx.tar"

echo "Uploading the sha256sums into github release"
github-release upload --user DeadSquirrel01 --repo "lineage-15_a5_releases" --tag $(date +%Y%m%d) --name "sha256sums_$(date +%Y%m%d).txt" --file "../../sha256sums_$(date +%Y%m%d).txt"

# Remove the now useless sha256sums file
rm -f ../../sha256sums_*.txt
