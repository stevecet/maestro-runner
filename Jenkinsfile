pipeline {
    agent any

    environment {
        ALLURE_RESULTS_PATH = 'allure-results'
    }

    options {
        // Prevent Jenkins from doing the implicit "Declarative: Checkout SCM" before our stages.
        // This lets us fix workspace permissions first when previous Docker runs left root-owned files behind.
        skipDefaultCheckout(true)
    }

    parameters {
        string(name: 'APP_VERSION', defaultValue: 'latest', description: 'APK version folder from app/versions to install before tests')
        choice(name: 'TEST_SUITE', choices: ['smoke', 'login', 'payments', 'selftopup', 'regression'], description: 'Suite manifest to execute')
        string(name: 'TEST_PATH', defaultValue: '', description: 'Optional test file or folder override. Leave empty to use TEST_SUITE.')
        string(name: 'APK_URL', defaultValue: 'https://expo.dev/artifacts/eas/pNjGzRbdX8ftuNhJFBv3QG.apk', description: 'Optional APK URL used when the selected version is not stored locally')
    }

    stages {
        stage('Workspace Permissions') {
            steps {
                script {
                    // Previous docker runs can leave root-owned artifacts in the workspace (e.g. app/current.version),
                    // which can break subsequent `checkout scm`.
                    def uid = sh(script: 'id -u', returnStdout: true).trim()
                    def gid = sh(script: 'id -g', returnStdout: true).trim()

                    // Use a tiny container as root to fix ownership in the mounted workspace.
                    // Keep this resilient: if docker is unavailable, checkout will likely fail anyway.
                    sh(
                        script: """
                          set +e
                          docker run --rm -v "\$PWD":/ws alpine:3.19 sh -lc '
                            mkdir -p /ws/app /ws/allure-results /ws/junit-results
                            chown -R ${uid}:${gid} /ws/app /ws/allure-results /ws/junit-results || true
                            chmod -R u+rwX /ws/app /ws/allure-results /ws/junit-results || true
                          '
                        """,
                        returnStatus: true
                    )
                }
            }
        }

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    def uid = sh(script: 'id -u', returnStdout: true).trim()
                    def gid = sh(script: 'id -g', returnStdout: true).trim()
                    def runnerEnv = [
                        "APP_VERSION=${params.APP_VERSION}",
                        "TEST_SUITE=${params.TEST_SUITE}",
                        "TEST_PATH=${params.TEST_PATH}",
                        "APK_URL=${params.APK_URL}",
                        "DOCKER_UID=${uid}",
                        "DOCKER_GID=${gid}"
                    ].join(' ')

                    // Use returnStatus: true to handle test failures without aborting the pipeline
                    def exitCode = sh(script: "${runnerEnv} docker compose up --build maestro-runner", returnStatus: true)
                    
                    if (exitCode != 0) {
                        currentBuild.result = 'UNSTABLE'
                        echo "Tests failed with exit code ${exitCode}. Marking build as UNSTABLE."
                    } else {
                        echo "Tests passed successfully."
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                junit testResults: 'junit-results/*.xml', allowEmptyResults: true
                allure includeProperties: false, jdk: '', results: [[path: 'allure-results']]
                sh 'docker compose down'
            }
        }
    }
}
