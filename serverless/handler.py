# OPS-250: the Lambda code. AWS runs handler() every time someone visits the API URL.
import datetime
import os
import time

import boto3  # AWS's Python library; already included in the Lambda runtime

s3 = boto3.client("s3")
BUCKET = os.environ["BUCKET"]


def handler(event, context):
    # break #2 sets DELAY_SECONDS above the 3-second timeout
    time.sleep(int(os.environ.get("DELAY_SECONDS", "0")))

    key = "uploads/" + datetime.datetime.now(datetime.timezone.utc).strftime("%Y%m%dT%H%M%S%f") + ".txt"
    s3.put_object(Bucket=BUCKET, Key=key, Body=b"hello from hello-lab\n")

    print(f"saved s3://{BUCKET}/{key}")  # goes to CloudWatch Logs
    return {
        "statusCode": 200,
        "headers": {"Content-Type": "text/plain"},
        "body": f"saved {key}\n",
    }
