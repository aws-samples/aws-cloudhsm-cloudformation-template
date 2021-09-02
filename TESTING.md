# Test Cases

* [Static Analysis](#static-analysis)
* [CloudHSM Cluster Only](#cloudhsm-cluster-only)
* [CloudHSM Cluster with KMS Custom Key Store](#cloudhsm-cluster-with-kms-custom-key-store)

## Static Analysis

The following tools run against each CloudFormation template without failures. Where warnings are expected and are filtered via metadata within the templates, the warning conditions must be documented inline within the template.

* `cfn-lint` 
* `cfn_guard` 

## CloudHSM Cluster Only

In all of these test cases, select the CloudHSM only deployment scope.

### Stack Creation

#### Stack Creation Happy Paths

* With default parameter settings except for choosing create CloudHSM cluster only
* Create a second stack in same account and different region using the default `pEnvPurpose` parameter value to demonstrate that the stacks can coexist in the same account
* Create a second stack in same account and region using a different `pEnvPurpose` parameter value than prior test to demonstrate the stacks can coexist in the same account
* Override `pSystem` parameter to change the default base prefix of many of the cloud resource names
* Change number of HSMs to 1
* Change number of HSMs to 3
* Use AMI ID instead of default AWS Systems Manager parameter store parameter
* Create CloudHSM using default parameters but supply backup ID of a CloudHSM cluster using the `pBackupId` parameter
  * Note that, in order to do a complete test of the newly deployed cluster, you will need the crypto office password from the cluster from which the backup was created.

#### Stack Creation Failures

* Attempt to create more CloudHSM clusters in a single account than allowed by quotas
* Attempt to create more CloudHSM HSMs in a single account than allowed by quotas
* Attempt to create a CloudHSM cluster using an invalid backup ID

#### Post Stack Creation

Confirm that:

* Proper number of HSMs have been created
* The state of the cluster and the associated HSM(s) are `Active`
* You can use the CloudHSM Management Utility from within the EC2 client instance to work with the HSMs. Follow the instructions in [README](./README.md) to:
  * "Inspect CloudHSM via the CloudHSM Management Utility"
  * "Changing the crypto officer password"

### Stack Deletion

* Delete stack that was created with default parameter values

### Post Stack Deletion

Confirm that all resources have been deleted except for:

* The customer CA certificate in AWS Secrets Manager
* Lambda log groups in CloudWatch Logs

### Stack Update

#### Updating the AMI

Deploy a new stack while specifying an older AMI ID (see below).

Update the stack with the ID of a newer AMI.  Doing so will cause the EC2 client instance to be replaced.

For example:
|Operation|AMI Name|us-east-1 AMI ID|us-east-2 AMI ID|
|---------|--------|----------------|----------------|
|Create the stack|`amzn2-ami-hvm-2.0.20210701.0-x86_64-gp2`|`ami-0dc2d3e4c0f9ebd18`|`ami-0233c2d874b811deb`| 
|Update the stack|`amzn2-ami-hvm-2.0.20210721.2-x86_64-gp2`|`ami-0c2b8ca1dad447f8a`|`ami-0443305dabd4be2bc`| 

#### Updating an IAM Role

* Modify an IAM role in the CloudHSM template and update the stack with the updated template

## CloudHSM Cluster with KMS Custom Key Store

### Stack Creation

#### Stack Creation Happy Paths

* With default parameter settings
* Override `pSystem` and `pEnvPurpose` parameters to customize resource names
* Create second stack in same account and region using a different `pEnvPurpose` parameter value than prior test to demonstrate that it can coexist
* Create a second stack in same account and region using a different `pEnvPurpose` parameter value than prior test to demonstrate the stacks can coexist in the same account
* Change number of HSMs to 1
* Change number of HSMs to 3
* Use AMI ID instead of default AWS Systems Manager parameter store parameter

#### Stack Creation Failure Scenarios

Override number of HSM to be 1 thereby causing the creation of custom key store to fail

### Usage of Custom Key Store

#### Use custom key store to create new key and use with an S3 bucket
* Create customer managed key associated with custom key store
* Create an S3 bucket with the CMK
* Test put and get operations against the bucket

#### Disconnect custom key store and reconnect to same cluster
* Perform previous test
* Disconnect custom key store from CloudHSM cluster
* Attempt to perform puts and gets with S3 bucket
* Reconnect key store
* Verify that puts and gets with S3 bucket are successful

#### Delete CloudHSM cluster, restore backup to new cluster, and connect key store to new cluster
* Perform first test above
* Manually delete HSMs and the CloudHSM cluster (deletion of each HSM will force a backup to be taken)
* Verify key store is disconnected and that S3 put and get operations fail
* Determine proper backup ID to use
* Create new CloudHSM cluster only stack specifying backup ID
* Connect key store to new cluster
* Verify that puts and gets with S3 bucket are successful

#### Manually add a 3rd HSM to a cluster
* Perform the first test above
* Via either AWS CLI or console, add a 3rd HSM to the cluster
* On the EC2 client:
  * Update the file `/opt/cloudhsm/etc/cloudhsm_mgmt_util.cfg` to add an entry for the newly added HSM
  * Restart the client service via `sudo systemctl restart cloudhsm-client.service`
  * Execute the management utility to ensure all three HSMs are connected to and listed
* Monitor the custom key store to see the number of HSM change from 2 to 3
* Verify that puts and gets with S3 bucket are successful

#### Manually delete one of the HSMs from the cluster
* Perform the first test above
* Manually delete one of the two HSMs
* Monitor the state of the key store
* Follow the test above to manually add an HSM

### Stack Deletion

### Post Stack Deletion

Confirm that all resources have been deleted except for:
* The customer CA certificate in AWS Secrets Manager
* The custom key store is retained and is in a disconnected state
* CloudWatch Logs are intact

### Stack Update

Perform the AMI change test as described above and verify that the replacement EC2 client can interact with the HSMs.