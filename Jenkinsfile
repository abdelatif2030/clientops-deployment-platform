pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'eu-north-1'
        TF_IN_AUTOMATION = 'true'
        DOCKER_IMAGE = 'abdo1997mohamed2030/clientops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
    }

    options {
        timestamps()
    }

    stages {

        stage('Checkout Code') {
            steps {
                git branch: 'main',
                    credentialsId: 'github',
                    url: 'https://github.com/abdelatif2030/clientops-deployment-platform.git'
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
            steps {
                dir('terraform') {
                    sh 'terraform init'
                }
            }
        }

        stage('Terraform Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([[
                    $class: 'AmazonWebServicesCredentialsBinding',
                    credentialsId: 'aws'
                ]]) {
                    dir('terraform') {
                        sh 'terraform apply -auto-approve'
                    }
                }
            }
        }

        stage('Generate Inventory') {
            steps {
                sh '''
                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)

                    cat > hosts.ini <<EOF
[app_servers]
$APP_IP ansible_user=ubuntu ansible_ssh_private_key_file=/var/jenkins_home/.ssh/terraform.pem

[monitoring_servers]
$MONITOR_IP ansible_user=ubuntu ansible_ssh_private_key_file=/var/jenkins_home/.ssh/terraform.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

                    echo "=== Generated hosts.ini ==="
                    cat hosts.ini
                '''
            }
        }

        stage('Wait for EC2 SSH') {
            steps {
                sh '''
                    echo "Waiting 60 seconds for EC2 instances to be ready..."
                    sleep 60
                '''
            }
        }

        stage('Run Ansible Setup') {
            steps {
                sh '''
                    chmod 600 /var/jenkins_home/.ssh/terraform.pem
                    ansible-playbook -i hosts.ini setup.yml
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    echo "=== Building Docker image ==="
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
                        echo "=== Logging in to Docker Hub ==="
                        echo "$DOCKERHUB_PASS" | docker login -u "$DOCKERHUB_USER" --password-stdin

                        echo "=== Pushing Docker images ==="
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
