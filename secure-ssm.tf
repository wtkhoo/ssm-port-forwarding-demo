# Get the AWS account ID
data "aws_caller_identity" "current" {}

# Define a policy to allow starting SSM port forwarding sessions to specific 
# ports on EC2 instances based on resource tagging
resource "aws_iam_policy" "ssm_port_forwarding" {
  name = "SSMPortForwarding"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      # Permissions to list and describe EC2 instances and SSM sessions
      {
        Action   = [
          "ssm:DescribeSessions",
          "ssm:ListDocuments",
          "ssm:GetConnectionStatus",
          "ssm:DescribeInstanceInformation",
          "ec2:DescribeInstances"
        ]
        Effect   = "Allow"
        Resource = "*"
      },
      # Permission to initiate SSM sessions on EC instances with a specific tag
      {
        Action   = [
          "ssm:StartSession",
        ]
        Effect   = "Allow"
        Resource = [
          "arn:aws:ec2:*:${data.aws_caller_identity.current.account_id}:instance/*",
        ]
        Condition = {
          StringEquals = {
            "aws:resourceTag/PortForward" = "true"
          }
        }
      },
      # Permission to allow starting specific SSM document sessions
      {
        Action   = [
          "ssm:StartSession",
        ]
        Effect   = "Allow"
        Resource = [
          "${aws_ssm_document.restricted_forwarding.arn}",
        ]
        Condition = {
          BoolIfExists = {
            "ssm:SessionDocumentAccessCheck" = "true"
          }
        }
      },
      # Deny usage of default SSM port forwarding documents
      {
        Action   = [
          "ssm:StartSession",
        ]
        Effect   = "Deny"
        Resource = [
          "arn:aws:ssm:*:*:document/AWS-StartPortForwardingSession*",
        ]
      },
      # Permissions to terminate and resume SSM sessions initiated by the role
      {
        Action   = [
          "ssm:TerminateSession",
          "ssm:ResumeSession"
        ]
        Effect   = "Allow"
        Resource = "arn:aws:ssm:*:*:session/$${aws:userid}-*"
      }
    ]
  })
}

# Define an IAM role to be used for port forwarding demo
resource "aws_iam_role" "ssm_port_forwarding" {
  name                = "SSMPortForwarding"
  managed_policy_arns = [
    aws_iam_policy.ssm_port_forwarding.arn
  ]

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
      }]
  })
}

# Create an SSM document for restricted port forwarding
resource "aws_ssm_document" "restricted_forwarding" {
  name          = "RestrictedPortForwardingSession"
  document_type = "Session"

  content = jsonencode({
    schemaVersion = "1.0",
    description = "Document for initiating port forwarding sessions via Session Manager",
    sessionType = "Port",
    parameters = {
      portNumber = {
        type = "String",
        description = "Port number to expose from the instance (optional)",
        allowedPattern = "^(80|443|22|3389)$",
        default = "80"
      },
      localPortNumber = {
        type = "String",
        description = "Local machine port number for traffic forwarding (optional)",
        allowedPattern = "^([0-9]|[1-9][0-9]{1,3}|[1-5][0-9]{4}|6[0-4][0-9]{3}|65[0-4][0-9]{2}|655[0-2][0-9]|6553[0-5])$",
        default = "0"
      }
    },
    properties = {
      portNumber = "{{ portNumber }}",
      type = "LocalPortForwarding",
      localPortNumber = "{{ localPortNumber }}"
    }
  })
}
