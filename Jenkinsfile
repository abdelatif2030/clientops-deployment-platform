pipeline {
    agent any

    environment {
        AWS_DEFAULT_REGION = 'eu-north-1'
        TF_IN_AUTOMATION = 'true'

        DOCKER_IMAGE = 'abdo1997mohamed2030/clientops-app'
        IMAGE_TAG = "${BUILD_NUMBER}"

        ANSIBLE_VENV = '/opt/ansible-venv'
        PATH = "${ANSIBLE_VENV}/bin:${env.PATH}"

        TF_DIR = "${WORKSPACE}/terraform"
        SSH_KEY = "${WORKSPACE}/terraform.pem"
    }

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                credentialsId: 'github',
                url: 'https://github.com/abdelatif2030/clientops-deployment-platform.git'
            }
        }

        stage('Tools Check') {
            steps {
                sh '''
                    git --version
                    python3 --version
                    docker --version
                    terraform version
                    aws --version
                '''
            }
        }

        stage('Setup Ansible') {
            steps {
                sh '''
                    if [ ! -d "$ANSIBLE_VENV" ]; then
                        python3 -m venv $ANSIBLE_VENV
                        $ANSIBLE_VENV/bin/pip install --upgrade pip
                        $ANSIBLE_VENV/bin/pip install ansible
                    fi
                '''
            }
        }

        stage('Terraform Apply') {
            steps {
                dir('terraform') {
                    withCredentials([[$class: 'AmazonWebServicesCredentialsBinding', credentialsId: 'aws']]) {
                        sh '''
                            terraform init -reconfigure
                            terraform apply -auto-approve
                        '''
                    }
                }
            }
        }

        stage('Extract SSH Key (FIXED)') {
            steps {
                dir('terraform') {
                    sh '''
                        echo "Extracting private key..."

                        terraform output -raw private_key_pem > ../terraform.pem

                        # CRITICAL FIX
                        sed -i 's/\\n/\
/g' ../terraform.pem

                        chmod 600 ../terraform.pem

                        echo "Key saved:"
                        head -n 2 ../terraform.pem
                    '''
                }
            }
        }

        stage('Generate Inventory') {
            steps {
                sh '''
                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)
                    MONITOR_IP=$(cd terraform && terraform output -raw monitoring_server_public_ip)

                    echo "[app]" > hosts.ini
                    echo "$APP_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> hosts.ini

                    echo "[monitor]" >> hosts.ini
                    echo "$MONITOR_IP ansible_user=ubuntu ansible_ssh_private_key_file=$SSH_KEY" >> hosts.ini

                    cat hosts.ini
                '''
            }
        }

        stage('Wait SSH') {
            steps {
                sh '''
                    APP_IP=$(cd terraform && terraform output -raw app_server_public_ip)

                    for i in $(seq 1 20); do
                        ssh -i $SSH_KEY -o StrictHostKeyChecking=no ubuntu@$APP_IP "echo OK" && break
                        echo "waiting SSH... $i"
                        sleep 10
                    done
                '''
            }
        }

        stage('Ansible Run') {
            steps {
                sh '''
                    chmod 600 $SSH_KEY || true

                    $ANSIBLE_VENV/bin/ansible-playbook -i hosts.ini setup.yml \
                        -e "ansible_ssh_common_args='-o StrictHostKeyChecking=no'"
                '''
            }
        }

        stage('Docker Build') {
            steps {
                sh '''
                    docker build -t $DOCKER_IMAGE:$IMAGE_TAG .
                    docker tag $DOCKER_IMAGE:$IMAGE_TAG $DOCKER_IMAGE:latest
                '''
            }
        }

        stage('Docker Push') {
            steps {
                withCredentials([usernamePassword(
                    credentialsId: 'dockerhub',
                    usernameVariable: 'U',
                    passwordVariable: 'P'
                )]) {
                    sh '''
                        echo "$P" | docker login -u "$U" --password-stdin
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
            echo "SUCCESS"
        }
        failure {
            echo "FAILED - check SSH key / Terraform / AWS"
        }
        always {
            echo "DONE"
        }
    }
}
