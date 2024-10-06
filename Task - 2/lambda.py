import json

def lambda_handler(event, context):
    
    return {
        "message": "New File Created in S3 bucket",
        "event": json.dumps(event)
    }