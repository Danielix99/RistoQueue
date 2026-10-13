pipeline {
    agent { label 'risto-deploy'}

    stages {
        stage('test') {
            //test unitari con pytest
            steps {
                sh '''
                python3 -m venv .venv
                .venv/bin/python -m pip install -r tests/requirements.txt
                .venv/bin/python -m pytest -q tests/
                '''
            }
        

            post {
                success {
                    echo 'Test completato; passo allo step successivo'
                }
                failure {
                    echo 'Test fallito, interrompo pipeline'
                }
            }
        }

        stage ('e2e') {
            //build delle immagini, cluster kind dentro la pipeline, deploy, tests/acceptance.sh
            steps {
                withCredentials([string(
                    credentialsId: 'ristoqueue-api-key',
                    variable: 'API_KEY'
                )]) { 
                sh 'ansible-playbook ansible/site.yml'
            }
        

            post {
                success {
                    echo 'Build, cluster e deploy completati; passo allo step successivo'
                }
                failure {
                    echo 'Build, deploy o cluster fallito, interrompo pipeline'
                }
            }
        }

        stage('publish') {
            when {
                allOf {
                    branch 'main'
                    not { changeRequest() }
                }
            }

            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'ghcr',
                    usernameVariable: 'GHCR_USER',
                    passwordVariable: 'GHCR_TOKEN'
                )]) {
                    sh 'ansible-playbook ansible/publish.yml'
                }
            }
            post {
                success {
                    echo 'Test, build, deploy e publish completati.'
                }
                failure {
                    echo 'Publish fallito, interrompo pipeline'
                }
            }
        }
    }
}