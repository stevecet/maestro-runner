# Maestro Mobile Tests

This project provides a Dockerized Maestro setup for Android UI automation with a structure that separates:

- test cases in `tests/`
- reusable flows in `subflows/`
- test data in `data/`
- suite definitions in `config/suites/`
- versioned APKs in `app/versions/`

## Recommended Structure

```text
.
|-- app/
|   |-- current.version
|   `-- versions/
|       `-- 1.14.0/
|           `-- smobilpay-1.14.0.apk
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

## App Versioning

Instead of replacing `app/smobilpay.apk` every time, APKs are now stored by version:

```bash
make download-apk APP_VERSION=1.14.0 APK_URL=https://your-link/app.apk
make list-apps
```

That creates:

```text
app/versions/1.14.0/smobilpay-1.14.0.apk
```

The selected version is tracked in `app/current.version`, so regression on an older build becomes easier.

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
make test-docker TEST_SUITE=smoke APP_VERSION=1.14.0
```

Run a specific folder or a single test file:

```bash
make test-docker TEST_PATH=tests/cashin
make test-docker TEST_PATH=tests/00_login/successful_login.yaml
```

## Reporting (JUnit + Allure)

- JUnit XML is written to `junit-results/` (published by Jenkins via the `junit` step).
- Allure raw results are written to `allure-results/` by converting the JUnit XML into minimal Allure `*-result.json` files, so the Jenkins Allure plugin can render a report.

## Jenkins

The pipeline now accepts:

- `APP_VERSION`
- `TEST_SUITE`
- `TEST_PATH`
- `APK_URL`

This means Jenkins can run smoke on the latest app, or regression on a stored historical version, without changing files in the repository.

## Team Guidance

For future growth, keep using this convention:

- put executable Maestro cases under `tests/<domain>/`
- keep reusable sequences in `subflows/`
- keep static or generated test data in `data/`
- define business-friendly groupings in `config/suites/*.txt`
- store APKs by version under `app/versions/<version>/`

## Cleanup

```bash
make down
```
