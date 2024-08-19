# Deploy AWS SSM Session Manager port forwarding demo environment

## Overview

This folder contains a simple project for deploying AWS environment to demonstrate AWS SSM Session Manager port forwarding. For more details, read my [blog post](https://blog.wkhoo.com/posts/ssm-port-forwarding-part2/).

The Terraform code will deploy the AWS resources as depicted in this high level architecture diagram:

![Demo architecture](https://blog.wkhoo.com/images/secure-ssm-architecture_huc99b2551ded5814faeefb358abb71c24_96205_800x640_fit_q50_box.jpeg)

> **Important note:** Deploying the demo environment will incur some cost in your AWS account even if you're on free tier because of the SSM endpoints and data transfer charges.

## Requirements

- [Terraform](https://www.terraform.io/downloads) (>= 1.5.0)
- AWS account [configured with proper credentials to run Terraform](https://registry.terraform.io/providers/hashicorp/aws/latest/docs#authentication-and-configuration)

## Walkthrough

1) Clone this repository to your local machine.

   ```shell
   git clone https://github.com/wtkhoo/ssm-port-forwarding-demo.git
   ```

2) Change your directory to the `ssm-port-forwarding-demo` folder.

   ```shell
   cd ssm-port-forwarding-demo
   ```

3) Run the terraform [init](https://www.terraform.io/cli/commands/init) command to initialize the Terraform deployment and set up the providers.

   ```shell
   terraform init
   ```

4) To customize your deployment, create a `terraform.tfvars` file and specify your values.

    ```
    # Prefix name for resources
    name     = "ssm-demo"
    # VPC CIDR block
    vpc_cidr = "10.0.0.0/16"
    ```
  
5) Next step is to run a terraform [plan](https://www.terraform.io/cli/commands/plan) command to preview what will be created.

   ```shell
   terraform plan
   ```

6) If your values are valid, you're ready to go. Run the terraform [apply](https://www.terraform.io/cli/commands/apply) command to provision the resources.

   ```shell
   terraform apply
   ```

7) When you're done with the demo, run the terraform [destroy](https://www.terraform.io/cli/commands/destroy) command to delete all resources that were created in your AWS environment.

   ```shell
   terraform destroy
   ```

## Questions and Feedback

If you have any questions or feedback, please don't hesitate to [create an issue](https://github.com/wtkhoo/ssm-port-forwarding-demo/issues/new).