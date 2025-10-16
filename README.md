# SRE Monitoring Server Setup Instructions

## Prerequisites

1. **GitLab Project**: Create a new GitLab project and push this code
2. **Cloud Account**: Credentials for your target cloud (AWS, Azure, or GCP)
3. **SSH Keys**:
   - AWS: existing EC2 key pair name
   - Azure/GCP: your SSH public key text (OpenSSH format)
4. **GitLab Variables**: Configure the required pipeline variables (see below)

## Step 1: Configure GitLab Pipeline Variables

Go to your GitLab project → Settings → CI/CD → Variables and add as needed for your target cloud:

### Common
| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `TARGET_CLOUD` | Variable | `aws` or `azure` or `gcp` | Selects Terraform folder and state |
| `SSH_PRIVATE_KEY` | Variable (Masked) | `base64-encoded-key` | Base64 of private key used by Ansible |
| `SSH_PUBLIC_KEY` | Variable | `ssh-rsa AAAA... user@host` | Required for Azure/GCP VM provisioning |

### AWS
| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `AWS_ACCESS_KEY_ID` | Variable | `your-access-key` | AWS Access Key |
| `AWS_SECRET_ACCESS_KEY` | Variable (Masked) | `your-secret-key` | AWS Secret Key |
| `AWS_REGION` | Variable | `us-east-1` | AWS Region |
| `KEY_PAIR_NAME` | Variable | `your-keypair-name` | Existing EC2 Key Pair name |

### Azure
| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `ARM_SUBSCRIPTION_ID` | Variable | `<uuid>` | Azure Subscription ID |
| `ARM_TENANT_ID` | Variable | `<uuid>` | Azure Tenant ID |
| `ARM_CLIENT_ID` | Variable | `<uuid>` | Azure Service Principal App ID |
| `ARM_CLIENT_SECRET` | Variable (Masked) | `<secret>` | Azure Service Principal Secret |
| `AZURE_LOCATION` | Variable | `eastus` | Azure Region (optional override) |

### GCP
| Variable | Type | Value | Description |
|----------|------|-------|-------------|
| `GOOGLE_CREDENTIALS` | File or Variable (Masked) | JSON content | Service Account with compute access |
| `GCP_PROJECT` | Variable | `my-project-id` | GCP Project ID |
| `GCP_REGION` | Variable | `us-central1` | GCP Region |
| `GCP_ZONE` | Variable | `us-central1-a` | GCP Zone |

### Generating SSH_PRIVATE_KEY Value
```bash
# Encode your private key
cat ~/.ssh/your-private-key.pem | base64 -w 0
```

### Getting your SSH_PUBLIC_KEY (Azure/GCP)
```bash
cat ~/.ssh/id_rsa.pub
```

### Providing GOOGLE_CREDENTIALS (GCP)
- Paste the entire JSON content of your Service Account key into a masked variable named `GOOGLE_CREDENTIALS`, or upload as a CI/CD file variable with the same key.

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
# AWS example
aws_region    = "us-east-1"
key_pair_name = "your-keypair-name"
instance_type = "t3.medium"
environment   = "sre-monitoring"
```

```hcl
# Azure example
location       = "eastus"
environment    = "sre-monitoring"
ssh_public_key = "ssh-rsa AAAAB3Nza... user@host"
```

```hcl
# GCP example
project        = "my-project-id"
region         = "us-central1"
zone           = "us-central1-a"
environment    = "sre-monitoring"
ssh_public_key = "ssh-rsa AAAAB3Nza... user@host"
```

## Step 3: Running the Pipeline (Multi-cloud)

1. **Choose Cloud**: Set `TARGET_CLOUD` pipeline variable to one of: `aws`, `azure`, `gcp`
2. **Manual Triggers**: All stages are `when: manual`
3. **Execution Order**: 
   - Run `validate`
   - Run `provision`
   - Run `configure`
   - Run `cleanup` (destroy)

### Pipeline Stages Explained

#### Validate Stage
- Checks Terraform formatting and syntax
- Validates configuration without creating resources

#### Provision Stage  
- Creates infrastructure in the selected cloud using Terraform
- Stores state in GitLab's HTTP backend (separate state per cloud)
- Outputs standardized values: `public_ip`, `instance_id`, `ssh_user`

#### Configure Stage
- Waits for the provisioned VM to be reachable via SSH
- Runs Ansible playbooks to configure the server
- Installs and configures the monitoring stack

#### Cleanup Stage
- Destroys all provisioned resources in the selected cloud
- Should be run when finished with the environment

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
ssh -i your-private-key.pem <ssh_user>@<instance-ip>
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

## Cloud-specific variables

### Common
- `TARGET_CLOUD`: `aws` | `azure` | `gcp`
- `SSH_PRIVATE_KEY`: base64 of private key used by Ansible
- `SSH_PUBLIC_KEY`: public key text (required for Azure/GCP)

### AWS
- `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_REGION` (default `us-east-1`)
- `KEY_PAIR_NAME`: EC2 Key Pair name

### Azure
- `ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`, `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`
- `AZURE_LOCATION` (default `eastus`)
- `SSH_PUBLIC_KEY` must be provided

### GCP
- `GOOGLE_CREDENTIALS`: JSON content of a Service Account with compute access
- `GCP_PROJECT`, `GCP_REGION` (default `us-central1`), `GCP_ZONE` (default `us-central1-a`)
- `SSH_PUBLIC_KEY` must be provided

## Troubleshooting

### Common Issues

1. **Pipeline fails at provision stage**
   - Validate cloud credentials and permissions (AWS/Azure/GCP)
   - AWS: verify EC2 key pair exists in the specified region
   - Azure: ensure Service Principal has `Contributor` on the subscription
   - GCP: verify `GOOGLE_CREDENTIALS` belongs to a Service Account with `Compute Admin`
   - Ensure sufficient quota limits in your chosen region/zone

2. **Configure stage timeout**
   - VM may still be initializing; check cloud console for status
   - Verify inbound rules allow SSH (port 22) and required service ports
   - Confirm the correct SSH username is used (`ubuntu` by default)
   - Verify private key format and permissions

3. **Services not accessible**
   - Check network rules:
     - AWS: Security Group rules
     - Azure: Network Security Group rules
     - GCP: VPC Firewall rules
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