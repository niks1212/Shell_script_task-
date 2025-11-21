set -euo pipefail


source config.env
echo "===== START: create.sh ====="

if ! command -v aws >/dev/null 2>&1; then
  echo "ERROR: aws CLI not installed"
  exit 1
fi

if ! aws sts get-caller-identity --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "ERROR: AWS credentials invalid"
  exit 1
fi

if ! aws ec2 describe-key-pairs --key-names "$KEY_PAIR_NAME" --region "$AWS_REGION" >/dev/null 2>&1; then
  echo "Creating key pair: $KEY_PAIR_NAME"
  aws ec2 create-key-pair --key-name "$KEY_PAIR_NAME" --region "$AWS_REGION" --query "KeyMaterial" --output text > "${KEY_PAIR_NAME}.pem"
  chmod 400 "${KEY_PAIR_NAME}.pem" || true
else
  echo "Key pair exists: $KEY_PAIR_NAME"
fi

SG_ID=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" --region "$AWS_REGION" --query "SecurityGroups[0].GroupId" --output text 2>/dev/null || echo "")
if [[ -z "$SG_ID" || "$SG_ID" == "None" ]]; then
  echo "Creating security group: $SECURITY_GROUP_NAME"
  SG_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "Auto SG" --region "$AWS_REGION" --query "GroupId" --output text)
  aws ec2 authorize-security-group-ingress --group-id "$SG_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0 --region "$AWS_REGION"
else
  echo "Security group exists: $SG_ID"
fi

RND=$RANDOM
S3_BUCKET_NAME="${S3_BUCKET_PREFIX}-${RND}"
echo "Creating S3 bucket: $S3_BUCKET_NAME"
aws s3api create-bucket --bucket "$S3_BUCKET_NAME" --region "$AWS_REGION"

echo "Launching EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_PAIR_NAME" \
  --security-group-ids "$SG_ID" \
  --region "$AWS_REGION" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$EC2_INSTANCE_NAME}]" \
  --query "Instances[0].InstanceId" --output text)

echo "Instance ID: $INSTANCE_ID"

aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region "$AWS_REGION"


PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$AWS_REGION" --query "Reservations[0].Instances[0].PublicIpAddress" --output text)


cat > "$SUMMARY_FILE" <<EOF
EC2_INSTANCE_ID=$INSTANCE_ID
EC2_PUBLIC_IP=$PUBLIC_IP
SECURITY_GROUP_ID=$SG_ID
S3_BUCKET_NAME=$S3_BUCKET_NAME
EOF

echo "===== Creation Summary ====="
cat "$SUMMARY_FILE"
echo "===== END: create.sh ====="
