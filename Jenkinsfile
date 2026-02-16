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

        stage('Prepare Environment') {
            steps {
                sh 'make download-apk'
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    try {
                        sh 'make test-docker'
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
            }
            sh 'make down'
        }
    }
}
