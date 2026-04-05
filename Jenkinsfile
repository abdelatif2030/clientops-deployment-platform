pipeline {
    agent any
    environment {
        AWS_ACCESS_KEY_ID = credentials('aws_access_key_id')
        AWS_SECRET_ACCESS_KEY = credentials('aws_secret_access_key')
        DOCKER_IMAGE = 'myapp'       // Change this to your Docker image name
        IMAGE_TAG = 'latest'
    }
    stages {
        stage('Terraform Init & Validate') {
            steps {
                dir('terraform') {
                    sh 'terraform init'
                    sh 'terraform validate'
                }
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    sh 'terraform apply -auto-approve'
                }
            }
        }

        stage('Generate Inventory') {
            steps {
                dir('terraform') {
                    script {
                        APP_IP = sh(script: "terraform output -raw app_server_public_ip", returnStdout: true).trim()
                        MONITOR_IP = sh(script: "terraform output -raw monitoring_server_public_ip", returnStdout: true).trim()
                        sh """
                        mkdir -p /var/jenkins_home/.ansible/tmp
                        cat > hosts.ini <<EOF
[app_servers]
$APP_IP ansible_user=ubuntu ansible_ssh_private_key_file=/var/jenkins_home/.ssh/terraform.pem

[monitoring_servers]
$MONITOR_IP ansible_user=ubuntu ansible_ssh_private_key_file=/var/jenkins_home/.ssh/terraform.pem

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF
                        """
                    }
                }
            }
        }

        stage('Wait for EC2 SSH') {
            steps {
                echo "Waiting 60 seconds for EC2 instances to be ready..."
                sleep 60
            }
        }

        stage('Add EC2 Host Keys') {
            steps {
                script {
                    sh """
                    ssh-keyscan -H ${APP_IP} >> /var/jenkins_home/.ssh/known_hosts
                    ssh-keyscan -H ${MONITOR_IP} >> /var/jenkins_home/.ssh/known_hosts
                    """
                }
            }
        }

        stage('Run Ansible Setup') {
            steps {
                sh '''
                chmod 600 /var/jenkins_home/.ssh/terraform.pem
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
