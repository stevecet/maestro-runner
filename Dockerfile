# Use Eclipse Temurin Java 17 as the base (OpenJDK is deprecated)
FROM eclipse-temurin:17-jdk-jammy

# Set environment variables
ENV MAESTRO_VERSION=1.39.2
ENV ANDROID_HOME=/opt/android-sdk
ENV PATH="${PATH}:/opt/maestro/maestro/bin:${ANDROID_HOME}/platform-tools"

# Install dependencies: curl, unzip, and android-tools (for adb)
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    wget \
    android-tools-adb \
    && rm -rf /var/lib/apt/lists/*

# Install Maestro CLI
RUN mkdir -p /opt/maestro && \
    wget -q -O /tmp/maestro.zip "https://github.com/mobile-dev-inc/maestro/releases/download/cli-${MAESTRO_VERSION}/maestro.zip" && \
    unzip -q /tmp/maestro.zip -d /opt/maestro && \
    rm /tmp/maestro.zip

# Set the working directory for your tests
WORKDIR /app

# Copy your local flows and .apk into the container
COPY . .

# Keep the container alive or run a default command
CMD ["maestro", "--version"]