#!/bin/bash
#
# Testing Script for using your own PKI process
#
# Simulating your own PKI process, this will use AWS Private Certificate Authority (PCA) to issue a certificate 
# and store it in secrets manager so flow can continue.
#
# Script assumes PCA is in current account in current region
#
# Can be run with first argument = name of cloudformation stack needing update.
# If name of stack not provided, it will be prompted for.
#

#set -x

# set stackname; use $1 if provided, else prompt for stackname
if [ ! -z ${1+x} ] ; then 
  stackname=${1}
else
  echo "Please enter stackname: "
  read stackname
fi
echo "Proceeding with stackname = ${stackname}"

# Find Private an active CA in account to issue cluster cert
existing_ca_arn=$(aws acm-pca list-certificate-authorities   \
  --query 'CertificateAuthorities[?Status == `ACTIVE`].Arn' \
  --output text |awk '{print $1}')

echo "exising Private CA Arn:\n${existing_ca_arn}"

# Obtain system ID for use in Secrets Manager paths
system_id=$(aws cloudformation describe-stacks \
  --query "Stacks[?StackName=='${stackname}'].Parameters" --output text |\
  grep pSystem |  awk '{print $2}')
if [[ -z ${system_id} ]]; then 
  echo "ERROR: stack not found; Please confirm stackname"
  echo "Existing active stacks:"
  aws cloudformation list-stacks --query "StackSummaries[?StackStatus=='CREATE_COMPLETE'].StackName" --output table
  exit -1
fi 

# Get ClusterID for use in Secrets Manager paths
cloudhsm_cluster_id=$(aws cloudformation describe-stack-resources \
  --stack-name $stackname \
  --query 'StackResources[?ResourceType == `Custom::CustomClusterLauncher`].PhysicalResourceId' --output text)

if [ -z ${cloudhsm_cluster_id} ]; then
  echo "ERROR: cloudhsm_cluster not discovered as a stack resource in stack ${stackname}. Exiting"
  exit -1
fi

secret_prefix="/${system_id}/${cloudhsm_cluster_id}/"
  
# setup some working space
working_dir="temp_working_dir_010101"
mkdir -p ${working_dir}
temp_csr_file=${working_dir}/cloudhsm.csr
temp_cluster_cert_file=${working_dir}/temporary_file_for_cluster_cert
temp_customer_ca_cert_file=${working_dir}/temporary_file_for_customer_ca_cert

# Get CSR
aws secretsmanager get-secret-value --secret-id "${secret_prefix}cluster-csr" --query 'SecretString' --output text > ${temp_csr_file}
echo "CSR retrieved from secrets manager; written to ${temp_csr_file}"

# Issue Certificate
issued_certificate_arn=$(aws acm-pca issue-certificate \
  --certificate-authority-arn ${existing_ca_arn}  \
  --csr fileb://${temp_csr_file} \
  --signing-algorithm "SHA256WITHRSA" \
  --validity Value=365,Type="DAYS" \
  --idempotency-token 1234567 \
  --query 'CertificateArn' --output text)
echo; echo "Certificate being issued. waiting 30 seconds"
sleep 30
  
# Retrieve Cluster Cert
aws acm-pca get-certificate \
    --certificate-authority-arn ${existing_ca_arn} \
    --certificate-arn ${issued_certificate_arn} \
    --query 'Certificate' --output text > ${temp_cluster_cert_file} 
echo; echo "Certificate retrieved."
cat ${temp_cluster_cert_file} 

# Get Customer CA Cert
aws acm-pca get-certificate \
    --certificate-authority-arn ${existing_ca_arn} \
    --certificate-arn ${issued_certificate_arn} \
    --query 'CertificateChain' --output text > ${temp_customer_ca_cert_file}
echo; echo "Customer CA cert retrieved."
cat ${temp_customer_ca_cert_file}

## Now just put em back in secrets manager and update stack
# aws secretsmanager update-secret --secret-id "${secret_prefix}cluster-cert" --secret-string "${cluster_cert}"
aws secretsmanager update-secret --secret-id "${secret_prefix}cluster-cert" --secret-string file://${temp_cluster_cert_file}
echo "Cluster Cert Stored in Secrets Manager at: ${secret_prefix}cluster-cert"

aws secretsmanager update-secret --secret-id "${secret_prefix}customer-ca-cert" --secret-string file://${temp_customer_ca_cert_file}
echo "Customer CA Cert Stored in Secrets Manager at: ${secret_prefix}customer-ca-cert"

# prep for Cloudformation update - create parameters file
cat << EOF > ${working_dir}/cfn_params.json
[
  {
    "ParameterKey": "pExternallyProvidedCertsReady",
    "ParameterValue": "true"
  },
  {
    "ParameterKey": "pSystem",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pEnvPurpose",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pVpcId",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pSubnets",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pHsmsPerSubnet",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pHsmType",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pUseExternalPkiProcess",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pBackupRetentionDays",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pBackupId",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pClientPkg",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pClientSubnet",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pClientType",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pClientSubnet",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pClientAmiSsmParameter",
    "UsePreviousValue": true
  },
  {
    "ParameterKey": "pClientAmiId",
    "UsePreviousValue": true
  }
]
EOF

# Update Stack
aws cloudformation update-stack \
  --stack-name ${stackname}  \
  --use-previous-template \
  --capabilities CAPABILITY_NAMED_IAM \
  --color on \
  --parameters file://${working_dir}/cfn_params.json

# Now clean up temporary files
echo "Cleaning up temp files/directories"
rm -v ${temp_csr_file}
rm -v ${temp_cluster_cert_file}
rm -v ${temp_customer_ca_cert_file}
rm -v ${working_dir}/cfn_params.json
rmdir -v ${working_dir}

# Complete
echo;echo 
echo "============================================================================================== "
echo "Cloudformation stack is now being updated and will use external certificates "