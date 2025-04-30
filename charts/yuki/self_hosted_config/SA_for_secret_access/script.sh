EKS_CLUSTER_NAME="" # system-stage
AWS_REGION="" # us-east-1
AWS_ACCOUNT_ID="" # 406122784773
NAMESPACE="" # test-proxy
POLICY_NAME="" # YU-657-Proxy-Secret-Access-Policy-test
SERVICE_ACCOUNT_NAME="" # yuki-proxy-sa-test
SECRET_NAME="" # yu-657_test
eksctl utils associate-iam-oidc-provider \
  --region $AWS_REGION \
  --cluster $EKS_CLUSTER_NAME \
  --approve

OIDC_PROVIDER=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION \
  --query "cluster.identity.oidc.issuer" --output text)

echo $OIDC_PROVIDER

# Replace placeholders in the policy document
sed -i '' "s/AWS_REGION/$AWS_REGION/g" secrets-access-policy.json
sed -i '' "s/AWS_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" secrets-access-policy.json
sed -i '' "s/SECRET_NAME/$SECRET_NAME/g" secrets-access-policy.json

aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://secrets-access-policy.json

# creates role with a pattern eksctl-$EKS_CLUSTER_NAME-addon-*
eksctl create iamserviceaccount \
  --name $SERVICE_ACCOUNT_NAME \
  --namespace $NAMESPACE \
  --cluster $EKS_CLUSTER_NAME \
  --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
  --approve \
  --override-existing-serviceaccounts

###############################################
# Debugging commands - don't send to customer #
###############################################

# apt-get update &&  \
#   apt-get install -y apt-transport-https ca-certificates curl unzip && \
#   curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip" &&  \
#   unzip awscliv2.zip && \
#   ./aws/install --update && \
#   apt install less


# aws secretsmanager get-secret-value --secret-id yu-657_test
# aws secretsmanager get-secret-value --secret-id postgres_password


# apt-get update && apt-get install -y \
#   python3 \
#   python3-pip \
#   python3-venv \
#   && rm -rf /var/lib/apt/lists/* && \
#   python3 -m venv /opt/venv && \
#   source /opt/venv/bin/activate

# pip install boto3
# python3

# import boto3
# client = boto3.client('secretsmanager')
# response = client.get_secret_value(SecretId='yu-657_test')
# secret = response['SecretString']
# print(secret)