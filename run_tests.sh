#!/bin/bash

set -uo pipefail

# Ensure adb has a writable HOME for ~/.android (common when running the container with a numeric UID).
if [ -z "${HOME:-}" ] || [ ! -w "${HOME:-/}" ]; then
    export HOME="/tmp"
fi
export ANDROID_SDK_HOME="${ANDROID_SDK_HOME:-$HOME}"
mkdir -p "${HOME}/.android" "${ANDROID_SDK_HOME}/.android" || true

# Avoid interactive prompts and ensure Maestro can write its state under a writable home.
export MAESTRO_CLI_NO_ANALYTICS="${MAESTRO_CLI_NO_ANALYTICS:-1}"
export MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED="${MAESTRO_CLI_ANALYSIS_NOTIFICATION_DISABLED:-true}"
export JAVA_TOOL_OPTIONS="${JAVA_TOOL_OPTIONS:--Duser.home=${HOME}}"

DEVICE="${DEVICE:-android-emulator:5555}"
TEST_TIMEOUT="${TEST_TIMEOUT:-600}"
APP_PACKAGE="${APP_PACKAGE:-com.smobilpayagentapp}"
TEST_SUITE="${TEST_SUITE:-regression}"
TEST_PATH="${TEST_PATH:-}"
APP_VERSION="${APP_VERSION:-latest}"
APP_DIR="${APP_DIR:-/app/app}"
SUITES_DIR="${SUITES_DIR:-/app/config/suites}"
INSTALL_ONLY="${INSTALL_ONLY:-0}"
DRY_RUN="${DRY_RUN:-0}"
MAESTRO_VERBOSE="${MAESTRO_VERBOSE:-0}"
MAESTRO_DEBUG_OUTPUT_DIR="${MAESTRO_DEBUG_OUTPUT_DIR:-}"
MAESTRO_FORMAT="${MAESTRO_FORMAT:-junit}"
RESULTS_ROOT="${RESULTS_ROOT:-/tmp/maestro-results}"
JUNIT_RESULTS_DIR="${JUNIT_RESULTS_DIR:-junit-results}"
ALLURE_RESULTS_DIR="${ALLURE_RESULTS_DIR:-allure-results}"

JUNIT_RESULTS_PATH="${RESULTS_ROOT}/${JUNIT_RESULTS_DIR}"
ALLURE_RESULTS_PATH="${RESULTS_ROOT}/${ALLURE_RESULTS_DIR}"

resolve_app_version() {
    local apk_path="$1"

    if [ -n "${APP_VERSION}" ] && [ "${APP_VERSION}" != "latest" ]; then
        echo "${APP_VERSION}"
        return 0
    fi

    if [ -f "${APP_DIR}/current.version" ]; then
        tr -d '[:space:]' < "${APP_DIR}/current.version"
        return 0
    fi

    basename "$(dirname "${apk_path}")"
}

resolve_apk_path() {
    if [ -n "${APK_PATH:-}" ] && [ -f "${APK_PATH}" ]; then
        echo "${APK_PATH}"
        return 0
    fi

    if [ -n "${APP_VERSION}" ] && [ "${APP_VERSION}" != "latest" ]; then
        local version_dir="${APP_DIR}/versions/${APP_VERSION}"
        if [ -d "${version_dir}" ]; then
            find "${version_dir}" -maxdepth 1 -type f -name "*.apk" | sort | head -n 1
            return 0
        fi
    fi

    local current_version_file="${APP_DIR}/current.version"
    if [ -f "${current_version_file}" ]; then
        local current_version
        current_version="$(tr -d '[:space:]' < "${current_version_file}")"
        if [ -n "${current_version}" ] && [ -d "${APP_DIR}/versions/${current_version}" ]; then
            find "${APP_DIR}/versions/${current_version}" -maxdepth 1 -type f -name "*.apk" | sort | head -n 1
            return 0
        fi
    fi

    find "${APP_DIR}/versions" -mindepth 2 -maxdepth 2 -type f -name "*.apk" | sort | tail -n 1
}

download_apk_if_needed() {
    local resolved_apk_path="$1"
    if [ -n "${resolved_apk_path}" ] && [ -f "${resolved_apk_path}" ]; then
        echo "${resolved_apk_path}"
        return 0
    fi

    if [ -z "${APK_URL:-}" ]; then
        return 1
    fi

    local target_version="${APP_VERSION}"
    if [ -z "${target_version}" ] || [ "${target_version}" = "latest" ]; then
        target_version="$(date +%Y%m%d-%H%M%S)"
    fi

    local target_dir="${APP_DIR}/versions/${target_version}"
    local target_file="${target_dir}/smobilpay-${target_version}.apk"

    mkdir -p "${target_dir}"
    echo "APK not found locally. Downloading ${APK_URL} into ${target_file}..."
    curl -L -o "${target_file}" "${APK_URL}"
    chmod 644 "${target_file}"
    printf '%s\n' "${target_version}" > "${APP_DIR}/current.version"

    echo "${target_file}"
}

collect_test_files() {
    local suite_file=""

    if [ -n "${TEST_PATH}" ]; then
        find "${TEST_PATH}" -type f -name "*.yaml" | sort
        return 0
    fi

    suite_file="${SUITES_DIR}/${TEST_SUITE}.txt"
    if [ -f "${suite_file}" ]; then
        while IFS= read -r entry; do
            [ -z "${entry}" ] && continue
            case "${entry}" in
                \#*) continue ;;
            esac

            if [ -d "${entry}" ]; then
                find "${entry}" -type f -name "*.yaml" | sort
            elif [ -f "${entry}" ]; then
                printf '%s\n' "${entry}"
            else
                echo "[WARN] Suite entry not found: ${entry}" >&2
            fi
        done < "${suite_file}"
        return 0
    fi

    find tests -type f -name "*.yaml" | sort
}

echo "Starting Maestro Test Runner Script..."
echo "Requested suite: ${TEST_SUITE}"
echo "Requested app version: ${APP_VERSION}"

adb connect "${DEVICE}"
sleep 2

echo "Waiting for device to boot..."
while [ "$(adb -s "${DEVICE}" shell getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
    echo "Device still booting..."
    sleep 5
done
echo "Device is ready."

mkdir -p "${APP_DIR}/versions" "${ALLURE_RESULTS_PATH}" "${JUNIT_RESULTS_PATH}"

APK_PATH="$(resolve_apk_path)"
if ! APK_PATH="$(download_apk_if_needed "${APK_PATH}")"; then
    echo "[ERROR] No APK found for APP_VERSION=${APP_VERSION}, and APK_URL was not provided."
    exit 1
fi
APP_VERSION="$(resolve_app_version "${APK_PATH}")"

echo "Using APK: ${APK_PATH}"
echo "Resolved app version: ${APP_VERSION}"

echo "Installing selected APK..."
adb -s "${DEVICE}" uninstall "${APP_PACKAGE}" >/dev/null 2>&1 || true
adb -s "${DEVICE}" install -r "${APK_PATH}"

if [ "${INSTALL_ONLY}" = "1" ]; then
    echo "Install-only mode enabled. Skipping test execution."
    exit 0
fi

rm -rf "${ALLURE_RESULTS_PATH:?}/"* "${JUNIT_RESULTS_PATH:?}/"* 2>/dev/null || true
mkdir -p "${ALLURE_RESULTS_PATH}" "${JUNIT_RESULTS_PATH}"
cat <<EOF > "${ALLURE_RESULTS_PATH}/environment.properties"
Device=${DEVICE}
AppId=${APP_PACKAGE}
Suite=${TEST_SUITE}
AppVersion=${APP_VERSION}
Environment=Development/WSL
EOF
cat <<EOF > "${ALLURE_RESULTS_PATH}/categories.json"
[
  {
    "name": "Maestro Assertions",
    "matchedStatuses": ["failed"],
    "messageRegex": ".*"
  },
  {
    "name": "Timeouts",
    "matchedStatuses": ["broken"],
    "messageRegex": ".*TIMED OUT.*"
  }
]
EOF

mapfile -t TEST_FILES < <(collect_test_files | awk 'NF' | sort -u)

if [ "${#TEST_FILES[@]}" -eq 0 ]; then
    echo "[ERROR] No tests found for suite '${TEST_SUITE}'."
    exit 1
fi

echo "Resolved ${#TEST_FILES[@]} test file(s)."

if [ "${DRY_RUN}" = "1" ]; then
    printf '%s\n' "${TEST_FILES[@]}"
    echo "Dry-run mode enabled. Skipping Maestro execution."
    exit 0
fi

EXIT_CODE=0

for test_file in "${TEST_FILES[@]}"; do
    echo "------------------------------------------------------------"
    echo "Running test: ${test_file}"

    test_name="$(basename "${test_file}" .yaml)"
    junit_xml="${JUNIT_RESULTS_PATH}/${test_name}.xml"

    maestro_args=(maestro --device "${DEVICE}")
    if [ "${MAESTRO_VERBOSE}" = "1" ]; then
        maestro_args+=(--verbose)
    fi

    test_args=(test "${test_file}")
    if [ -n "${MAESTRO_DEBUG_OUTPUT_DIR}" ]; then
        mkdir -p "${MAESTRO_DEBUG_OUTPUT_DIR}/${test_name}" || true
        test_args+=(--debug-output "${MAESTRO_DEBUG_OUTPUT_DIR}/${test_name}" --flatten-debug-output)
    fi

    if [ "${MAESTRO_FORMAT}" = "junit" ]; then
        test_args+=(--format junit --output "${junit_xml}")
    elif [ -n "${MAESTRO_FORMAT}" ] && [ "${MAESTRO_FORMAT}" != "none" ]; then
        test_args+=(--format "${MAESTRO_FORMAT}")
    fi

    timeout "${TEST_TIMEOUT}" "${maestro_args[@]}" "${test_args[@]}"
    RESULT=$?

    if [ -f "${junit_xml}" ]; then
        sed -i "s/name=\"Test Suite\"/name=\"${test_name}\"/g" "${junit_xml}"
        sed -i "s/classname=\"Flow\"/classname=\"${test_name}\"/g" "${junit_xml}"
    fi

    if [ "${RESULT}" -eq 124 ]; then
        echo "[ERROR] Test ${test_file} TIMED OUT after ${TEST_TIMEOUT}s"
        EXIT_CODE=1
    elif [ "${RESULT}" -ne 0 ]; then
        echo "[ERROR] Test ${test_file} FAILED with exit code ${RESULT}"
        EXIT_CODE=1

        if ! adb -s "${DEVICE}" shell getprop sys.boot_completed >/dev/null 2>&1; then
            echo "[CRITICAL] Device went offline. Attempting to reconnect..."
            adb connect "${DEVICE}"
            sleep 5
        fi
    else
        echo "[SUCCESS] Test ${test_file} PASSED"
    fi
done

if [ "${MAESTRO_FORMAT}" = "junit" ]; then
    echo "Converting JUnit XML to Allure results..."
    if [ -x "./scripts/junit_to_allure.sh" ]; then
        ./scripts/junit_to_allure.sh "${JUNIT_RESULTS_PATH}" "${ALLURE_RESULTS_PATH}" || true
    else
        echo "[WARN] Missing converter script ./scripts/junit_to_allure.sh; Allure results will not be generated." >&2
    fi
else
    echo "Skipping Allure conversion (MAESTRO_FORMAT=${MAESTRO_FORMAT})."
fi

echo "Fixing permissions for result folders..."
chmod -R 777 "${ALLURE_RESULTS_PATH}" "${JUNIT_RESULTS_PATH}" >/dev/null 2>&1 || true

echo "Test run finished with code ${EXIT_CODE}"
echo "JUnit results: ${JUNIT_RESULTS_PATH}"
echo "Allure results: ${ALLURE_RESULTS_PATH}"
exit "${EXIT_CODE}"
