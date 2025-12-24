APK_DIR := app
APK_NAME := smobilpay.apk
APK_PATH := app/smobilpay.apk	
APK_URL := https://expo.dev/artifacts/eas/uXov38MZuEoUS2qt1azMHS.apk

# 0. Check if the app directory exists and download the latest version
download-apk:
	@echo "Checking APK directory..."
	if [ ! -d "$(APK_DIR)" ]; then \
		echo "Creating $(APK_DIR) directory"; \
		mkdir -p "$(APK_DIR)"; \
	else \
		echo "$(APK_DIR) folder already exists"; \
	fi

	@echo "⬇Downloading latest APK..."
	curl -L -o "$(APK_DIR)/$(APK_NAME)" "$(APK_URL)"

	@echo "Setting permissions..."
	chmod 644 "$(APK_DIR)/$(APK_NAME)"

	@echo "APK is ready at $(APK_DIR)/$(APK_NAME)"


# 1. Start the containers and wait for it to be ready
up:
	docker compose up -d

	@echo "Waiting for containers to initialize..."
	sleep 90

	docker compose ps

# 2. Install the APK into the running emulator container
start: up download-apk
	adb connect localhost:5555
	adb -s localhost:5555 install $(APK_PATH)

# 3. Run the Maestro tests
run-tests:
	maestro --device localhost:5555 test tests

# 4. Run tests in Docker
test-docker:
	docker compose up --build maestro-runner

# 5. Clean up
down:
	docker compose down