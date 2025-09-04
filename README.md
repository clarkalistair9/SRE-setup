# SRE Monitoring Server Setup Instructions

## Prerequisites

1. **GitLab Project**: Create a new GitLab project and push this code
2. **AWS Account**: KodeKloud AWS environment credentials
3. **SSH Key Pair**: Generate or use existing AWS EC2 key pair
4. **GitLab Variables**: Configure the required pipeline variables

## Step 1: Configure GitLab Pipeline Variables

Go to your GitLab project → Settings → CI/CD → Variables and add:

| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Variable | `your-access-key` | AWS Access Key from KodeKloud |
| `AWS_SECRET_ACCESS_KEY` | Variable (Masked) | `your-secret-key` | AWS Secret Key from KodeKloud |
| `AWS_REGION` | Variable | `us-east-1` | AWS Region (adjust as needed) |
| `KEY_PAIR_NAME` | Variable | `your-keypair-name` | Name of your AWS EC2 Key Pair |
| `SSH_PRIVATE_KEY` | Variable (Masked) | `base64-encoded-key` | Base64 encoded private key |

### Generating SSH_PRIVATE_KEY Value
```bash
# Encode your private key
cat ~/.ssh/your-private-key.pem | base64 -w 0
```

## Step 2: Project Structure Setup

Create the following additional files in your repository:

### ansible/ansible.cfg
```ini
[defaults]
host_key_checking = False
inventory = inventory/hosts
roles_path = roles/
stdout_callback = yaml
callbacks_enabled = profile_tasks
forks = 10
gathering = smart
fact_caching = memory
```

### terraform/terraform.tfvars.example
```hcl
aws_region = "us-east-1"
key_pair_name = "your-keypair-name"
instance_type = "t3.medium"
environment = "sre-monitoring"
```

## Step 3: Running the Pipeline

1. **Manual Triggers**: All stages are set to `when: manual` for safety
2. **Execution Order**: 
   - Run `validate` first to check Terraform syntax
   - Run `provision` to create AWS infrastructure  
   - Run `configure` to set up monitoring stack
   - Run `cleanup` when you're done (destroys everything)

### Pipeline Stages Explained

#### Validate Stage
- Checks Terraform formatting and syntax
- Validates configuration without creating resources

#### Provision Stage  
- Creates AWS infrastructure using Terraform
- Stores state in GitLab's HTTP backend
- Outputs instance IP and URLs as artifacts

#### Configure Stage
- Waits for EC2 instance to be ready
- Runs Ansible playbooks to configure the server
- Installs and configures monitoring stack

#### Cleanup Stage
- Destroys all AWS resources
- Should be run when finished with environment

## Step 4: Accessing Your SRE Server

After successful pipeline completion, you'll have:

### Prometheus (Metrics & Monitoring)
- URL: `http://<instance-ip>:9090`
- Features: Metrics collection, alerting rules, service discovery
- Targets: Self-monitoring, node metrics, container metrics

### Grafana (Dashboards & Visualization)  
- URL: `http://<instance-ip>:3000`
- Default credentials: `admin/admin`
- Pre-configured Prometheus datasource
- Ready for custom dashboards

### SSH Access
```bash
ssh -i your-private-key.pem ubuntu@<instance-ip>
```

## Step 5: Post-Deployment Tasks

### Grafana Configuration
1. Login to Grafana and change the default password
2. Import community dashboards:
   - Node Exporter Dashboard (ID: 1860)
   - Docker Container Dashboard (ID: 193)
   - Prometheus Stats Dashboard (ID: 2)

### Prometheus Configuration
- Metrics retention: 30 days (configurable)
- Scrape interval: 15 seconds
- Available at `/metrics` endpoint on each service

### Security Notes
- UFW firewall is configured with minimal required ports
- Fail2ban protects against SSH brute force attacks
- Automatic security updates are enabled
- All services run in Docker containers for isolation

## Troubleshooting

### Common Issues

1. **Pipeline fails at provision stage**
   - Check AWS credentials and permissions
   - Verify key pair exists in specified region
   - Ensure sufficient AWS quota limits

2. **Configure stage timeout**
   - EC2 instance may still be initializing
   - Check security groups allow SSH (port 22)
   - Verify private key format and permissions

3. **Services not accessible**
   - Check security groups allow required ports
   - Verify Docker containers are running: `docker ps`
   - Check service logs: `docker logs <container-name>`

### Manual Commands for Debugging

```bash
# Check user data script completion
sudo tail -f /var/log/cloud-init-output.log

# Verify Docker is running
sudo systemctl status docker

# Check monitoring stack
cd /opt/monitoring && docker compose ps

# View service logs
docker logs prometheus
docker logs grafana
docker logs node-exporter
docker logs cadvisor
```

## Cost Optimization

- Default instance type: t3.medium (~$0.04/hour)
- EBS storage: 30GB gp3 (~$2.40/month)
- Remember to run cleanup stage to avoid ongoing charges
- KodeKloud environments have time limits

## Next Steps

1. **Custom Dashboards**: Create Grafana dashboards for your specific use cases
2. **Alert Rules**: Add Prometheus alerting rules for critical metrics
3. **Additional Exporters**: Add application-specific exporters
4. **Backup Strategy**: Configure backup for Grafana dashboards and Prometheus data
5. **SSL/TLS**: Add reverse proxy with SSL certificates for production use