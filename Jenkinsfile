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
                script {
                    if (isUnix()) {
                        sh 'make download-apk'
                    } else {
                        bat 'make download-apk'
                    }
                }
            }
        }

        stage('Run Tests') {
            steps {
                script {
                    try {
                        if (isUnix()) {
                            sh 'make test-docker'
                        } else {
                            bat 'make test-docker'
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
                    sh 'make down'
                } else {
                    bat 'make down'
                }
            }
        }
    }
}
