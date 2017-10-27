# nginx-hello-world

## Overview

This repo contains code to build and provision a web application that serves static content in AWS.  The server runs CentOS 7.3 with NGINX as the HTTP server.  NGINX installation and configuration is done via a Chef recipe.  An AMI image provisioned with the Chef recipe is created using Packer.  The AMI is then deployed to AWS along with a VPC and subnets via Terraform.

## Pre-requisites

Ensure that the following are installed on your system:

1. [ChefDK](https://downloads.chef.io/chefdk/current).  (Note that installation via Homebrew Cask does not necessarily have the latest version of the ChefDK.)
1. [Vagrant](https://www.vagrantup.com/downloads.html)
1. [VirtualBox](https://www.virtualbox.org/wiki/Downloads)
1. [Packer](https://www.packer.io/docs/install/index.html)
1. [Terraform](https://www.terraform.io/intro/getting-started/install.html)
1. [AWS CLI tools](https://docs.aws.amazon.com/cli/latest/userguide/installing.html)
  - On OSX, you may have a nicer time installing via [Homebrew](https://brew.sh/): `brew install awscli`
  - On Windows, you may have a nicer time installing via [Chocolatey](https://chocolatey.org/packages/awscli): `choco install awscli`
  - Ensure that your credentials and default region are set to us-east-1 via `aws configure`

## Chef

The Chef recipe installs NGINX and replaces the default `index.html` with our "Hello World!" content and forces a redirect from http to https unless the `X-Proto-Forwarded` header is set to `https`.  (This is [what an ELB does when it terminates TLS](https://aws.amazon.com/premiumsupport/knowledge-center/redirect-http-https-elb/).)  Tests are performed via [InSpec](https://www.inspec.io/) and [Test Kitchen](http://kitchen.ci/) and run against a Centos 7.latest virtual machine.

To run a full build/test/teardown cycle of the cookbook, run the following command.  Note that this is not necessary in order to build the infrastructure in this repo:

```bash
cd chef/nginx_hello_world && kitchen test
```

## Packer

Packer runs the Chef recipe against the officially supported Centos 7.3 AMI in the us-east-1 region of AWS.  It then saves the resulting AMI with a unique name (a timestamp is appended to the AMI name in order to version the image) in the default VPC of the current user.

To build the AMI, run the following command:

```bash
packer build template.json
```

Note: You must have a default VPC in us-east-1 in order for the code to run correctly.  If you have deleted your default VPC, follow [these instructions](https://docs.aws.amazon.com/AmazonVPC/latest/UserGuide/default-vpc.html#create-default-vpc) to create a new Default VPC.

## Terraform

Terraform creates a new VPC in AWS with a public subnet, creates an EC2 instance from the most recent AMI we created with Packer, and places it behind an elastic load balancer (ELB) which terminates SSL and forwards requests on to NGINX running on our EC2 instance.

First, we need to generate a self-signed cert to add to the ELB.  (The `certs` directory is `.gitignore`-ed to avoid accidentally publishing our private key.):

```bash
openssl req -x509 -newkey rsa:4096 -keyout terraform/certs/key.pem -out terraform/certs/cert.pem -days 365 -nodes -subj '/CN=*.us-east-01.elb.amazonaws.com'
```

To deploy the infrastructure, run the following after the Packer image has been successfully built:

```bash
cd terraform && terraform apply
```

The output of `terraform apply` will contain the DNS name at which the site can be viewed.  Accessing the the site via HTTP will result in a permanent redirection to HTTPS.  Accessing the site via HTTPS will result in the Hello World! content being served.

Note: In this repo, Terraform state is stored locally.  This is ok for development purposes on a small demo project like this, but for production use consider [storing Terraform state remotely](https://www.terraform.io/docs/state/remote.html).  [S3 is a good choice](https://www.terraform.io/docs/backends/types/s3.html).