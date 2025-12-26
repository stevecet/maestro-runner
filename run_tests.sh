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

# 3. Ensure APK is installed
echo "Checking APK installation..."
if ! adb -s $DEVICE shell pm list packages | grep com.smobilpayagentapp; then
    echo "Installing APK..."
    adb -s $DEVICE install /app/app/smobilpay.apk
else
    echo "APK already installed."
fi

# 4. Run tests
echo "Finding all .yaml tests..."
TEST_FILES=$(find tests -name "*.yaml" -not -path "*/login/*")

EXIT_CODE=0

for test_file in $TEST_FILES; do
    echo "------------------------------------------------------------"
    echo "Running test: $test_file"
    
    # Run maestro with a timeout
    timeout $TEST_TIMEOUT maestro --device $DEVICE test "$test_file"
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
