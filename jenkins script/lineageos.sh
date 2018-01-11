#!/bin/bash
# If I don't define it, build will give me an error
export TMPDIR="$WORKSPACE/tmp"
# Clean tmp dir
rm -rf $TMPDIR
mkdir $TMPDIR
# repopick needs "repo" command
REPO="$WORKSPACE/lineageos-15.1/.repo/repo"
export PATH=/bin:/sbin:/usr/bin:/usr/sbin:$REPO:$PATH
FBASE_PATCH="0001-fw-base-Enable-home-button-wake.patch" # patch to wake device with home button
CAMERA_PATCH="0001-Revert-Camera-Remove-dead-legacy-code.patch" # We have legacy camera
cd lineageos-15.1
# Clean patched dirs that have repopicks
cd frameworks/av
git reset --hard HEAD@{0}
cd ../../hardware/samsung
git reset --hard HEAD@{0}
cd ../../vendor/lineage
git reset --hard HEAD@{0}
cd ../..
repo sync --force-sync
# Some needed commits haven't been pushed to lineage repos, yet. Let's repopick them, then
# Script can be found here http://msm8916.com/~vincent/repopicks.sh
./repopicks.sh
# Temporary remove disable AudioFX build: it crashes ad cause reboots in 8.1. Will be re-enabled later when gets stable
perl -i -ne 'print unless /^    AudioFX/; ' vendor/lineage/config/common.mk
cp device/samsung/a5-common/patches/$FBASE_PATCH frameworks/base/
cp device/samsung/a5-common/patches/$CAMERA_PATCH frameworks/av/
# Apply patch
(cd frameworks/base && patch -N -p1 < $FBASE_PATCH) # Also ignores patching if patch is already applied
(cd frameworks/av && patch -N -p1 < $CAMERA_PATCH)
rm frameworks/base/$FBASE_PATCH
rm frameworks/av/$CAMERA_PATCH
# Fix build error in hardware/samsung
sed -i 's=void rilEventAddWakeup_helper=//void rilEventAddWakeup_helper=g' hardware/samsung/ril/include/libril/ril_ex.h
# Cleanup from previous build

# sha256sums' file should be removed by twrp job. Remove it here, too, in case twrp build fails
rm -f ../../sha256sums_*.txt
rm -rf out
# For unknown reasons to me, with jenkins some headers aren't copied during build
export USE_CCACHE=1
# define -Xmx4g because my computer doesn't have enough ram for jack
export JACK_SERVER_VM_ARGUMENTS="-Dfile.encoding=UTF-8 -XX:+TieredCompilation -Xmx4g"
export ANDROID_JACK_VM_ARGS="$JACK_SERVER_VM_ARGUMENTS"
# lineage 15 zip path
export ROM_PATH="$WORKSPACE/lineageos-15.1/out/target/product/a5ultexx/lineage-15.1-*-UNOFFICIAL-a5ultexx.zip"
export ROM_ZIP="LineageOS_15.1_$(date +%Y%m%d)_SM-A500FU.zip"
# Kill jack server if active and start it (still for low ram reasons)
./prebuilts/sdk/tools/jack-admin kill-server || true
./prebuilts/sdk/tools/jack-admin start-server || true
# Start building
source build/envsetup.sh
brunch a5ultexx

# Tell the user to download a camera app that supports legacy ones to use it, because in 8.1 camera does not support legacy cameras.
# Do it by writing it in updater-scipt
mkdir $TMPDIR/zip # Gives error if the dir is already present, because zip dir needs to be clean, to not include shit in the zip
cd $TMPDIR/zip
cp $ROM_PATH $TMPDIR/los15.zip
unzip ../los15.zip
sed -i '/package_extract_file("boot.img", "\/dev\/block\/bootdevice\/by-name\/boot");/a ui_print("IMPORTANT: DEFAULT CAMERA APP ONLY TAKES PHOTOS");\nui_print("SO, DOWNLOAD A CAMERA APP FROM PLAY STORE e.g. OPEN CAMERA TO TAKE VIDEOS");\nui_print("TESTED CAMERAS: Open camera, Footej camera");' META-INF/com/google/android/updater-script
zip -r $ROM_ZIP *

# Create a file containing the sha256sum of the zip.
# We create it outside the project directory because twrp job will add his twrp sha256sums
sha256sum $ROM_ZIP > ../../../sha256sums_$(date +%Y%m%d).txt

# Publish to github
export GITHUB_TOKEN=# Secret :P
export GITHUB_USER=DeadSquirrel01
export GITHUB_REPO=lineage-15_a5_releases

# Publish the release
# Needs to have github-release installed
echo "Create a new release in https://github.com/DeadSquirrel01/lineage-15_a5_releases"
github-release release --user $GITHUB_USER --repo $GITHUB_REPO --tag $(date +%Y%m%d) --name "lineageos 15.1 $(date +%Y%m%d)"

echo "Uploading the lineage 15 zip into github release"
github-release upload --user $GITHUB_USER --repo $GITHUB_REPO --tag $(date +%Y%m%d) --name $ROM_ZIP --file $ROM_ZIP

cd ../../lineageos-15.1/lineage-15_a5_releases
git add changelog.txt
git commit -m "Update changelog to $(date +%Y%m%d) release"
git push https://$GITHUB_USER:$GITHUB_TOKEN@github.com/$GITHUB_USER/$GITHUB_REPO.git
cd ..

# Copy Build log
wget ${BUILD_URL}/consoleText -O build_log_$(date +%Y%m%d).txt
echo "Uploading build log"
github-release upload --user $GITHUB_USER --repo $GITHUB_REPO --tag $(date +%Y%m%d) --name build_log_$(date +%Y%m%d).txt --file build_log_$(date +%Y%m%d).txt
rm build_log_*.txt

cd $WORKSPACE
# Clean temporary dir again
rm -rf $TMPDIR

