#!/bin/bash
apt-get update
apt-get upgrade -y
hostnamectl set-hostname ${hostname}
echo "127.0.0.1 ${hostname}" >> /etc/hosts
apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release software-properties-common python3 python3-pip unzip htop vim git
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
systemctl enable --now docker
usermod -aG docker ubuntu
mkdir -p /opt/monitoring && chown ubuntu:ubuntu /opt/monitoring
touch /var/log/user-data-complete.log




