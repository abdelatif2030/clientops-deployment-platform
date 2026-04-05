pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'eu-north-1'
        TF_IN_AUTOMATION = 'true'
        DOCKER_IMAGE = 'abdo1997mohamed2030/clientops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"
        ANSIBLE_VENV = '/opt/ansible-venv'
        PATH = "${ANSIBLE_VENV}/bin:${env.PATH}"
        SSH_KEY = '/var/jenkins_home/.ssh/terraform.pem'
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
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
                    ansible --version || echo "Ansible not found"
                    aws --version
                '''
            }
        }

        stage('Setup Ansible Venv') {
            steps {
                sh '''
                    if [ ! -d "$ANSIBLE_VENV" ]; then
                        python3 -m venv $ANSIBLE_VENV
                        source $ANSIBLE_VENV/bin/activate
                        pip install --upgrade pip
                        pip install ansible
                    fi
                    echo "=== Ansible version in venv ==="
                    $ANSIBLE_VENV/bin/ansible --version
                '''
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws']]) {
                    dir('terraform') {
                        sh '''
                            terraform init
                            terraform validate
                            terraform apply -auto-approve
                        '''
                    }
                }
            }
        }

        stage('Generate Inventory & Detect SSH User') {
            steps {
                sh '''
                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)

                    # Detect correct SSH user
                    SSH_USER="ubuntu"
                    ssh -i $SSH_KEY -o ConnectTimeout=5 $SSH_USER@$APP_IP 'echo ok' 2>/dev/null || SSH_USER="ec2-user"

                    echo "Using SSH_USER=$SSH_USER"

                    mkdir -p /var/jenkins_home/.ansible/tmp
                    cat > hosts.ini <<EOF
[app_servers]
$APP_IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY

[monitoring_servers]
$MONITOR_IP ansible_user=$SSH_USER ansible_ssh_private_key_file=$SSH_KEY

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

                    echo "=== Generated hosts.ini ==="
                    cat hosts.ini
                '''
            }
        }

        stage('Prepare SSH Known Hosts') {
            steps {
                sh '''
                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)
                    mkdir -p ~/.ssh
                    chmod 700 ~/.ssh
                    ssh-keyscan -H $APP_IP >> ~/.ssh/known_hosts
                    ssh-keyscan -H $MONITOR_IP >> ~/.ssh/known_hosts
                    chmod 644 ~/.ssh/known_hosts
                    echo "=== SSH known_hosts updated ==="
                '''
            }
        }

        stage('Wait for EC2 SSH') {
            steps {
                sh '''
                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)

                    echo "Waiting for SSH access..."
                    for i in {1..12}; do
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$APP_IP 'echo ok' && \
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONITOR_IP 'echo ok' && break
                        echo "SSH not ready yet, retrying 10s..."
                        sleep 10
                    done
                '''
            }
        }

        stage('Run Ansible Setup') {
            steps {
                sh '''
                    chmod 600 $SSH_KEY
                    $ANSIBLE_VENV/bin/ansible-playbook -i hosts.ini setup.yml \
                        --ssh-extra-args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
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
