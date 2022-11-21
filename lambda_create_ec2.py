import boto3
from botocore.exceptions import ClientError
from time import sleep
import os
from uuid import uuid4


def lambda_handler(event, context):
    # creates client for the given service parameter
    def create_client(service):
        return boto3.client(service, region_name='us-east-1')

    # creates ec2 instance and send EIP to SQS
    def create_ec2_instance():
        # create EIP to associate to EC2
        ec2_client = create_client('ec2')
        create_eip_resp = ec2_client.allocate_address(Domain='vpc')
        eip = create_eip_resp['PublicIp']
        allocation_id = create_eip_resp['AllocationId']

        # create EC2 instance
        ec2_name = '{0}-{1}-ec2-sql-server'.format(os.environ.get('ACCOUNT_ID'), uuid4())
        create_ec2_resp = ec2_client.run_instances(ImageId='ami-0c38083e32ff6dda3', InstanceType='c1.xlarge',
                                                   SubnetId=os.environ.get('SUBNET_ID'), MinCount=1,
                                                   MaxCount=1, TagSpecifications=[{'ResourceType': 'instance',
                                                                                   'Tags': [
                                                                                       {'Key': 'Name', 
                                                                                        'Value': ec2_name}
                                                                                   ]}])['Instances']
        instance_id = create_ec2_resp[0]['InstanceId']

        # waiter for creating ec2 instance
        max_retries = 30
        while max_retries > 0:
            desc_ec2_resp = ec2_client.describe_instances(InstanceIds=[instance_id])['Reservations'][0]['Instances'][0]
            if desc_ec2_resp['State']['Name'] == 'running':
                break
            max_retries -= 1
            sleep(5)

        # associate EIP to the EC2 instance
        associate_ec2_resp = ec2_client.associate_address(AllocationId=allocation_id, InstanceId=instance_id)
        send_eip_to_sqs(eip)

    def send_eip_to_sqs(eip):
        client = create_client('sqs')
        send_msg_resp = client.send_message(QueueUrl=os.environ.get('EIP_QUEUE_URL'),
                                            MessageBody=eip)

    try:
        create_ec2_instance()
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
