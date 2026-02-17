pipeline {
    agent any

    environment {
        ALLURE_RESULTS_PATH = 'allure-results'
        TEST_PATH           = 'tests/00_login'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    // Use returnStatus: true to handle test failures without aborting the pipeline
                    def exitCode = sh(script: 'docker compose up --build maestro-runner', returnStatus: true)
                    
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
                // Publish Allure reports even if tests failed
                allure includeProperties: false, jdk: '', results: [[path: 'allure-results']]
                sh 'docker compose down'
            }
        }
    }
}
