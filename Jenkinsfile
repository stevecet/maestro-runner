pipeline {
    agent any

    environment {
        ALLURE_RESULTS_PATH = 'allure-results'
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
                    try {
                        if (isUnix()) {
                            sh 'docker compose up --build maestro-runner'
                        } else {
                            bat 'docker compose up --build maestro-runner'
                        }
                    } catch (e) {
                        currentBuild.result = 'UNSTABLE'
                    }
                }
            }
        }
    }

    post {
        always {
            script {
                allure includeProperties: false, jdk: '', results: [[path: 'allure-results']]
                if (isUnix()) {
                    sh 'docker compose down'
                } else {
                    bat 'docker compose down'
                }
            }
        }
    }
}
