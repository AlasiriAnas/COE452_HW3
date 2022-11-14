output "calc_api_gw_url" {
    description = "Public URL of Calculator API Gateway"
    value       = resource.aws_apigatewayv2_stage.lambda.invoke_url
}