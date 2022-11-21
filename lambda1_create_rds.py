import boto3
from botocore.exceptions import ClientError
from uuid import uuid4
import string
from random import choice
import os


def lambda_handler(event, context):
    # creates client for the given service parameter
    def create_client(service):
        return boto3.client(service, region_name='us-east-1')

    # generates random password for RDS instance
    def generate_password(length):
        chars = string.ascii_letters + string.digits
        return ''.join(choice(chars) for i in range(length))

    # creates RDS DB instance and sends DB information to the email using SNS
    def create_rds_instance():
        # create DB Instance
        rds_client = create_client('rds')
        db_instance_identifier = '{0}-{1}-rds-sql-server'.format(os.environ.get('ACCOUNT_ID'), uuid4())
        password = generate_password(20)
        create_rds_resp = rds_client.create_db_instance(DBInstanceIdentifier=db_instance_identifier,
                                                        AllocatedStorage=20, DBInstanceClass='db.t3.xlarge',
                                                        Engine='sqlserver-se', EngineVersion='14.00.3451.2.v1',
                                                        LicenseModel='license-included', MasterUsername='admin',
                                                        MasterUserPassword=password, AvailabilityZone='us-east-1a',
                                                        DBSubnetGroupName=os.environ.get("SUBNET_GROUP_NAME"),
                                                        Port=1433, PubliclyAccessible=True)['DBInstance']

        # send DBInstanceIdentifier, username and password to an email using SNS
        sns_client = create_client('sns')
        send_email_resp = sns_client.publish(TopicArn=os.environ.get('SNS_TOPIC'),
                                             Message="Started Creating RDS DB instance. Here is the DB "
                                                     "information: \nDB Instance Identifier: {0} \nUsername: {1} "
                                                     "\nPassword: {2}".format(db_instance_identifier, 'admin',
                                                                              password))
    try:
        create_rds_instance()
    except ClientError as e:
        return {
            'statusCode': 500,
            'body': 'Error occurred during boto3 call: {0}'.format(e)
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': 'Error occurred during lambda function execution: {0}'.format(e)
        }
    return {
        'statusCode': 200,
        'body': 'Lambda function execution Successful'
    }
