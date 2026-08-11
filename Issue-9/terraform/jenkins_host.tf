resource "aws_security_group" "jenkins_sg" {
  name        = "vantra-jenkins-sg"
  description = "Allows inbound Jenkins UI from the corp network"
  vpc_id      = data.aws_vpc.shared.id

  ingress {
    description = "Jenkins UI"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = [var.corp_cidr]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "vantra-jenkins-sg"
  }
}

resource "aws_instance" "jenkins" {
  ami                         = var.ami_id
  instance_type               = "t3.medium"
  subnet_id                   = data.aws_subnets.public.ids[0]
  vpc_security_group_ids      = [aws_security_group.jenkins_sg.id]
  iam_instance_profile        = aws_iam_instance_profile.jenkins_instance_profile.name
  associate_public_ip_address = true

  # NOTE: var.ami_id resolves to Ubuntu in this account/region - this
  # user_data is apt-based to match. If you point ami_id at an Amazon
  # Linux AMI instead, swap this for dnf.
  user_data = <<-EOF
    #!/bin/bash
    set -e
    export DEBIAN_FRONTEND=noninteractive

    wait_for_apt_lock() {
      while sudo fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 \
         || sudo fuser /var/lib/apt/lists/lock >/dev/null 2>&1 \
         || sudo fuser /var/lib/dpkg/lock >/dev/null 2>&1; do
        echo "Waiting for another apt/dpkg process to release the lock..."
        sleep 5
      done
    }

    wait_for_apt_lock
    apt-get update -y
    wait_for_apt_lock
    apt-get install -y openjdk-21-jre fontconfig docker.io git unzip curl

    # Don't assume the AMI ships amazon-ssm-agent pre-installed.
    snap install amazon-ssm-agent --classic || true
    systemctl enable --now snap.amazon-ssm-agent.amazon-ssm-agent.service || systemctl enable --now amazon-ssm-agent || true

    systemctl enable --now docker

    # --- Jenkins (Debian/Ubuntu repo) - 2026 signing key, the old
    # 2023 key was retired for LTS releases from Jenkins 2.541.1 onward ---
    curl -fsSL https://pkg.jenkins.io/debian-stable/jenkins.io-2026.key -o /usr/share/keyrings/jenkins-keyring.asc
    echo "deb [signed-by=/usr/share/keyrings/jenkins-keyring.asc] https://pkg.jenkins.io/debian-stable binary/" > /etc/apt/sources.list.d/jenkins.list
    wait_for_apt_lock
    apt-get update -y
    wait_for_apt_lock
    apt-get install -y jenkins
    usermod -aG docker jenkins

    # --- AWS CLI v2 ---
    curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
    unzip -o /tmp/awscliv2.zip -d /tmp
    /tmp/aws/install

    # --- Terraform ---
    TF_VERSION="1.9.5"
    curl -fsSL "https://releases.hashicorp.com/terraform/$${TF_VERSION}/terraform_$${TF_VERSION}_linux_amd64.zip" -o /tmp/terraform.zip
    unzip -o /tmp/terraform.zip -d /usr/local/bin

    systemctl restart jenkins

    echo "===== bootstrap complete =====" >> /var/log/vantra-bootstrap.log
    systemctl is-active jenkins >> /var/log/vantra-bootstrap.log 2>&1 || true
    java -version >> /var/log/vantra-bootstrap.log 2>&1 || true
    aws --version >> /var/log/vantra-bootstrap.log 2>&1 || true
    terraform -version >> /var/log/vantra-bootstrap.log 2>&1 || true
  EOF

  tags = {
    Name    = "vantra-jenkins-controller"
    Project = "billing-invoice-service"
    Role    = "ci"
  }
}

output "jenkins_instance_id" {
  value = aws_instance.jenkins.id
}

output "jenkins_public_ip" {
  value = aws_instance.jenkins.public_ip
}
