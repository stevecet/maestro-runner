#!/bin/bash

# Configuration
DEVICE="android-emulator:5555"
TEST_TIMEOUT=600 # 10 minutes timeout per test file

echo "Starting Maestro Test Runner Script..."

# 1. Connect to ADB
adb connect $DEVICE
sleep 2

# 2. Wait for device to be ready
echo "Waiting for device to boot..."
while [ "$(adb -s $DEVICE shell getprop sys.boot_completed | tr -d '\r')" != "1" ]; do
    echo "Device still booting..."
    sleep 5
done
echo "Device is ready."

# 3. Ensure APK is ready
echo "Checking APK file..."
APK_PATH="/app/app/smobilpay.apk"
if [ ! -f "$APK_PATH" ]; then
    echo "APK not found. Downloading from $APK_URL..."
    mkdir -p /app/app
    curl -L -o "$APK_PATH" "$APK_URL"
    chmod 644 "$APK_PATH"
fi

echo "Checking APK installation..."
if ! adb -s $DEVICE shell pm list packages | grep com.smobilpayagentapp; then
    echo "Installing APK..."
    adb -s $DEVICE install "$APK_PATH"
else
    echo "APK already installed."
fi

# 4. Run tests
echo "Finding all .yaml tests..."
# Clear previous allure results
rm -rf allure-results/*
mkdir -p allure-results

TEST_FILES=$(find ${TEST_PATH:-tests} -name "*.yaml" | sort)

EXIT_CODE=0

for test_file in $TEST_FILES; do
    echo "------------------------------------------------------------"
    echo "Running test: $test_file"
    
    # Clear previous results for this test file if necessary, 
    # but maestro --format allure --output allure-results usually appends/manages it.
    # However, to avoid mixing old results from different runs, we might want to clear the whole directory at the start.
    
    # Run maestro with a timeout and JUnit reporting (which Allure can consume)
    test_name=$(basename "$test_file" .yaml)
    timeout $TEST_TIMEOUT maestro --device $DEVICE test "$test_file" --format junit --output "allure-results/${test_name}.xml"
    RESULT=$?
    
    if [ $RESULT -eq 124 ]; then
        echo "[ERROR] Test $test_file TIMED OUT after ${TEST_TIMEOUT}s"
        EXIT_CODE=1
    elif [ $RESULT -ne 0 ]; then
        echo "[ERROR] Test $test_file FAILED with exit code $RESULT"
        EXIT_CODE=1
        
        # Check if device went offline
        if ! adb -s $DEVICE shell getprop sys.boot_completed >/dev/null 2>&1; then
            echo "[CRITICAL] Device went offline. Attempting to reconnect..."
            adb connect $DEVICE
            sleep 5
        fi
    else
        echo "[SUCCESS] Test $test_file PASSED"
    fi
done

echo "Test run finished with code $EXIT_CODE"
exit $EXIT_CODE
