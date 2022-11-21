import boto3
from botocore.exceptions import ClientError
import os


def lambda_handler(event, context):
    # creates client for the given service parameter
    def create_client(service):
        return boto3.client(service, region_name='us-east-1')
    
    # sends RDS endpoint to SQS queue and sends an email notification using SNS
    def send_rds_details_to_sqs_sns(event):
        # get RDS endpoint
        rds_client = create_client('rds')
        rds_arn = event['detail']['SourceArn']  # Contains ARN of the RDS DB instance
        desc_rds_resp = client.describe_db_instances(DBInstanceIdentifier=rds_arn)['DBInstances'][0]
        endpoint = desc_rds_resp['Endpoint']['Address']  # Contains DB instance endpoint
        
        # send RDS endpoint to SQS queue
        sqs_client = create_client('sqs')
        send_msg_resp = sqs_client.send_message(QueueUrl=os.environ.get('RDS_ENDPOINT_QUEUE_URL'), MessageBody=endpoint)
        
        #send email notification using SNS
        sns_client = create_client('sns')
        send_email_resp = sns_client.publish(TopicArn=os.environ.get('SNS_TOPIC'), Message="RDS Instance created successfully. Access the database using this endpoint: {0}".format(endpoint))
    
    try:
        send_rds_details_to_sqs_sns(event)
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
