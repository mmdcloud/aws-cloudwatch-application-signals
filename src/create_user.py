import boto3
import json
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Users')

def lambda_handler(event, context):
    body = json.loads(event['body'])
    name = body['name']
    email = body['email']
    user_id = str(uuid.uuid4())
    
    response = table.put_item(
        Item={
            'user_id': user_id,
            'name': name,
            'email': email
        }
    )
    
    return {
        'statusCode': 200,
        'body': json.dumps({'message': 'User created successfully', 'user_id': user_id})
    }