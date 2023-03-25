resource "aws_iam_role" "ebs_volume_removal_lambda" {
  name = "iam_role_for_ebs_volume_auto_removal"
  managed_policy_arns = [
    "${aws_iam_policy.ebs_auto_removal.arn}",
    "${aws_iam_policy.ebs_removal_policy.arn}",
    "${aws_iam_policy.sns_policy_ebs_auto_removal.arn}",
    "arn:aws:iam::aws:policy/service-role/${var.lambda_exec_role}",
  ]
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "iam_attachment_lambda" {
  role       = aws_iam_role.ebs_volume_removal_lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/${var.lambda_exec_role}"
}

resource "aws_iam_policy_attachment" "ebs_auto_removal_policy" {
  name       = "ebs_auto_removal_policy"
  roles      = [aws_iam_role.ebs_volume_removal_lambda.name]
  policy_arn = aws_iam_policy.ebs_auto_removal.arn
}

resource "aws_iam_policy_attachment" "ebs_removal_policy" {
  name       = "ebs_removal_policy"
  roles      = [aws_iam_role.ebs_volume_removal_lambda.name]
  policy_arn = aws_iam_policy.ebs_removal_policy.arn
}

resource "aws_iam_policy" "ebs_auto_removal" {
  name        = "iam_policy_for_ebs_auto_removal"
  path        = "/"
  description = "IAM Policy for ebs auto removal tool"

  policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": [
        "logs:PutLogEvents",
        "logs:DescribeLogStreams",
        "logs:DescribeLogGroups"
      ],
      "Resource": [
        "*"
      ],
      "Effect": "Allow"
    },
      {
        "Action": [
          "cloudwatch:PutMetricData"
        ],
        "Resource": [
          "*"
        ],
        "Effect": "Allow"
      }
  ]
}
EOF
}

# module.ebs-lambda[0].aws_iam_policy.ebs_removal_policy:
resource "aws_iam_policy" "ebs_removal_policy" {
  description = "IAM Policy for removing and tagging ebs volumes"
  name        = "iam_policy_for_ebs_automation_tagging_removing"
  path        = "/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "ec2:DeleteVolume",
            "ec2:DescribeVolumes",
            "ec2:CreateTags",
            "ec2:DeleteTags",
            "ec2:DescribeTags",
            "ec2:ModifyVolumeAttribute",
          ]
          Effect = "Allow"
          Resource = [
            "*",
          ]
        },
      ]
      Version = "2012-10-17"
    }
  )
}

# aws_iam_policy.sns_policy_ebs_auto_removal:
resource "aws_iam_policy" "sns_policy_ebs_auto_removal" {
  depends_on  = [aws_sns_topic.remove_ebs_topic]
  description = "publish to sns topic when performing ebs volume automation reports"
  name        = "sns_policy_ebs_auto_removal"
  path        = "/"
  policy = jsonencode(
    {
      Statement = [
        {
          Action = [
            "sns:ListTagsForResource",
            "sns:ListTopics",
            "sns:GetTopicAttributes",
          ]
          Effect   = "Allow"
          Resource = "arn:aws:sns:${var.main_region}:${data.aws_caller_identity.current.account_id}:*"
          Sid      = "VisualEditor0"
        },
        {
          Action = [
            "sns:SetSubscriptionAttributes",
            "sns:Publish",
            "sns:GetSubscriptionAttributes",
            "sns:SetTopicAttributes",
          ]
          Effect   = "Allow"
          Resource = "${aws_sns_topic.remove_ebs_topic.arn}"
          Sid      = "VisualEditor1"
        },
      ]
      Version = "2012-10-17"
    }
  )
}
