# Ansible Playbook for Monitoring Stack

This playbook sets up a monitoring stack using Prometheus, Grafana, and Node Exporter on a GCP VM instance. It includes tasks for installing necessary packages, configuring services, and ensuring the monitoring stack is running.

## Requirements
- Ansible installed on the control machine.
- Access to a GCP VM instance with SSH configured.
- Python and pip installed on the target machine.
- Ansible collections for GCP and other dependencies installed.

## Setup Instructions

1. **Install Ansible Collections** from requirements.yml:
    Ensure you have the required Ansible collections installed. You can do this by running:
    ```bash
    ansible-galaxy collection install -r requirements.yml
    ```
2. **Configure Inventory**:
    Inventory should automatically set up after running terraform.
3. **Set up secret variables**:
    Ensure you have the `ansible/group_vars/secret.yml` file configured with your secrets, such as API keys or passwords.
    ```bash
    ansible-vault create ansible/group_vars/secret.yml
    ```
    example:
    ```yaml
    username: '<username>'
    password: '<password>'
    ```

4. **Run the Playbook**:
    Execute the playbook using the following command:
    ```bash
    ansible-playbook -i inventory/hosts monitoring.yml --ask-vault-pass
    ```

