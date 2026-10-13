pipeline {
    agent { label 'risto-deploy' }

    stages {
        stage('test') {
            steps {
                sh '''
                    python3 -m venv .venv
                    .venv/bin/python -m pip install -r tests/requirements.txt
                    .venv/bin/python -m pytest -q tests/
                '''
            }

            post {
                success {
                    echo 'Test completati; passo allo step successivo'
                }
                failure {
                    echo 'Test falliti, interrompo pipeline'
                }
            }
        }

        stage('e2e') {
            // Minikube, build immagini, deploy e test di accettazione
            steps {
                withCredentials([string(
                    credentialsId: 'ristoqueue-api-key',
                    variable: 'API_KEY'
                )]) {
                    sh 'ansible-playbook ansible/site.yml'
                }
            }

            post {
                success {
                    echo 'Build, deploy e test di accettazione completati'
                }
                failure {
                    echo 'Build, deploy o test falliti, interrompo pipeline'
                }
            }
        }

        stage('publish') {
            when {
                expression {
                    def branch = env.BRANCH_NAME ?: env.GIT_BRANCH

                    return !env.CHANGE_ID &&
                        ['main', 'origin/main'].contains(branch)
                }
            }

            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'Cred_docker_marco',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_PASSWORD'
                )]) {
                    sh 'ansible-playbook ansible/publish.yml'
                }
            }

            post {
                success {
                    echo 'Test, build, deploy e publish completati'
                }
                failure {
                    echo 'Publish fallito'
                }
            }
        }
    }
}