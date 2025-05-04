AWS_REGION="us-east-1" # us-east-1
EKS_CLUSTER_NAME="" # system-stage
AWS_ACCOUNT_ID="406122784773" # 406122784773
SERVICE_TAG_KEY="service" # service
SERVICE_TAG_VALUE="yuki-proxy" # yuki-proxy
ROLE_NAME="yuki-proxy-secret-access-role" # yuki-proxy-secret-access-role
POLICY_NAME="yuki-proxy-secret-access-policy" # yuki-proxy-secret-access-policy

SERVICE_ACCOUNT_NAME="" # yuki-proxy-sa
NAMESPACE="" # yuki-proxy

# Check if OIDC provider is associated with the cluster, and if not, associate it
OIDC_PROVIDER_ID=$(aws eks describe-cluster --name $EKS_CLUSTER_NAME --region $AWS_REGION --query "cluster.identity.oidc.issuer" --output text | cut -d'/' -f5)
[[ -z $OIDC_PROVIDER_ID ]] && eksctl utils associate-iam-oidc-provider --region $AWS_REGION --cluster $EKS_CLUSTER_NAME --approve


# Replace placeholders in the policy document
sed -i '' "s/SERVICE_TAG_KEY/$SERVICE_TAG_KEY/g" secrets-access-policy.json
sed -i '' "s/SERVICE_TAG_VALUE/$SERVICE_TAG_VALUE/g" secrets-access-policy.json

# Create policy
aws iam create-policy \
  --policy-name $POLICY_NAME \
  --policy-document file://secrets-access-policy.json

# Replace placeholders in the trust document
sed -i '' "s/AWS_REGION/$AWS_REGION/g" trust.json
sed -i '' "s/AWS_ACCOUNT_ID/$AWS_ACCOUNT_ID/g" trust.json
sed -i '' "s/OIDC_PROVIDER_ID/$OIDC_PROVIDER_ID/g" trust.json
sed -i '' "s/NAMESPACE/$NAMESPACE/g" trust.json
sed -i '' "s/SERVICE_ACCOUNT_NAME/$SERVICE_ACCOUNT_NAME/g" trust.json

# Create IAM service account
aws iam create-role \
  --role-name $ROLE_NAME \
  --assume-role-policy-document file://trust.json

# Attach policy to IAM service account
aws iam attach-role-policy \
  --role-name $ROLE_NAME \
  --policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME


###############################################
# Debugging commands - don't send to customer #
###############################################

# k apply -f test_pod.yaml
# kubectl exec -it secrets-test -n $NAMESPACE -- bash
# yum install -y aws-cli less
# aws secretsmanager get-secret-value --secret-id $YOUR_SECRET_NAME

#####################################################
# Alternative setup for service account with eksctl #
#####################################################
# eksctl create iamserviceaccount \
#   --name $SERVICE_ACCOUNT_NAME \
#   --namespace $NAMESPACE \
#   --cluster $EKS_CLUSTER_NAME \
#   --attach-policy-arn arn:aws:iam::$AWS_ACCOUNT_ID:policy/$POLICY_NAME \
#   --approve \
#   --override-existing-serviceaccounts