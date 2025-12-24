# Maestro Mobile Tests

This project provides a Dockerized environment for running mobile UI automation tests using [Maestro](https://maestro.mobile.dev/). It includes an Android emulator and a test runner.

## Prerequisites

Before running the project, ensure you have the following installed on your machine:

- **Docker** & **Docker Compose**: To run the emulator and tests in containers.
- **Make**: To use the simplified commands.
- **ADB (Android Debug Bridge)**: To connect to the emulator and install the APK (`sudo apt-get install android-tools-adb` on Linux).
- **Curl**: To download the test APK.

## Configuration

Test credentials and other data are located in the `data/` directory.

- **User Credentials**: Edit `data/login/user.js` to update test user credentials.

## Getting Started

### 1. Start the Environment & Install App

Use the following command to start the Android Emulator, download the test APK, and install it onto the emulator.

```bash
make start
```

- **What this does**:
  - Starts the `android-emulator` container.
  - Waits for the emulator to be ready.
  - Downloads the target APK (`smobilpay.apk`) to the `app/` directory (if not already present).
  - Connects your local `adb` to the containerized emulator.
  - Installs the APK.

### 2. Run Tests

#### Option A: Run in Docker (Recommended)

Run the tests inside a throwaway container that connects to the emulator.

```bash
make test-docker
```

- This builds the `maestro-runner` image and executes the tests defined in `tests/`.

#### Option B: Run Locally

If you have the Maestro CLI installed on your host machine, you can run:

```bash
make run-tests
```

### 3. Stop & Cleanup

To stop the containers and free up resources:

```bash
make stop
```
