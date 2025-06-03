#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

VENDOR=redmi
DEVICE=begonia

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

export PATCHELF_VERSION=0_17_2

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
                CLEAN_VENDOR=false
                ;;
        -k | --kang )
                KANG="--kang"
                ;;
        -s | --section )
                SECTION="${2}"; shift
                CLEAN_VENDOR=false
                ;;
        * )
                SRC="${1}"
                ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup {
    case "${1}" in
        system/lib/libsink.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libshim_vtservice.so" "${2}"
            ;;
        vendor/lib/hw/audio.primary.mt6785.so|\
        vendor/lib/hw/audio.usb.mt6785.so)
	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libalsautils.so" "libalsautils-v30.so" "${2}"
            ;;
        vendor/lib64/hw/android.hardware.thermal@2.0-impl.so|\
        vendor/lib64/hw/dfps.mt6785.so|\
        vendor/lib64/hw/vendor.mediatek.hardware.pq@2.6-impl.so)
	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v32.so" "${2}"
            ;;
        vendor/lib64/libmtkcam_stdutils.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libutils.so" "libutils-v30.so" "${2}"
            ;;
        vendor/bin/mnld|\
        vendor/lib*/libaalservice.so|\
        vendor/lib*/libcam.utils.sensorprovider.so)
	    [ "$2" = "" ] && return 0
            grep -q "android.hardware.sensors@1.0-convert-shared.so" "$2" || "$PATCHELF" --add-needed "android.hardware.sensors@1.0-convert-shared.so" "$2"
            ;;
        vendor/bin/hw/android.hardware.keymaster@4.0-service.beanpod)
	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libshim_beanpod.so" "${2}"
            ;;
        vendor/lib/libMtkOmxVdecEx.so|\
        system/lib/libsource.so)
	    [ "$2" = "" ] && return 0
            grep -q "libui_shim.so" "$2" || "$PATCHELF" --add-needed "libui_shim.so" "$2"
            ;;
        vendor/bin/hw/vendor.dolby.hardware.dms@2.0-service)
            "$PATCHELF" --add-needed "libstagefright_foundation-v33.so" "$2"
            ;;
        system/lib64/libem_support_jni.so)
    	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libjni_shim.so" "${2}"
            ;;
        vendor/lib/libwvhidl.so|\
        vendor/lib/mediadrm/libwvdrmengine.so)
	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --replace-needed "libcrypto.so" "libcrypto-v33.so" "${2}"
            ;;
	vendor/bin/hw/android.hardware.neuralnetworks@1.3-service-mtk-neuron)
             [ "$2" = "" ] && return 0
             grep -q "libbase_shim.so" "${2}" || "${PATCHELF}" --add-needed "libbase_shim.so" "${2}"
             ;;
        vendor/lib/libmnl.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libcutils.so" "${2}"
            ;;
        system/lib/libmtk_vt_service.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libgui_shim.so" "${2}"
            ;;
        *)
            return 1
            ;;
    esac
}
function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
