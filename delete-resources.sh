#!/bin/bash
source config.env
source created_resources.env

echo "Terminating EC2 instance: $INSTANCE_ID ..."
aws ec2 terminate-instances --instance-ids $INSTANCE_ID --region $AWS_REGION
aws ec2 wait instance-terminated --instance-ids $INSTANCE_ID --region $AWS_REGION

echo "Deleting Security Group: $SG_ID ..."
aws ec2 delete-security-group --group-id $SG_ID --region $AWS_REGION

echo "Deleting Key Pair: $KEY_PAIR_NAME ..."
aws ec2 delete-key-pair --key-name $KEY_PAIR_NAME --region $AWS_REGION
rm -f ${KEY_PAIR_NAME}.pem

aws s3 rm s3://$S3_BUCKET_NAME --recursive
aws s3api delete-bucket --bucket $S3_BUCKET_NAME --region $AWS_REGION
echo "Cleanup Completed."
