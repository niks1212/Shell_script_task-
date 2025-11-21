source config.env
echo "===== Starting AWS Resource Creation ====="

echo "Creating Key Pair: $KEY_PAIR_NAME ..."
aws ec2 create-key-pair --region $AWS_REGION --key-name $KEY_PAIR_NAME \
  --query 'KeyMaterial' --output text > ${KEY_PAIR_NAME}.pem 2>/dev/null
chmod 400 ${KEY_PAIR_NAME}.pem

echo "Checking if Security Group exists..."
SG_ID=$(aws ec2 describe-security-groups \
  --filters Name=group-name,Values=$SECURITY_GROUP_NAME \
  --query 'SecurityGroups[0].GroupId' --output text --region $AWS_REGION)

if [[ "$SG_ID" == "None" ]]; then
  echo "Creating Security Group: $SECURITY_GROUP_NAME ..."
  SG_ID=$(aws ec2 create-security-group \
    --group-name $SECURITY_GROUP_NAME \
    --description "Auto-created security group" \
    --region $AWS_REGION \
    --query 'GroupId' --output text)

  aws ec2 authorize-security-group-ingress \
    --group-id $SG_ID --protocol tcp --port 22 --cidr 0.0.0.0/0 \
    --region $AWS_REGION
else
  echo "Security Group already exists: $SG_ID"
fi

RANDOM_ID=$RANDOM
S3_BUCKET_NAME="${S3_BUCKET_PREFIX}-${RANDOM_ID}"

echo "Creating S3 bucket: $S3_BUCKET_NAME ..."
if [[ "$AWS_REGION" == "us-east-1" ]]; then
  aws s3api create-bucket --bucket $S3_BUCKET_NAME --region $AWS_REGION
else
  aws s3api create-bucket --bucket $S3_BUCKET_NAME --region $AWS_REGION \
    --create-bucket-configuration LocationConstraint=$AWS_REGION
fi

echo "Launching EC2 Instance ..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id $AMI_ID \
  --instance-type $INSTANCE_TYPE \
  --key-name $KEY_PAIR_NAME \
  --security-group-ids $SG_ID \
  --region $AWS_REGION \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$EC2_INSTANCE_NAME}]" \
  --query 'Instances[0].InstanceId' --output text)

echo "SG_ID=$SG_ID" > created_resources.env
echo "INSTANCE_ID=$INSTANCE_ID" >> created_resources.env
echo "S3_BUCKET_NAME=$S3_BUCKET_NAME" >> created_resources.env

echo "===== Resource Creation Complete ====="
echo "Created:"
echo "EC2 Instance: $INSTANCE_ID"
echo "Security Group: $SG_ID"
echo "S3 Bucket: $S3_BUCKET_NAME"
