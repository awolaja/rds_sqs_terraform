variable "vpc_id" {
}

variable "subnet_ids" {
}

variable "security_group_ids" {
}

variable "account_number" {

}
variable "env" {
  default = "dev"
}

variable "region" {
  default = "us-east-1"
}

variable "az" {
  default = "us-east-1a"
}

variable "sns_notifications_email" {

}

variable "db_subnet_group_name" {

}

variable "db_instance_class" {

}

variable "ec2_instance_class" {

}

variable "sqlserver_ami_id" {
  default = "ami-0c38083e32ff6dda3"
}

variable "ssh_keypair_name" {

}

variable "sql_engine" {
  default = "sqlserver-se"
}

variable "sql_engine_version" {
  default = "14.00.3451.2.v1"
}
