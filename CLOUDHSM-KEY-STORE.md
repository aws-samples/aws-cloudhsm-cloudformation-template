# Automated Provisioning of AWS CloudHSM Key Stores Using AWS CloudFormation

The `cloudhsm-key-store.yml` AWS CloudFormation template creates an [CloudHSM key store for KMS](https://docs.aws.amazon.com/kms/latest/developerguide/custom-key-store-overview.html) and connects it to the CloudHSM cluster.

This template is intended to be used for learning and experimentation purposes. If you would like to learn more about the supporting CloudFormation custom resource and how its use AWS Step Functions state machines and other AWS services, see [INTERNALS](./INTERNALS.md).

This template does not depend on the presence of a stack created using the `cloudhsm.yml` template. See the [Usage](#usage) information for prerequisites before you use the `cloudhsm-key-store.yml` template. 

* [Overview](#overview)
* [Usage](#usage)
* [Managing security](#managing-security)
* [Reviewing template parameters](#reviewing-template-parameters)
* [Creating the stack](#creating-the-stack)
* [Troubleshooting stack creation](#troubleshooting-stack-creation)
* [Updating the stack](#updating-the-stack)
* [Deleting the stack](#deleting-the-stack)
* [Notifying of potential security issues](#notifying-of-potential-security-issues)
* [Contributing](#contributing)
* [License](#license)

## Overview

The [`cloudhsm-key-store.yml`](cloudhsm-key-store.yml) template enables you to create, update, and delete a CloudHSM key store. 

In addition to a CloudHSM key store, the following supporting resources are created:

* A `kmsuser` Crypto User is created in the specified CloudHSM cluster
* A CloudFormation custom resource AWS Lambda function is used to create, update, and delete the key store
* AWS Step Functions state machines are used to orchestrate creating, updating, and deleting the key store
* Lambda functions are used to support the state machines
* An AWS Systems Manager document is used by steps in the state machines to execute scripts on the EC2 client in support of creating and updating a `kmsuser` in the associated CloudHSM cluster
* IAM service roles are used to support the resources referenced above

## Usage

### Reviewing the opinionated approach

This CloudFormation template takes an opinionated approach to creating and managing a CloudHSM key store. Since this approach might not be aligned with your organization's requirements, you should review the approach before using the template.

### Preparing to create a CloudHSM key store

You should address the following considerations before using the template.

#### 1. Review CloudHSM key store documentation

Ensure that you're familiar with the capabilities and constraints of using a [CloudHSM key store for KMS](https://docs.aws.amazon.com/kms/latest/developerguide/custom-key-store-overview.html)

#### 2. Determine qualifier for cloud resource names

Determine a value for the [`pEnvPurpose`](#reviewing-template-parameters) CloudFormation template parameter that will be used to help qualify the names of many of the cloud resources created by the stack.  If you intend to deploy only one instance of the stack and CloudHSM key store in the AWS account, then you can use the default value.

Many of the resources created by the template will be qualified by a combination of the `pSystem` and `pEnvPurpose` parameter values. Normally, you won't need to override the value of the `pSystem` parameter, but if you intend to manage multiple CloudHSM key stores in the same account, then you will need to use the `pEnvPurpose` parameter to help distinguish the resources used to support the respective clusters. For example, if you create multiple stacks in the same account and in the same Region for testing purposes, then specify values such as `test1` vs `test2` for the `pEnvPurpose` parameter.

Since the template automatically qualifies the names of global resources such as IAM roles with the AWS Region identifier, you do not need to include a Region identifier in the `pEnvPurpose` parameter.

#### 3. Identify a CloudHSM cluster

Ensure that you've reviewed [AWS CloudHSM key store concepts](https://docs.aws.amazon.com/kms/latest/developerguide/hsm-key-store-concepts.html). Ensure that your CloudHSM cluster of interest has two HSMs in two availability zones (AZs).

If a `kmsuser` already exists in the cluster, creation of the key store using this template will fail.

If you don't already have a compatible CloudHSM cluster, you should review the [README](./README.md) for how to use the `cloudhsm.yml` template to create a CloudHSM cluster.

#### 4. Identify an EC2 client

If you used the companion `cloudhsm.yml` template to create the cluster, then the EC2 client associated with the cluster will satisfy most of the requirements of this CloudHSM key store template.

|Requirement|Addressed by `cloudhsm.yml` template?|Description|
|-----------|-------------------------------------|----------------|
|`cloudhsm-cli` package installed and configured.|Yes|An EC2 instance in which the `cloudhsm-cli` package is installed and configured is required.<br><br>If you did not opt to have the `cloudhsm-cli` package installed during creation of the cluster, you can chose to have it installed via an update to the CloudHSM cluster stack. See [`README`](./README.md) for details.|
|CA certificate|Yes|The EC2 instance must be configured with the CA certificate used to issue the cluster certificate.<br><br>If you used the companion `cloudhsm.yml` template to create the cluster, then the CA certificate will already be configured on the EC2 client.|
|AWS managed policy `AmazonSSMManagedInstanceCore`|Yes|The EC2 client must be configured with the AWS Systems Manager agent and the AWS IAM role associated with the instance must include the AWS managed policy `AmazonSSMManagedInstanceCore`.|

#### 5. Ensure Secrets Manager secrets are available

This template requires two secrets in AWS Secrets Manager.

|Template parameter|Description|
|------------------|-----------|
|`pCloudHsmAdminPasswordSecretName`|The name of a secret in Secrets Manager that contains the Crypto Officer (CO) or admin user's current password. The secret string is expected to be in string format (not binary).<br><br>If you used the `cloudhsm.yml` template to create a CloudHSM cluster, then a secret should already exist in Secrets Manager. Ensure tht the secret contains the value of the current Crypto Officer (CO) or admin user's password.|
|`pCloudHsmCustCaCertSecretName`|The name of a secret in Secrets Manager that contains the customer CA certificate used to issue the CloudHSM's cluster certificate. The secret string is expected to be in string format (not binary).<br><br>If you used the `cloudhsm.yml` template to create a CloudHSM cluster, then a secret should already exist in Secrets Manager.|

## Managing security

You should take steps to properly secure the Crypto Officer (CO) user's password that is accessed by the template to create the required `kmsuser` in the specified CloudHSM cluster.

### Static analysis of the CloudFormation templates

The CloudFormation template `cloudhsm-key-store.yml` has been scanned using the `cfn_nag` and `bandit` tools.

Stelligent's [cfn_nag](https://github.com/stelligent/cfn_nag) static analysis tool has been used to evaluate vulnerabilities within the template. All `failing` findings have been resolved. `warning` findings have been left intact to inform users of potential security findings that should be reviewed before using the templates. For a complete report of the warnings and notes on why they were not resolved, see the `security/` folder.

PyCQA's [bandit](https://github.com/PyCQA/bandit) static analysis tool has be used to evaluate inline Python code contained in the template. No issues were identified based on these tests. See the `security/` folder for `bandit` results. If you'd like to run `bandit` on your own against the inline Python code, see the example script under `./test/scripts/bandit-inline-python.sh`.

## Reviewing template parameters

|Parameter|Required|Description|Default|Supported in Stack Updates?|
|---------|--------|-----------|-------|---------------------------|
|`pSystem`|Optional|Used as a prefix in the names of many of the newly created cloud resources. You normally do not need to override the default value.|`cloudhsm`|No|
|`pEnvPurpose`|Optional|Identifies the purpose for this particular instance of the stack. Used as part of the prefix in the names of many of the newly created resources. Enables you to create and more easily distinguish resources of multiple stacks in the same AWS account. For example, `1`, `2`, `test1`, `test2`, etc.|`1`|No|
|`pKeyStoreName`|Optional|The name of the CloudHSM key store to be created.|`cloudhsm-key-store`|No|
|`pDeleteKeyStoreUponStackDeletion`|Optional|Set to `false` if you'd like the key store to be disconnected, but not deleted upon stack deletion. Set to `true` if you want the key store to be deleted upon stack deletion.<br><br>Since a CloudHSM key store cannot be deleted when KMS keys are associated with the key store, this template will not attempt to delete a key store with which kes are associated even when this parameter is set to `true`.|`false`|No|
|`pCloudHsmClusterId`|Required|The ID of the CloudHSM cluster to which the key store will be connected.|None|No|
|`pCloudHsmAdminPasswordSecretName`|Required|The name of a secret in Secrets Manager that contains the Crypto Officer (CO) or admin user's current password. The secret string is expected to be in string format (not binary).<br><br>If you used the `cloudhsm.yml` template to create a CloudHSM cluster, then a secret should already exist in Secrets Manager. Ensure tht the secret contains the value of the current Crypto Officer (CO) or admin user's password.|None|No|
|`pCloudHsmCustCaCertSecretName`|Required|The name of a secret in Secrets Manager that contains the customer CA certificate used to issue the CloudHSM's cluster certificate. The secret string is expected to be in string format (not binary).<br><br>If you used the `cloudhsm.yml` template to create a CloudHSM cluster, then a secret should already exist in Secrets Manager.|None|No|
|`pClientInstanceId`|Required|The EC2 instance ID in which the `cloudhsm-cli` package has already been installed and configured.<br><br>If you used the `cloudhsm.yml` template to create a CloudHSM cluster, ensure that you've selected to have the `cloudhsm-cli` package installed upon creation of the stack. You can also request installation of the package during a stack update operation. See the [README](./README.md) for details.|None|No|

## Creating the stack

Once you've addressed the preparation steps, you're ready to create the stack.

### 1. Create the stack

Use the [`cloudhsm-key-store.yml`](cloudhsm-key-store.yml) template to create a new stack.

### 2. Monitor progress of stack creation

Typically, creation of the stack will take from ~10 to ~20 minutes depending on the number of HSMs to be created.

The general order in which cloud resources are created is as follows:

* IAM service roles for AWS StepFunctions and Lambda functions
* Lambda functions to support StepFunction state machines
* StepFunction state machines
* CloudFormation Custom resource Lambda function
* CloudHSM key store
  * The `kmsuser` is created in the cluster
  * The CloudHSM key store is created
  * The key store is connected to the CloudHSM cluster

### 3. Inspect the created resources

Once the stack has been created, you can tour the environment to review the cloud resources. For example:

Access the KMS console to view the CloudHSM key store
* Select `Custom key stores` -> `CloudHSM key stores`
* The state of the key store should be `Connected`
* The cluster ID should match the expected value

Since the key store is in a connected state, you cannot edit the key store.

## Troubleshooting stack creation

By default, when issues occur during stack creation, CloudFormation will attempt to rollback the changes by deleting the resources created up to the point of the failure. You can preserve the state of a failed stack creation attempt by creating the stack with the option to disable rollback on stack creation failure. If the resources have been rolled back and deleted, you won't have the opportunity to inspect the resources for the cause of the failure. 

In this situation, you should delete the stack and attempt to create a new stack with an option to preserve successfully provisioned resources. When creating a stack again, in the CloudFormation console, in "Stack failure options", select "Preserve successfully provisioned resources". 

### `rKmsCloudHsmKeyStore` creation failure

Since most of the operations supporting stack creation occur via the create cluster state machine in Step Functions, you should familiarize yourself with monitoring the execution of state machines. You can access the Step Functions console and select the `...-create-key-store` and `...-connect-key-store` state machines to isolate the step at which the failure occurred.

In the CloudWatch Logs console, you can review the output of the `...-create-key-store` and `...-connect-key-store` Lambda functions and other functions that support the state machines.

## Updating the stack

The CloudFormation template does not yet support making updates to the stack.

## Deleting the stack

Deletion of the stack generally reverses the process described earlier. When the CloudFormation custom resource is called with the `delete` action, a CloudHSM cluster delete state machine is executed to delete the HSMs and the cluster.

An entry in Secrets Manager containing the customer CA certificate associated with the creation of the cluster will be preserved so that the certificate can be reused in the event that you create a new cluster from a backup.

## Notifying of potential security issues

See [CONTRIBUTING](CONTRIBUTING.md#security-issue-notifications) for more information on notifying AWS/Amazon Security about potential security issues.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md) for more information.

## License

This library is licensed under the MIT-0 License. See the LICENSE file.