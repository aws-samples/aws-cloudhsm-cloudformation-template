# CloudHSM Cluster Lifecycle Management Test Cases

## Static Analysis

The following tools run against each CloudFormation template without failures. Where warnings are expected and are filtered via metadata within the templates, the warning conditions must be documented inline within the template.

* `cfn-lint` 
* `cfn_guard` 

## Prerequisites

**Delete Service Linked Roles**

Before each test, ensure that the following service linked roles have been deleted from the AWS account:
* `AWSServiceRoleForCloudHSM`
* `AWSServiceRoleForKeyManagementServiceCustomKeyStores`

**Plan to Test in Multiple Regions**

Ensure that you test the template in multiple AWS Regions including `us-east-1` and at least one other Region.

## Stack Creation

### Stack Creation Happy Paths

#### Common creation scenarios

* With default parameter settings and user-specified VPC and subnets
* Create a second stack in same account and different region using the default `pEnvPurpose` parameter value to demonstrate that the stacks can coexist in the same account
* Create a second stack in same account and region using a different `pEnvPurpose` parameter value than prior test to demonstrate the stacks can coexist in the same account
* Override `pSystem` parameter to change the default base prefix of many of the cloud resource names
* Change number of HSMs per subnet to 2
* Change number of HSMs per subnet to 3
* Vary the number of subnets
* Use AMI ID instead of default AWS Systems Manager parameter store parameter
* Validate that the `ClusterId` attribute is set properly.

#### Select CloudHSM client or CLI package

* Select to install the `cloudhsm-cli` package (override the default)

#### Create cluster from backup

* Create CloudHSM using default parameters but supply backup ID of a CloudHSM cluster using the `pBackupId` parameter
  * Note that, in order to do a complete test of the newly deployed cluster, you will need the crypto officer password from the cluster from which the backup was created.

#### Use external PKI process

* Specify `true` for using an external PKI process
  * See the stack update scenarios to continue once the cluster cert has been issued.
  * External PKI process bad data
    * Wrongly formatted cluster and/or customer CA certs
    * Cluster cert issued from wrong CSR

### Stack Creation Failures

Attempt to create a stack...

* Without specifying VPC and subnet parameters. 
* Without enabling internet connectivity from the subnet in which the EC2 client is to be deployed.
* Using the same `pSystemId` and `pEnvPurpose` settings as an existing stack.
* When the number of CloudHSM clusters in a single account would exceed the quota of 4 clusters.
* When the number of HSMs in a single account would exceed the quota of 6 HSMs.
  * Cause the 7th HSM to be created to be the first HSM in a cluster
  * Cause the 7th HSM to be created to not be the first HSM in a cluster
* With an invalid backup ID.
* In a region in which CloudHSM is not supported.
* In a subnet/AZ in which CloudHSM is not supported.
  * Specify a single subnet/AZ that is not supported.
  * Specify multiple subnets/AZs, but with only one that is not supported.
* Test both automated rollbacks and preserve resources upon creation failure.

In all failure scenarios, assess the extent to which resources are rolled back and a stack deletion causes deletion of resources.

### Post Stack Creation

Confirm that:

* Proper number of HSMs have been created
* The state of the cluster and the associated HSM(s) are `Active`
* You can use the CloudHSM Management Utility from within the EC2 client instance to work with the HSMs. Follow the instructions in [README](./README.md) to:
  * "Inspect CloudHSM via the CloudHSM Management Utility"
  * "Changing the crypto officer password"

## Stack Deletion

* Delete stack that was created with default parameter values

## Post Stack Deletion

Confirm that all resources have been deleted except for:

* The customer CA certificate in AWS Secrets Manager
* CloudWatch Logs log groups

## Stack Update

### Using external PKI Process

* Apply first update after updating CA cert and cluster cert in Secrets Manager
* Perform second update to ensure that cluster initialization and activation are not performed again

**Failure paths**

* Perform a stack update with certs ready set to `true`, but leave the default Secrets Manager secret in place.
* Provide a mismatched CA cert in Secrets Manager
* Provide a mismatched cluster cert in Secrets Manager

### Changing the number of HSMs per subnet

* Increase the number of HSMs per subnet.
  * Increase within the allowed quota of HSMs per account
  * Increase to exceed the allowed quota of HSMs per account
    * Enable at least one addition HSM to start creating, but at least one subsequent HSM creation fails due to quota
      * Ensure that stack rollback waits for HSMs to activate before attempting to rollback to prior state.
* Decrease the number of HSMs per subnet.
* Stop the EC2 client (do not terminate) prior to changing the number of HSMs per subnet.
* Set the number of HSMs per subnet to 0.
  * After successfully deleting all HSMs, apply another update with HSMs per subnet > 0.

### Updating the EC2 client subnet

* Change the subnet of the EC2 client

### Updating the AMI

Deploy a new stack while specifying an older AMI ID (see below).

Update the stack with the ID of a newer AMI.  Doing so will cause the EC2 client instance to be replaced.

For example:

|Operation|AMI Name|us-east-1 AMI ID|us-east-2 AMI ID|
|---------|--------|----------------|----------------|
|Create the stack|`amzn2-ami-hvm-2.0.20210701.0-x86_64-gp2`|`ami-0dc2d3e4c0f9ebd18`|`ami-0233c2d874b811deb`| 
|Update the stack|`amzn2-ami-hvm-2.0.20210721.2-x86_64-gp2`|`ami-0c2b8ca1dad447f8a`|`ami-0443305dabd4be2bc`| 

### Updating an IAM Role

* Modify an IAM role in the CloudHSM template and update the stack with the updated template

## Modifying resources outside of CloudFormation

Perform the following actions directly outside the CloudFormation stack:

* Terminate the EC2 client
* Add or more HSMs.
* Delete one or more HSMs without deleting the cluster.
  * Perform a stack update by changing the number of HSMs per subnet.
  * Delete the stack.
* Delete the HSMs and the cluster.
  * Delete the stack.