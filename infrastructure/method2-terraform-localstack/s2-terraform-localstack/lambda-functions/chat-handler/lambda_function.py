"""
Portfolio Chat Lambda Function
Production-grade Lambda that reads secrets from AWS Secrets Manager
"""
import json
import os
import boto3
from botocore.exceptions import ClientError

# Initialize AWS clients
# In LocalStack, Lambda needs to use LOCALSTACK_HOSTNAME to access services
localstack_host = os.environ.get('LOCALSTACK_HOSTNAME', 'localhost')
endpoint_url = f"http://{localstack_host}:4566"
secrets_client = boto3.client('secretsmanager', endpoint_url=endpoint_url)

def get_secret(secret_name):
    """Retrieve secret from AWS Secrets Manager"""
    try:
        response = secrets_client.get_secret_value(SecretId=secret_name)
        return response['SecretString']
    except ClientError as e:
        print(f"Error retrieving secret {secret_name}: {e}")
        raise

def lambda_handler(event, context):
    """
    Lambda handler for chat requests
    Demonstrates:
    - Reading from Secrets Manager
    - CloudWatch logging
    - API Gateway integration
    """
    print(f"Received event: {json.dumps(event)}")

    try:
        # Parse request body
        body = json.loads(event.get('body', '{}'))
        message = body.get('message', '')

        if not message:
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({'error': 'Message is required'})
            }

        # Get Claude API key from Secrets Manager
        print("Fetching Claude API key from Secrets Manager...")
        claude_api_key = get_secret('portfolio/claude-api-key')
        print(f"Successfully retrieved secret (length: {len(claude_api_key)})")

        # TODO: In production, call Claude API here
        # For now, return a demo response showing the Lambda is working
        response_data = {
            'response': f'Lambda function received your message: "{message}"',
            'secrets_manager': 'Successfully retrieved Claude API key from Secrets Manager',
            'metadata': {
                'function_name': context.function_name,
                'request_id': context.aws_request_id,
                'log_group': context.log_group_name,
                'secret_retrieved': True,
                'secret_length': len(claude_api_key)
            }
        }

        print(f"Response: {json.dumps(response_data)}")

        return {
            'statusCode': 200,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps(response_data)
        }

    except Exception as e:
        print(f"Error processing request: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({'error': str(e)})
        }
