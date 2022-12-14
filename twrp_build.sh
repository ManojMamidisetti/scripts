#/bin/bash!
#
# Copyright (C) 2022 JaswantTeja
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "$MY_DIR" ]]; then MY_DIR="$PWD"; fi

# Setup colour for the script
yellow='\033[0;33m'
white='\033[0m'
red='\033[0;31m'
green='\e[0;32m'

# Variables for ENV Setup
CHATID="$chat"
API_BOT="$api"
VENDOR=""
DEVICE=""
CODENAME=""
DEVICE_TREE=""
DEVICE_BRANCH=""
TWRP_VERSION=""

# Telegram Setup
export BOT_MSG_URL="https://api.telegram.org/bot$API_BOT/sendMessage"
export BOT_BUILD_URL="https://api.telegram.org/bot$API_BOT/sendDocument"

tg_post_msg() {
        curl -s -X POST "$BOT_MSG_URL" -d chat_id="$2" \
        -d "parse_mode=html" \
        -d text="$1"
}

tg_post_build() {
        #Post MD5Checksum alongwith for easeness
        MD5CHECK=$(md5sum "$1" | cut -d' ' -f1)

        #Show the Checksum alongwith caption
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3 build finished in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds | <b>MD5 Checksum : </b><code>$MD5CHECK</code>"
}

tg_error() {
        curl --progress-bar -F document=@"$1" "$BOT_BUILD_URL" \
        -F chat_id="$2" \
        -F "disable_web_page_preview=true" \
        -F "parse_mode=html" \
        -F caption="$3Failed to build , check <code>error.log</code>"
}

# Start Buliding

echo "============================="
echo "    Started Building TWRP    " 
echo "============================="

build_twrp() {
Start=$(date +"%s")

. build/envsetup && lunch omni_"$CODENAME"-eng && export ALLOW_MISSING_DEPENDENCIES=true
mka recoveryimage | tee error.log

End=$(date +"%s")
Diff=$(($End - $Start))
}

export IMG="$MY_DIR"/out/target/product/"$CODENAME"/recovery.img

# Init TWRP repo
mkdir TWRP && cd TWRP
repo init https://github.com/minimal-manifest-twrp/platform_manifest_twrp_omni -b "$TWRP_VERSION" --depth=1
repo sync

# Clone device tree
git clone "$DEVICE_TREE" -b "$DEVICE_BRANCH" device/"$VENDOR"/"$CODENAME"/

# let's start building the image

tg_post_msg "<b>TWRP CI Build Triggered for $CODENAME</b>" "$CHATID"
build_twrp || error=true
DATE=$(date +"%Y%m%d-%H%M%S")

	if [ -f "$IMG" ]; then
		echo -e "$green << Build completed in $(($Diff / 60)) minutes and $(($Diff % 60)) seconds >> \n $white"
	else
		echo -e "$red << Failed to compile the TWRP image , Check up error.log >>$white"
		tg_error "error.log" "$CHATID"
		rm -rf out
		rm -rf error.log
		exit 1
	fi

	if [ -f "$IMG" ]; then
		TWRP_IMGAGE="twrp*_$CODENAME_$DATE.img"
		mkdir Package
		mv "$IMG" Package/"$TWRP_IMGAGE"
		cd Package
		tg_post_build "$TWRP_IMGAGE" "$CHATID"
		exit
	fi
