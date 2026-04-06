# Use official Ubuntu LTS as base
FROM ubuntu:24.04

# Set environment variables
ENV DEBIAN_FRONTEND=noninteractive
ENV ANSIBLE_VENV=/opt/ansible-venv
ENV PATH=$ANSIBLE_VENV/bin:$PATH

# Install required system packages
RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 python3-venv python3-pip \
    sudo curl wget git unzip \
    docker.io \
    apt-transport-https gnupg software-properties-common \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "/tmp/awscliv2.zip" \
    && unzip /tmp/awscliv2.zip -d /tmp \
    && /tmp/aws/install \
    && rm -rf /tmp/aws /tmp/awscliv2.zip

# Install Terraform
ENV TERRAFORM_VERSION=1.14.8
RUN curl -fsSL https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_amd64.zip -o terraform.zip \
    && unzip terraform.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform.zip

# Create virtual environment for Ansible
RUN python3 -m venv $ANSIBLE_VENV \
    && $ANSIBLE_VENV/bin/pip install --upgrade pip \
    && $ANSIBLE_VENV/bin/pip install ansible

# Set default working directory
WORKDIR /workspace

# Copy Jenkins pipeline files if needed
# COPY . /workspace

# Default entrypoint
CMD [ "bash" ]
