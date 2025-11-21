echo "===== START: uninstall.sh ====="

source config.env
INSTANCE_IDS=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$EC2_INSTANCE_NAME" \
    --query "Reservations[*].Instances[*].InstanceId" \
    --output text)

if [[ -n "$INSTANCE_IDS" ]]; then
    echo "Terminating instances: $INSTANCE_IDS"
    aws ec2 terminate-instances --instance-ids $INSTANCE_IDS || true
else
    echo "No EC2 instances found."
fi

SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=$SECURITY_GROUP_NAME" \
    --query "SecurityGroups[0].GroupId" --output text 2>/dev/null)

if [[ "$SG_ID" != "None" ]]; then
    echo "Deleting security group: $SG_ID"
    aws ec2 delete-security-group --group-id "$SG_ID" || true
else
    echo "Security group not found."
fi

echo "Deleting key pair: $KEY_PAIR_NAME"
aws ec2 delete-key-pair --key-name "$KEY_PAIR_NAME" || true

if [[ -f "$KEY_PAIR_NAME.pem" ]]; then
    rm -f "$KEY_PAIR_NAME.pem"
fi

BUCKETS=$(aws s3api list-buckets --query "Buckets[?starts_with(Name, '$S3_BUCKET_PREFIX')].Name" --output text)

for BUCKET in $BUCKETS; do
    echo "Deleting S3 bucket: $BUCKET"
    aws s3 rb s3://$BUCKET --force || true
done

echo "===== END: uninstall.sh ====="
