import json

def lambda_handler(event, context):
    
    return {
        "statusCode": 200, 
        "body": "Hello World from API Gateway with Lambda Proxy"
    }