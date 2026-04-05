pipeline {
    agent any

    environment {
        DOCKER_IMAGE = 'your-dockerhub-username/your-app'
        IMAGE_TAG = "${env.BUILD_NUMBER}"
    }

    stages {
        stage('Checkout SCM') {
            steps {
                checkout([$class: 'GitSCM',
                          branches: [[name: 'main']],
                          userRemoteConfigs: [[
                              url: 'https://github.com/abdelatif2030/clientops-deployment-platform.git',
                              credentialsId: 'github'
                          ]]
                ])
            }
        }

        stage('Verify Tools') {
            steps {
                sh '''
                echo "=== Checking installed tools ==="
                git --version
                python3 --version
                docker --version
                terraform version
                ansible --version
                aws --version
                '''
            }
        }

        stage('Terraform Init') {
            dir('terraform') {
                steps {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            dir('terraform') {
                steps {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Apply') {
            withCredentials([[
                $class: 'AmazonWebServicesCredentialsBinding',
                credentialsId: 'aws',
                accessKeyVariable: 'AWS_ACCESS_KEY_ID',
                secretKeyVariable: 'AWS_SECRET_ACCESS_KEY'
            ]]) {
                dir('terraform') {
                    steps {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Generate Inventory') {
            steps {
                script {
                    def app_ip = sh(script: "cd terraform && terraform output -raw app_server_public_ip", returnStdout: true).trim()
                    def mon_ip = sh(script: "cd terraform && terraform output -raw monitoring_server_public_ip", returnStdout: true).trim()

                    writeFile file: 'hosts.ini', text: """
[app_servers]
${app_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/var/jenkins_home/.ssh/terraform.pem

[monitoring_servers]
${mon_ip} ansible_user=ubuntu ansible_ssh_private_key_file=/var/jenkins_home/.ssh/terraform.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
"""
                    sh 'cat hosts.ini'
                }
            }
        }

        stage('Wait for EC2 SSH') {
            steps {
                echo "Waiting 60 seconds for EC2 instances to be ready..."
                sh 'sleep 60'
            }
        }

        stage('Run Ansible Setup') {
            steps {
                sh '''
                chmod 600 /var/jenkins_home/.ssh/terraform.pem
                export ANSIBLE_HOST_KEY_CHECKING=False
                /opt/ansible-venv/bin/ansible-playbook -i hosts.ini setup.yml
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                docker build -t $DOCKER_IMAGE:$IMAGE_TAG .
                docker tag $DOCKER_IMAGE:$IMAGE_TAG $DOCKER_IMAGE:latest
                '''
            }
        }

        stage('Push Docker Image to Docker Hub') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKERHUB_USER',
                    passwordVariable: 'DOCKERHUB_PASS'
                )]) {
                    sh '''
                    echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin
                    docker push $DOCKER_IMAGE:$IMAGE_TAG
                    docker push $DOCKER_IMAGE:latest
                    docker logout
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Full CI/CD pipeline completed successfully!'
        }
        failure {
            echo 'FAILED: Pipeline execution failed. Check the console output.'
        }
        always {
            echo 'Pipeline finished.'
        }
    }
}
