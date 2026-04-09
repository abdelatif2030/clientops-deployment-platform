# Use official Jenkins LTS image
FROM jenkins/jenkins:lts

# Switch to root to install packages
USER root

# -------------------------------
# Install base packages
# -------------------------------
RUN apt-get update && apt-get install -y \
    curl \
    unzip \
    git \
    python3 \
    python3-venv \
    python3-pip \
    ca-certificates \
    gnupg \
    lsb-release \
    apt-transport-https \
    sudo \
    && rm -rf /var/lib/apt/lists/*

# -------------------------------
# Install Ansible in virtual environment
# -------------------------------
RUN python3 -m venv /opt/ansible-venv \
    && /opt/ansible-venv/bin/pip install --upgrade pip \
    && /opt/ansible-venv/bin/pip install ansible

# Add venv to PATH
ENV PATH="/opt/ansible-venv/bin:${PATH}"

# -------------------------------
# Install Docker CLI
# -------------------------------
RUN mkdir -p /etc/apt/keyrings && \
    curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" \
    > /etc/apt/sources.list.d/docker.list && \
    apt-get update && apt-get install -y docker-ce-cli && \
    rm -rf /var/lib/apt/lists/*

# -------------------------------
# Install AWS CLI v2
# -------------------------------
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf aws awscliv2.zip

# -------------------------------
# Install kubectl
# -------------------------------
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
    install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl && \
    rm kubectl

# -------------------------------
# Install eksctl
# -------------------------------
RUN curl --silent --location "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_amd64.tar.gz" | tar xz -C /tmp && \
    mv /tmp/eksctl /usr/local/bin && \
    chmod +x /usr/local/bin/eksctl

# -------------------------------
# Allow Jenkins user to run Docker
# -------------------------------
RUN groupadd docker || true && \
    usermod -aG docker jenkins

# Switch back to Jenkins user
USER jenkins

# Expose Jenkins ports
EXPOSE 8080 50000
