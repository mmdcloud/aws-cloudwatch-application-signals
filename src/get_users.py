import boto3
import json
import uuid

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Users')

def lambda_handler(event, context):
    user_id = event['pathParameters']['userId']
    
    response = table.get_item(Key={'user_id': user_id})
    user = response.get('Item')
    
    if user:
        return {
            'statusCode': 200,
            'body': json.dumps(user)
        }
    else:
        return {
            'statusCode': 404,
            'body': json.dumps({'message': 'User not found'})
        }