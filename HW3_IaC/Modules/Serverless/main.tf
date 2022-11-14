provider "aws" {
    region = "us-east-1"
}

provider "archive" {}

data "archive_file" "lambda-functions" {
    type = "zip"
    source_dir  = "./Lambda-Functions"
    output_path = "./Lambda-Functions.zip"
}

data "aws_iam_policy_document" "policy" {
  statement {
    sid    = ""
    effect = "Allow"
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type        = "Service"
    }
    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "lambdaRole" {
  name = "LambdaRole"
  assume_role_policy = data.aws_iam_policy_document.policy.json
}

# Lambda functions

resource "aws_lambda_function" "calc" {
  for_each = toset(var.lambda_list)
  function_name = each.value
  filename         = data.archive_file.lambda-functions.output_path
  source_code_hash = data.archive_file.lambda-functions.output_base64sha256
  role             = aws_iam_role.lambdaRole.arn
  handler = "${each.value}.lambda_handler"
  runtime = "python3.9"
}

resource "aws_apigatewayv2_api" "lambda" {
  name          = "calculator_gw"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "lambda" {
  api_id = aws_apigatewayv2_api.lambda.id

  name        = "calculator_stage"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "calc" {
  for_each = toset(var.lambda_list)
  api_id = aws_apigatewayv2_api.lambda.id

  integration_uri    = aws_lambda_function.calc[each.value].invoke_arn
  integration_type   = "AWS_PROXY"
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "calc" {
  for_each = toset(var.lambda_list)
  api_id = aws_apigatewayv2_api.lambda.id

  route_key = "GET /lambda/${each.value}"
  target    = "integrations/${aws_apigatewayv2_integration.calc[each.value].id}"
}

resource "aws_lambda_permission" "api_gw" {
  for_each = toset(var.lambda_list)
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.calc[each.value].function_name
  principal     = "apigateway.amazonaws.com"

  source_arn = "${aws_apigatewayv2_api.lambda.execution_arn}/*/*"
}

# DynamoDB

resource "aws_dynamodb_table" "calculator" {
  name           = "calculator"
  hash_key       = "opId"
  billing_mode   = "PROVISIONED"
  read_capacity  = 20
  write_capacity = 20

  attribute {
    name = "opId"
    type = "S"
  }

  tags = {
    Name        = "calculator"
    Environment = "dev"
  }
}

resource "aws_iam_policy" "dynamoDBLambdaPolicy" {
  name = "DynamoDBLambdaPolicy"

  policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "dynamodb:*"
            ],
            "Resource": [
                "arn:aws:dynamodb:*:*:table/*"
            ]
        }
    ]
})
}

resource "aws_iam_role_policy_attachment" "lambda-policy-attachment" {
  role       = aws_iam_role.lambdaRole.name
  policy_arn = aws_iam_policy.dynamoDBLambdaPolicy.arn
}



# VPC

# //Creating a VPC 
# resource "aws_vpc" "main" {
#   cidr_block       = "10.0.0.0/16"
#   instance_tenancy = "default"

#   tags = {
#     Name = "main"
#   }
# }

# //Creating a private subnet 
# resource "aws_subnet" "private_subnets" {
#  count      = length(var.private_subnet_cidrs)
#  vpc_id     = aws_vpc.main.id
#  cidr_block = element(var.private_subnet_cidrs, count.index)
 
#  tags = {
#    Name = "Private Subnet ${count.index + 1}"
#  }
# }

# # resource "aws_route_table" "PrivateRT" {    # Creating RT for Private Subnet
# #    vpc_id = aws_vpc.Main.id
# #    route {
# #    cidr_block = "0.0.0.0/0"             # Traffic from Private Subnet reaches Internet via NAT Gateway
# #    nat_gateway_id = aws_nat_gateway.NATgw.id
# #    }
# #  }

# //Creating a Priavte Link API that should work as a bridge between the Subnets inside the VPC outside the VPC, and is connectd to the application load balancer only 
# resource "aws_apigatewayv2_vpc_link" "VPC_Private_Link" {
#   name               = "VPC_Private_Link"
#   security_group_ids = [data.aws_security_group.VPC_Private_Link.id]
#   subnet_ids         = data.aws_subnet_ids.VPC_Private_Link.ids

#   tags = {
#     Usage = "VPC_Private_Link"
#   }
# }


# #  resource "aws_route_table_association" "PrivateRTassociation" {
# #     subnet_id = aws_subnet.privatesubnets.id
# #     route_table_id = aws_route_table.PrivateRT.id
# #  }

# //Creating an Application Load Balancer
#  resource "aws_lb" "test" {
#   name               = "test-lb-tf"
#   internal           = false
#   load_balancer_type = "application"
#   security_groups    = [aws_security_group.lb_sg.id]
#   subnets            = [for subnet in aws_subnet.public : subnet.id]

#   enable_deletion_protection = true

#   access_logs {
#     bucket  = aws_s3_bucket.lb_logs.bucket
#     prefix  = "test-lb"
#     enabled = true
#   }

#   tags = {
#     Environment = "production"
#   }
# }

# # resource "aws_lb" "LB" {
# #   name               = "LB"
# #   load_balancer_type = "network"

# #   subnet_mapping {
# #     subnet_id            = aws_subnet.APL.id
# #     private_ipv4_address = "10.0.4.0/24"
# #   }

# #   subnet_mapping {
# #     subnet_id            = aws_subnet.EC2.id
# #     private_ipv4_address = "10.0.5.0/24"
# #   }

# # }