# 🚀 AWS GitHub Actions Pipeline

> Infrastructure as Code with Terraform and automated CI/CD via GitHub Actions using OIDC — no static AWS keys required.

![Terraform](https://img.shields.io/badge/Terraform-1.8-7B42BC?style=for-the-badge&logo=terraform&logoColor=white)
![GitHub Actions](https://img.shields.io/badge/GitHub_Actions-CI%2FCD-2088FF?style=for-the-badge&logo=githubactions&logoColor=white)
![AWS](https://img.shields.io/badge/AWS-Cloud-FF9900?style=for-the-badge&logo=amazonaws&logoColor=white)

---

## 📋 Overview

This project provides a reusable Terraform pipeline that deploys AWS infrastructure automatically on every push. It supports multiple environments (staging, prod) and uses **AWS OIDC** for authentication — meaning no AWS access keys are stored in GitHub.

---

## 📁 Project Structure

```
aws-github-actions-pipeline/
│
├── .github/
│   └── workflows/
│       ├── infra.yml          # Reusable Terraform workflow
│       ├── staging.yml        # Triggers deploy on push to staging branch
│       └── prod.yml           # Triggers deploy on push to main branch
│
└── terraform/
    ├── envs/
    │   ├── staging/
    │   │   └── terraform.tfvars    # Staging variables
    │   └── prod/
    │       └── terraform.tfvars    # Prod variables
    ├── main.tf                     # AWS resources
    ├── provider.tf                 # AWS provider config
    ├── backend.tf                  # S3 remote state
    ├── variables.tf                # Input variables
    └── destroy_config.json         # Destroy flags per environment
```

---

## ⚙️ How It Works

```
push to staging branch
        ↓
staging.yml triggers infra.yml
        ↓
Authenticate AWS via OIDC (no static keys)
        ↓
terraform init → validate → plan → apply
        ↓
Resources deployed to staging environment
```

The same flow applies to `prod` on push to `main`.

---

## 🔐 Setting Up `AWS_ASSUME_ROLE_ARN`

This project uses **OIDC** — GitHub assumes an AWS IAM Role temporarily instead of using long-lived access keys.

### 1. Create the IAM Role on AWS

The role must trust GitHub Actions as an identity provider. In your AWS account, create a role with this trust policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:YOUR_GITHUB_USERNAME/aws-github-actions-pipeline:*"
        }
      }
    }
  ]
}
```

### 2. Get the Role ARN

```bash
aws iam get-role \
  --role-name YOUR_ROLE_NAME \
  --query "Role.Arn" \
  --output text
# arn:aws:iam::123456789012:role/YOUR_ROLE_NAME
```

### 3. Add to GitHub Secrets

```
GitHub → Settings → Environments → (staging or prod) → Add secret

Name:  AWS_ASSUME_ROLE_ARN
Value: arn:aws:iam::123456789012:role/YOUR_ROLE_NAME
```

> ⚠️ Never commit the ARN or any AWS credentials directly in code.

---

## 🌍 Adding a New Environment

**1. Create the tfvars file:**
```
terraform/envs/YOUR_ENV/terraform.tfvars
```

```hcl
aws_region    = "us-east-1"
environment   = "YOUR_ENV"
```

**2. Add the entry to `destroy_config.json`:**
```json
{
  "staging": false,
  "prod": false,
  "YOUR_ENV": false
}
```

**3. Create the workflow file `.github/workflows/YOUR_ENV.yml`:**
```yaml
name: "YOUR_ENV DEPLOY"
on:
  push:
    branches:
      - YOUR_ENV

permissions:
  id-token: write
  contents: read

jobs:
  terraform:
    uses: ./.github/workflows/infra.yml
    secrets: inherit
    with:
      environment: YOUR_ENV
      aws-region: "us-east-1"
      aws-statefile-s3-bucket: "your-terraform-state-bucket"
      aws-lock-dynamodb-table: "your-dynamodb-lock-table"
```

**4. Push to the new branch** — the pipeline runs automatically.

---

## ➕ Adding New Resources

Add any new resource directly in `terraform/main.tf`.

**Example — adding an S3 bucket:**

```hcl
resource "aws_s3_bucket" "my_bucket" {
  bucket = "${var.environment}-my-new-bucket"

  tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
```

If the resource needs a variable, add it to `variables.tf` and set the value in each `terraform/envs/*/terraform.tfvars`.

On the next push, Terraform will detect the new resource and create it automatically.

---

## 💣 destroy_config.json

This file controls whether Terraform should **destroy** all resources in an environment instead of applying.

```json
{
  "staging": false,
  "prod": false
}
```

| Value | Behavior |
|---|---|
| `false` | Normal deploy — runs `terraform apply` |
| `true` | Destroys all resources — runs `terraform destroy` |

**To destroy the staging environment:**

```json
{
  "staging": true,
  "prod": false
}
```

Commit and push to the `staging` branch — the pipeline will destroy all staging resources automatically.

> ⚠️ Set back to `false` after destroying, otherwise every push will trigger a destroy.

---

## 🔒 Security

- ✅ OIDC authentication — no static AWS keys in GitHub
- ✅ Secrets stored in GitHub Environment Secrets
- ✅ Remote state stored in S3 with versioning
- ✅ Least privilege IAM role per environment
- ✅ `.terraform/` and state files excluded from git

---

<p align="center">Made with ☕ by <a href="https://github.com/gabrielsimongianotti">gabrielsimongianotti</a></p>

