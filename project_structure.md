# SRE Monitoring Server Project Structure

```
sre-monitoring-server/
├── .gitlab-ci.yml
├── README.md
├── terraform/
│   ├── main.tf
│   ├── user_data.sh
│   └── terraform.tfvars.example
├── ansible/
│   ├── ansible.cfg
│   ├── inventory/
│   │   └── hosts (generated during pipeline)
│   ├── playbooks/
│   │   └── site.yml
│   └── roles/
│       ├── system_hardening/
│       │   ├── tasks/
│       │   │   └── main.yml
│       │   ├── templates/
│       │   │   ├── 20auto-upgrades.j2
│       │   │   ├── jail.local.j2
│       │   │   ├── monitoring-logs.j2
│       │   │   ├── 99-monitoring.conf.j2
│       │   │   └── 99-monitoring-sysctl.conf.j2
│       │   └── handlers/
│       │       └── main.yml
│       └── monitoring_stack/
│           ├── tasks/
│           │   └── main.yml
│           ├── templates/
│           │   ├── prometheus.yml.j2
│           │   ├── grafana-datasource.yml.j2
│           │   ├── grafana-dashboards.yml.j2
│           │   ├── docker-compose.yml.j2
│           │   └── monitoring-stack.service.j2
│           └── handlers/
│               └── main.yml
└── docs/
    ├── setup.md
    └── troubleshooting.md
```

## Key Files Created

### GitLab CI/CD Pipeline (.gitlab-ci.yml)
- **validate**: Validates Terraform configuration
- **provision**: Creates AWS infrastructure using Terraform
- **configure**: Runs Ansible playbooks to configure the server
- **cleanup**: Destroys infrastructure (manual trigger)

### Terraform Configuration (terraform/)
- **main.tf**: Complete AWS infrastructure setup including VPC, subnets, security groups, and EC2 instance
- **user_data.sh**: Bootstrap script that prepares the Ubuntu server with Docker and basic packages

### Ansible Configuration (ansible/)
- **site.yml**: Main playbook orchestrating the configuration
- **system_hardening role**: Implements security best practices
- **monitoring_stack role**: Deploys Prometheus, Grafana, and exporters using Docker Compose

## What Gets Deployed

### Infrastructure
- VPC with public subnet
- EC2 instance (t3.medium by default)
- Security groups with minimal required access
- Proper networking setup

### Security Hardening
- UFW firewall configuration
- Fail2ban for SSH protection
- Automatic security updates
- System limits and kernel parameter tuning
- Log rotation configuration

### Monitoring Stack (via Docker)
- **Prometheus**: Metrics collection and storage
- **Grafana**: Visualization and dashboards
- **Node Exporter**: System metrics
- **cAdvisor**: Container metrics

### Access Points
- Prometheus: `http://<instance-ip>:9090`
- Grafana: `http://<instance-ip>:3000` (admin/admin)
- SSH: Port 22 with key-based authentication