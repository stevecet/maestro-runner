# Maestro Mobile Tests

This project provides a Dockerized Maestro setup for Android UI automation with a structure that separates:

- test cases in `tests/`
- reusable flows in `subflows/`
- test data in `data/`
- suite definitions in `config/suites/`
- the APK under `app/smobilpay.apk`

## Recommended Structure

```text
.
|-- app/
|   `-- smobilpay.apk
|-- config/
|   `-- suites/
|       |-- smoke.txt
|       |-- login.txt
|       |-- payments.txt
|       `-- regression.txt
|-- data/
|-- subflows/
`-- tests/
```

The suite files list folders or individual test files. This lets us group cases into smoke, regression, payments, or any future business suite without moving your current Maestro flows.

## App APK

The APK is not committed to Git. Download the app build used for testing:

```bash
make download-apk APK_URL=https://your-link/app.apk
```

This stores the APK at `app/smobilpay.apk`. Running the test commands also downloads it automatically when it is missing and `APK_URL` is available.

## Running Tests

Start the emulator:

```bash
make up
```

Run the default regression suite in Docker:

```bash
make test-docker
```

Show step-by-step execution output (verbose):

```bash
make test-docker MAESTRO_VERBOSE=1
```

Collect per-test debug output (screenshots/logs) into a folder:

```bash
make test-docker MAESTRO_DEBUG_OUTPUT_DIR=maestro-debug
```

Run a specific suite:

```bash
make test-docker TEST_SUITE=smoke
```

Run a specific folder or a single test file:

```bash
make test-docker TEST_PATH=tests/cashin
make test-docker TEST_PATH=tests/00_login/successful_login.yaml
```

## Reporting (JUnit + Allure)

- JUnit XML is written to `junit-results/` (published by Jenkins via the `junit` step).
- Allure raw results are written to `allure-results/` by converting the JUnit XML into minimal Allure `*-result.json` files, so the Jenkins Allure plugin can render a report.

## Jenkins Workspace Permissions

If Jenkins fails during `checkout scm` with permission errors under `app/`, it usually means a previous Docker run wrote root-owned files into the workspace.

This repo configures the `maestro-runner` container to run as the Jenkins agent user (`DOCKER_UID/DOCKER_GID`) and mounts the repository read-only to prevent future permission drift.

## Jenkins

The pipeline accepts:

- `TEST_SUITE`
- `TEST_PATH`
- `APK_URL`

Jenkins uses `app/smobilpay.apk` when present, or downloads it from `APK_URL`.

## Team Guidance

For future growth, keep using this convention:

- put executable Maestro cases under `tests/<domain>/`
- keep reusable sequences in `subflows/`
- keep static or generated test data in `data/`
- define business-friendly groupings in `config/suites/*.txt`
- replace `app/smobilpay.apk` when switching to a different app build

## Cleanup

```bash
make down
```
