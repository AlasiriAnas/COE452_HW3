#in this file we refrence every module in the project

# Configure the AWS provider

provider "aws" {
    region = "us-east-1"
    access_key = "..."
    secret_key = "..."
}

# create lambda functions 




# create vpc 

module "vpc" {

    source = "../Modules/VPC"
    region = var.region
    project_name = var.project_name
    vpc_cider = var.vpc_cider
    public_subnet_az1_cider = var.public_subnet_az1_cider
    private_app_subnet_az1_cider = var.private_app_subnet_az1_cider
    private_data_subnet_az1_cider = var.private_data_subnet_az1_cider
}

