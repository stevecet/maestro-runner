APK_DIR := app
APK_NAME := smobilpay.apk
APK_PATH := app/smobilpay.apk
APK_URL := https://expo.dev/artifacts/eas/9tP2bG2ePDt1fHku7tTgiL.apk

EMULATOR_CONTAINER := android-emulator
EMULATOR_IP := $(shell docker inspect -f '{{range.NetworkSettings.Networks}}{{.IPAddress}}{{end}}' $(EMULATOR_CONTAINER))
ADB_DEVICE := $(EMULATOR_IP):5555

# Setup

pull:
	docker compose pull

up: pull
	docker compose up -d android-emulator wiremock
	@echo "Waiting for containers to initialize..."
	sleep 10
	docker compose ps

down:
	docker compose down

restart: down start

# APK

download-apk:
	@echo "Checking APK..."
	@if [ ! -d "$(APK_DIR)" ]; then \
		echo "Creating $(APK_DIR) directory"; \
		mkdir -p "$(APK_DIR)"; \
	fi
	@if [ ! -f "$(APK_PATH)" ]; then \
		echo "⬇ Downloading latest APK..."; \
		curl -L -o "$(APK_PATH)" "$(APK_URL)"; \
		chmod 644 "$(APK_PATH)"; \
	else \
		echo "APK already exists at $(APK_PATH)"; \
	fi

# ADB / Emulator

reset-adb:
	@echo "Resetting host ADB..."
	@adb kill-server || true
	@adb start-server

wait-for-emulator:
	@echo "Waiting for emulator to finish booting..."
	@until docker exec $(EMULATOR_CONTAINER) adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; do \
		sleep 5; \
	done
	@echo "Emulator booted"

adb-devices:
	@adb devices -l

# Test Flow

start: up download-apk wait-for-emulator reset-adb
	@echo "Connecting to emulator at $(ADB_DEVICE)..."
	adb connect $(ADB_DEVICE)
	adb -s $(ADB_DEVICE) install -r $(APK_PATH)
	maestro --device $(ADB_DEVICE) test tests/login/successful_login.yaml

run-tests:
	find tests -name "*.yaml" -print0 | xargs -0 maestro --device $(ADB_DEVICE) test

# Docker-only tests

test-docker:
	docker compose up --build maestro-runner