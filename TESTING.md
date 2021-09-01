# Test Cases

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
* Create a second stack in same account and region using a different `pEnvPurpose` parameter value than prior test to demonstrate the stacks can coexist in the same accunt
* Override `pSystem` parameter to change the default base prefix of many of the cloud resource names
* Change number of HSMs to 1
* Change number of HSMs to 3
* Use AMI ID instead of default AWS Systems Manager parameter store parameter
* Create CloudHSM using default parameters but supply backup ID of a CloudHSM cluster

#### Stack Creation Failures

* Attempt to create more CloudHSM clusters in a single account than allowed by quotas
* Attempt to create more CloudHSM HSMs in a single account than allowed by quotas

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

#### AMI Change

Deploy a new stack while specifying an older AMI ID (see below).

Update the stack with the ID of a newer AMI.  Doing so will cause the EC2 client instance to be replaced.

For example:
|Operation|AMI Name|us-east-1 AMI ID|us-east-2 AMI ID|
|---------|--------|----------------|----------------|
|Create the stack|`amzn2-ami-hvm-2.0.20210701.0-x86_64-gp2`|`ami-0dc2d3e4c0f9ebd18`|`ami-0233c2d874b811deb`| 
|Update the stack|`amzn2-ami-hvm-2.0.20210721.2-x86_64-gp2`|`ami-0c2b8ca1dad447f8a`|`ami-0443305dabd4be2bc`| 

## CloudHSM Cluster with Custom Key Store

### Stack Creation

#### Stack Creation Happy Paths

* With default parameter settings
* Override `pSystem` and `pEnvPurpose` parameters to customize resource names
* Create second stack in same account and region using a different `pEnvPurpose` parameter value than prior test to demonstrate that it can coexist
* Change number of HSMs to 1
* Change number of HSMs to 3
* Use AMI ID instead of default AWS Systems Manager parameter store parameter

#### Stack Creation Failure Scenarios

* Override number of HSM to be 1 thereby causing the creation of custom key store to fail

### Stack Deletion

### Post Stack Deletion

Confirm that:

* All resources have been deleted except for:
  * The customer CA certificate in AWS Secrets Manager
  * The custom key store is retained and is in a disconnected state

### Stack Update

Perform the AMI change test as described above.
