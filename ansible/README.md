# VPS Bootstrap

Edit `inventory.ini` and replace `VPS_IP` with the droplet IP.
Update `ansible_ssh_private_key_file` (`SSH_PRIVATE_KEY_PATH`) to the SSH key path for root access.
Run `ansible-playbook --syntax-check playbook.yml` before applying changes.
Bootstrap the host with `ansible-playbook playbook.yml` when ready.
The playbook installs Nginx, Certbot, cron, and Docker from Docker's APT repo.
It creates `/var/www/VisionTemplate` and the external `vision_network` network.
App deployment and Nginx vhost creation are intentionally handled elsewhere.
