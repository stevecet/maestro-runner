#!/bin/bash
set -euo pipefail

JUNIT_DIR="${1:-junit-results}"
ALLURE_DIR="${2:-allure-results}"

if [ ! -d "${JUNIT_DIR}" ]; then
  echo "[WARN] JUnit directory not found: ${JUNIT_DIR}" >&2
  exit 0
fi

mkdir -p "${ALLURE_DIR}"

uuid() {
  if [ -r /proc/sys/kernel/random/uuid ]; then
    cat /proc/sys/kernel/random/uuid
  elif command -v uuidgen >/dev/null 2>&1; then
    uuidgen
  else
    date +%s%N
  fi
}

now_ms() {
  date +%s%3N 2>/dev/null || echo $(( $(date +%s) * 1000 ))
}

json_escape() {
  # Minimal JSON escaping for strings.
  # shellcheck disable=SC2001
  printf '%s' "$1" | sed \
    -e 's/\\/\\\\/g' \
    -e 's/"/\\"/g' \
    -e 's/\r//g' \
    -e ':a;N;$!ba;s/\n/\\n/g'
}

write_result() {
  local test_uuid="$1"
  local name="$2"
  local full_name="$3"
  local status="$4"
  local suite="$5"
  local package="$6"
  local message="${7:-}"

  local start stop
  start="$(now_ms)"
  stop="${start}"

  local name_e full_name_e suite_e package_e message_e
  name_e="$(json_escape "${name}")"
  full_name_e="$(json_escape "${full_name}")"
  suite_e="$(json_escape "${suite}")"
  package_e="$(json_escape "${package}")"
  message_e="$(json_escape "${message}")"

  local out_file="${ALLURE_DIR}/${test_uuid}-result.json"

  if [ -n "${message}" ]; then
    cat > "${out_file}" <<EOF
{"uuid":"${test_uuid}","name":"${name_e}","fullName":"${full_name_e}","status":"${status}","stage":"finished","start":${start},"stop":${stop},"statusDetails":{"message":"${message_e}"},"labels":[{"name":"suite","value":"${suite_e}"},{"name":"package","value":"${package_e}"}]}
EOF
  else
    cat > "${out_file}" <<EOF
{"uuid":"${test_uuid}","name":"${name_e}","fullName":"${full_name_e}","status":"${status}","stage":"finished","start":${start},"stop":${stop},"labels":[{"name":"suite","value":"${suite_e}"},{"name":"package","value":"${package_e}"}]}
EOF
  fi
}

for xml in "${JUNIT_DIR}"/*.xml; do
  [ -f "${xml}" ] || continue

  suite="$(sed -n 's/.*<testsuite[^>]*name="\([^"]*\)".*/\1/p' "${xml}" | head -n 1)"
  [ -n "${suite}" ] || suite="$(basename "${xml}" .xml)"

  # Parse testcases. If a file has no <testcase>, treat the suite as a single test.
  if ! grep -q "<testcase" "${xml}"; then
    test_uuid="$(uuid)"
    write_result "${test_uuid}" "${suite}" "${suite}" "broken" "${suite}" "${suite}" "No <testcase> found in JUnit XML"
    continue
  fi

  current_name=""
  current_classname=""
  current_status="passed"
  current_message=""

  while IFS= read -r line; do
    case "${line}" in
      *"<testcase "*)
        current_name="$(printf '%s' "${line}" | sed -n 's/.*name="\([^"]*\)".*/\1/p')"
        current_classname="$(printf '%s' "${line}" | sed -n 's/.*classname="\([^"]*\)".*/\1/p')"
        current_status="passed"
        current_message=""

        # Self-closing testcase tag.
        if printf '%s' "${line}" | grep -q "/>"; then
          test_uuid="$(uuid)"
          full_name="${current_classname:+${current_classname}.}${current_name}"
          write_result "${test_uuid}" "${current_name:-${suite}}" "${full_name:-${suite}}" "${current_status}" "${suite}" "${current_classname:-${suite}}"
          current_name=""
          current_classname=""
        fi
        ;;
      *"<failure"*|*"<error"*)
        if printf '%s' "${line}" | grep -q "<failure"; then
          current_status="failed"
        else
          current_status="broken"
        fi
        current_message="$(printf '%s' "${line}" | sed -n 's/.*message="\([^"]*\)".*/\1/p')"
        ;;
      *"</testcase>"*)
        test_uuid="$(uuid)"
        full_name="${current_classname:+${current_classname}.}${current_name}"
        write_result "${test_uuid}" "${current_name:-${suite}}" "${full_name:-${suite}}" "${current_status}" "${suite}" "${current_classname:-${suite}}" "${current_message}"
        current_name=""
        current_classname=""
        current_status="passed"
        current_message=""
        ;;
    esac
  done < "${xml}"
done

echo "Generated Allure result JSON files in ${ALLURE_DIR} from ${JUNIT_DIR}."
