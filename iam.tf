data "template_file" "iam_lambda_exec_role_policy" {
  template = file("./files/iam_policies/lambda_exec_role.json")
}

module "iam_lambda_exec_role" {
  source              = "./modules/iam"
  name                = local.iam_lambda_exec_role_name
  is_instance_profile = 0
  description         = ""
  env                 = var.env
  assume_role_policy  = <<-DOC
    {
      "Version": "2008-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": ["lambda.amazonaws.com"]
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  DOC
  policy              = data.template_file.iam_lambda_exec_role_policy.rendered
  managed_policy_arns = ["arn:aws:iam::aws:policy/AmazonEC2FullAccess"]
}

data "template_file" "iam_ec2_role_policy" {
  template = file("./files/iam_policies/ec2_role.json")
}

module "iam_ec2_role" {
  source              = "./modules/iam"
  name                = local.iam_ec2_role_name
  is_instance_profile = 1
  description         = ""
  env                 = var.env
  assume_role_policy  = <<-DOC
    {
      "Version": "2008-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Principal": {
            "Service": ["ec2.amazonaws.com"]
          },
          "Action": "sts:AssumeRole"
        }
      ]
    }
  DOC
  policy              = data.template_file.iam_ec2_role_policy.rendered
}
