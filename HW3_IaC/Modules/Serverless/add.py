import json

import boto3

dynamodb = boto3.client('dynamodb')

def lambda_handler(event, context):
    params = {
        "opId": {
            "S": f"{event['x']}+{event['y']}"
        }
    }
    res = dynamodb.get_item(
        TableName='calculator',
        Key=params,
    )
    if res.get("Item", None) != None:
        return {
        'statusCode': 200,
        'massage': 'found in the database',
        'body': {
            'x': event['x'],
            'y': event['y'],
            'op': 'add',
            'result': res['Item']['result']
            }
        }
    else:
        params['result'] = {'N': f"{event['x'] + event['y']}"}
        res = dynamodb.put_item(
            TableName='calculator',
            Item=params
        )
        return {
            'statusCode': 200,
            'massage': 'created in the database',
            'body': {
                'x': event['x'],
                'y': event['y'],
                'op': 'add',
                'result': params['result']
            }
        }