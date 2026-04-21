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
{"uuid":"${test_uuid}","name":"${name_e}","fullName":"${full_name_e}","status":"${status}","stage":"finished","start":${start},"stop":${stop},"statusDetails":{"message":"${message_e}","trace":"${message_e}"},"labels":[{"name":"suite","value":"${suite_e}"},{"name":"package","value":"${package_e}"}]}
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
  in_failure=0
  failure_tag=""

  while IFS= read -r line; do
    case "${line}" in
      *"<testcase "*)
        current_name="$(printf '%s' "${line}" | sed -n 's/.*name="\([^"]*\)".*/\1/p')"
        current_classname="$(printf '%s' "${line}" | sed -n 's/.*classname="\([^"]*\)".*/\1/p')"
        current_status="passed"
        current_message=""
        in_failure=0
        failure_tag=""

        # Self-closing testcase tag — write immediately.
        if printf '%s' "${line}" | grep -q "/>"; then
          test_uuid="$(uuid)"
          full_name="${current_classname:+${current_classname}.}${current_name}"
          write_result "${test_uuid}" "${current_name:-${suite}}" "${full_name:-${suite}}" "${current_status}" "${suite}" "${current_classname:-${suite}}"
          current_name=""
          current_classname=""
        fi
        ;;

      *"<failure"*|*"<error"*)
        # Determine status
        if printf '%s' "${line}" | grep -q "<failure"; then
          current_status="failed"
          failure_tag="failure"
        else
          current_status="broken"
          failure_tag="error"
        fi

        # 1. Try message= attribute on this line
        current_message="$(printf '%s' "${line}" | sed -n 's/.*message="\([^"]*\)".*/\1/p')"

        # 2. Try inline text content: <failure>text</failure> on same line
        if [ -z "${current_message}" ]; then
          current_message="$(printf '%s' "${line}" | sed -n "s|.*<${failure_tag}[^>]*>\(.*\)</${failure_tag}>.*|\1|p")"
        fi

        # 3. If the closing tag is NOT on this line, we will accumulate content next lines
        if printf '%s' "${line}" | grep -q "</${failure_tag}>"; then
          in_failure=0
        else
          in_failure=1
        fi
        ;;

      *"</failure>"*|*"</error>"*)
        if [ "${in_failure}" -eq 1 ]; then
          # Capture any trailing text before the closing tag on this line
          local_content="$(printf '%s' "${line}" | sed "s|</[^>]*>.*||" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
          if [ -z "${current_message}" ] && [ -n "${local_content}" ]; then
            current_message="${local_content}"
          fi
          in_failure=0
        fi
        ;;

      *"</testcase>"*)
        test_uuid="$(uuid)"
        full_name="${current_classname:+${current_classname}.}${current_name}"
        write_result "${test_uuid}" "${current_name:-${suite}}" "${full_name:-${suite}}" "${current_status}" "${suite}" "${current_classname:-${suite}}" "${current_message}"
        current_name=""
        current_classname=""
        current_status="passed"
        current_message=""
        in_failure=0
        failure_tag=""
        ;;

      *)
        # Accumulate text lines inside a <failure> or <error> block
        if [ "${in_failure}" -eq 1 ] && [ -z "${current_message}" ]; then
          trimmed="$(printf '%s' "${line}" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')"
          if [ -n "${trimmed}" ]; then
            current_message="${trimmed}"
          fi
        fi
        ;;
    esac
  done < "${xml}"
done

echo "Generated Allure result JSON files in ${ALLURE_DIR} from ${JUNIT_DIR}."
