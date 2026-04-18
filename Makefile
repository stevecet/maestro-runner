APK_ROOT := app
APK_VERSIONS_DIR := $(APK_ROOT)/versions
APP_VERSION ?= latest
APK_URL ?= https://expo.dev/artifacts/eas/czMwkPWpEviGGfVSv9XCka.apk
TEST_SUITE ?= regression
TEST_PATH ?=
DEVICE ?= localhost:5555

pull:
	docker compose pull

download-apk:
	@VERSION="$(APP_VERSION)"; \
	if [ "$$VERSION" = "latest" ]; then VERSION="$$(date +%Y%m%d-%H%M%S)"; fi; \
	TARGET_DIR="$(APK_VERSIONS_DIR)/$$VERSION"; \
	TARGET_FILE="$$TARGET_DIR/smobilpay-$$VERSION.apk"; \
	echo "Preparing versioned APK folder $$TARGET_DIR"; \
	mkdir -p "$$TARGET_DIR"; \
	echo "Downloading APK for version $$VERSION"; \
	curl -L -o "$$TARGET_FILE" "$(APK_URL)"; \
	chmod 644 "$$TARGET_FILE"; \
	printf '%s\n' "$$VERSION" > "$(APK_ROOT)/current.version"; \
	echo "APK stored at $$TARGET_FILE"

list-apps:
	@echo "Available app versions:"; \
	if [ -d "$(APK_VERSIONS_DIR)" ]; then find "$(APK_VERSIONS_DIR)" -mindepth 1 -maxdepth 1 -type d | sort; else echo "No versioned APKs stored yet."; fi; \
	if [ -f "$(APK_ROOT)/current.version" ]; then echo "Current version: $$(cat $(APK_ROOT)/current.version)"; fi

up: pull
	docker compose up -d android-emulator
	@echo "Waiting for containers to initialize..."
	sleep 90
	docker compose ps

start: up
	adb connect $(DEVICE)
	APP_VERSION=$(APP_VERSION) APK_URL="$(APK_URL)" DEVICE=$(DEVICE) INSTALL_ONLY=1 docker compose run --rm maestro-runner

install-app:
	adb connect $(DEVICE)
	APP_VERSION=$(APP_VERSION) APK_URL="$(APK_URL)" DEVICE=$(DEVICE) INSTALL_ONLY=1 docker compose run --rm maestro-runner

run-tests:
	TEST_SUITE=$(TEST_SUITE) TEST_PATH=$(TEST_PATH) APP_VERSION=$(APP_VERSION) APK_URL="$(APK_URL)" maestro --device $(DEVICE) test $${TEST_PATH:-tests}

test-docker:
	TEST_SUITE=$(TEST_SUITE) TEST_PATH=$(TEST_PATH) APP_VERSION=$(APP_VERSION) APK_URL="$(APK_URL)" docker compose up --build maestro-runner

dry-run:
	TEST_SUITE=$(TEST_SUITE) TEST_PATH=$(TEST_PATH) APP_VERSION=$(APP_VERSION) APK_URL="$(APK_URL)" DRY_RUN=1 docker compose run --rm maestro-runner

down:
	docker compose down
