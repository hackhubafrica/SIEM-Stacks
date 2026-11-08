
AI Overview

Deploying Wazuh SIEM/XDR on Docker using Docker Compose is the fastest way to get a production-ready or home-lab security monitoring environment up and running.

📋 Prerequisites & System Requirements

Before starting, ensure your host machine meets the following baseline specs:

Requirement	Single-Node Stack (1-25 Agents)	Multi-Node Stack (Production)
OS	Linux or Windows (with WSL 2)	Linux or Windows
CPU	Minimum 4 Cores	Minimum 4 Cores
RAM	Minimum 8 GB RAM	Minimum 16 GB RAM
Storage	50 GB+ SSD	100 GB+ SSD


Critical Host Configuration

The Wazuh Indexer (built on OpenSearch) requires a higher virtual memory allocation than the Linux default. Run this command on your host machine before launching the containers, otherwise the indexer will instantly crash:
bash
# Apply immediately
sudo sysctl -w vm.max_map_count=262144

# Make it persistent across reboots
echo "vm.max_map_count=262144" | sudo tee -a /etc/sysctl.conf
Use code with caution.

🚀 Step-by-Step Deployment (Single-Node)


1. Clone the Official Repository

Clone the production-ready repository directly from Wazuh's GitHub:
bash
git clone https://github.com/wazuh/wazuh-docker.git
cd wazuh-docker/single-node/
Use code with caution.

2. Generate SSL/TLS Certificates

Wazuh components enforce internal encrypted communication. Use the built-in certificate generator container to provision self-signed certificates:
bash
docker compose -f generate-indexer-certs.yml run --rm generator
Use code with caution.

3. Start the Stack

Launch the Wazuh Indexer, Server (Manager), and Dashboard in detached (background) mode:
bash
docker compose up -d
Use code with caution.

4. Monitor the Startup

The indexer typically takes about 60 seconds to fully initialize its cluster. Check the cluster initialization status using:
bash
docker compose ps
Use code with caution.

🔑 Accessing the Dashboard

Once all containers show a running status, open your browser and navigate to your host's IP address over HTTPS:
• URL: https://<YOUR_HOST_IP> (Accept the self-signed certificate warning if in a lab environment).
• Default Username: admin
• Default Password: SecretPassword (Note: You can change this inside the docker-compose.yml file prior to boot).

🛡️ Network Ports Checklist

Ensure your host firewall or cloud security groups allow traffic through the following required ports so your endpoints can communicate with the SIEM:
• 443 (TCP): Web user interface (Wazuh Dashboard).
• 1514 (TCP): Agent communication and log collection.
• 1515 (TCP): Agent enrollment and authentication.
• 55000 (TCP): Wazuh REST API used by the dashboard.

🛠️ Common Administrative Commands

• View live logs: docker compose logs -f wazuh.manager
• Stop the SIEM stack: docker compose down
• Access container shell: docker compose exec wazuh.manager bash
To tailor this setup to your exact needs, let me know:
• Are you setting this up for a home-lab environment or a production infrastructure?
• Do you plan to deploy standard Wazuh agents on endpoints, or do you want to monitor the Docker host itself