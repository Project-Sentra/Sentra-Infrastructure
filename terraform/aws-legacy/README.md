# AWS (legacy)

The original AWS design for Sentra: EC2 (free tier) behind an Application Load Balancer
with ACM HTTPS, images in ECR, and GitHub Actions OIDC for deployments.

It is **no longer maintained or deployed**. The project moved to Google Cloud
(`terraform/gcp` + `ansible/`). These files are kept as a reference for the design
documentation and to show how the infrastructure evolved.
