APK_ROOT := app
APK_PATH := $(APK_ROOT)/smobilpay.apk
APK_URL ?= https://expo.dev/artifacts/eas/a_SbXg_Oq_iLv9mZFdCKroUcMq23onlkT4A-uGL3wrM.apk
TEST_SUITE ?= regression
TEST_PATH ?=
DEVICE ?= localhost:5555
MAESTRO_VERBOSE ?= 0
MAESTRO_FORMAT ?= junit
MAESTRO_DEBUG_OUTPUT_DIR ?=

pull:
	docker compose pull

download-apk:
	mkdir -p "$(APK_ROOT)"
	curl -L -o "$(APK_PATH)" "$(APK_URL)"
	chmod 644 "$(APK_PATH)"
	echo "APK stored at $(APK_PATH)"

up: pull
	docker compose up -d android-emulator
	@echo "Waiting for containers to initialize..."
	sleep 90
	docker compose ps

start: up 
	APK_URL="$(APK_URL)" DEVICE=android-emulator:5555 INSTALL_ONLY=1 docker compose run --rm maestro-runner

install-app:
	APK_URL="$(APK_URL)" DEVICE=android-emulator:5555 INSTALL_ONLY=1 docker compose run --rm maestro-runner

run-tests:
	TEST_SUITE=$(TEST_SUITE) TEST_PATH=$(TEST_PATH) APK_URL="$(APK_URL)" maestro --device $(DEVICE) test $${TEST_PATH:-tests}

test-docker:
	TEST_SUITE=$(TEST_SUITE) TEST_PATH=$(TEST_PATH) APK_URL="$(APK_URL)" MAESTRO_VERBOSE=$(MAESTRO_VERBOSE) MAESTRO_FORMAT=$(MAESTRO_FORMAT) MAESTRO_DEBUG_OUTPUT_DIR="$(MAESTRO_DEBUG_OUTPUT_DIR)" docker compose up --build maestro-runner

dry-run:
	TEST_SUITE=$(TEST_SUITE) TEST_PATH=$(TEST_PATH) APK_URL="$(APK_URL)" DRY_RUN=1 docker compose run --rm maestro-runner

down:
	docker compose down
