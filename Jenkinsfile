pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'eu-north-1'
        TF_IN_AUTOMATION = 'true'

        DOCKER_IMAGE = 'abdo1997mohamed2030/clientops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"

        ANSIBLE_VENV = '/opt/ansible-venv'

        WORKSPACE_DIR = "${WORKSPACE}"
        TF_DIR = "${WORKSPACE}/terraform"

        SSH_KEY = "${WORKSPACE}/terraform.pem"
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
                    echo "=== Tools Check ==="
                    git --version
                    python3 --version
                    docker --version
                    terraform version
                    aws --version
                '''
            }
        }

        stage('Setup Ansible Venv') {
            steps {
                sh '''
                    if [ ! -d "$ANSIBLE_VENV" ]; then
                        python3 -m venv $ANSIBLE_VENV
                        $ANSIBLE_VENV/bin/pip install --upgrade pip
                        $ANSIBLE_VENV/bin/pip install ansible
                    fi

                    $ANSIBLE_VENV/bin/ansible --version
                '''
            }
        }

        stage('Terraform Init & Apply') {
            steps {
                dir('terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws']]) {
                        sh '''
                            terraform init -reconfigure
                            terraform validate
                            terraform plan -out=tfplan
                            terraform apply -auto-approve tfplan
                        '''
                    }
                }
            }
        }

        stage('Prepare SSH Key (FIXED SAFE METHOD)') {
            steps {
                sh '''
                    echo "⚠ IMPORTANT: Using pre-generated SSH key from Jenkins workspace"

                    if [ ! -f "$SSH_KEY" ]; then
                        echo "ERROR: terraform.pem NOT FOUND in workspace!"
                        echo "👉 You MUST place your private key manually or generate it externally."
                        exit 1
                    fi

                    chmod 600 $SSH_KEY

                    echo "SSH Key OK:"
                    head -n 2 $SSH_KEY
                '''
            }
        }

        stage('Generate Inventory') {
            steps {
                sh '''
                    set -e

                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)

                    echo "APP_IP=$APP_IP"
                    echo "MONITOR_IP=$MONITOR_IP"

                    find_user() {
                        for u in ubuntu ec2-user admin centos; do
                            ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 $u@$1 "exit" &>/dev/null && echo $u && return
                        done
                        echo "ubuntu"
                    }

                    APP_USER=$(find_user $APP_IP)
                    MONITOR_USER=$(find_user $MONITOR_IP)

                    echo "Detected users: $APP_USER / $MONITOR_USER"

                    cat > hosts.ini <<EOF
[app_servers]
$APP_IP ansible_user=$APP_USER ansible_ssh_private_key_file=$SSH_KEY

[monitoring_servers]
$MONITOR_IP ansible_user=$MONITOR_USER ansible_ssh_private_key_file=$SSH_KEY

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

                    cat hosts.ini
                '''
            }
        }

        stage('Wait for SSH') {
            steps {
                sh '''
                    set +e

                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)

                    echo "Waiting for SSH..."

                    for i in $(seq 1 20); do
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$APP_IP "exit" && \
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no -o ConnectTimeout=5 ubuntu@$MONITOR_IP "exit" && break

                        echo "Retry $i/20..."
                        sleep 10
                    done
                '''
            }
        }

        stage('Run Ansible') {
            steps {
                sh '''
                    $ANSIBLE_VENV/bin/ansible-playbook -i hosts.ini setup.yml \
                        -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
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

        stage('Push Docker Image') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'DOCKER_USER',
                    passwordVariable: 'DOCKER_PASS'
                )]) {
                    sh '''
                        echo "$DOCKER_PASS" | docker login -u "$DOCKER_USER" --password-stdin

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
            echo "SUCCESS: Pipeline completed successfully"
        }
        failure {
            echo "FAILED: Check Terraform, SSH key, or AWS security groups"
        }
        always {
            echo "Pipeline finished"
        }
    }
}
