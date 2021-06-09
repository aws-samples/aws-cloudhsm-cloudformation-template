# Automated Deployment of AWS CloudHSM Resources

This AWS CloudFormation template automatically deploys an [AWS CloudHSM](https://docs.aws.amazon.com/cloudhsm/latest/userguide/introduction.html) cluster with HSMs and supporting AWS resources. Optionally, the template creates an [AWS KMS custom key store](https://docs.aws.amazon.com/kms/latest/developerguide/custom-key-store-overview.html) and connects it to the CloudHSM cluster.

* [Overview](#overview)
* [Usage](#usage)
* [Known Issues](#known-issues)
* [Troubleshooting Stack Creation](#troubleshooting-stack-creation)
* [Performing Post Stack Creation Steps](#performing-post-stack-creation-steps)
* [Monitoring and Managing the Resources](#monitoring-and-managing-the-resources)

## Overview

The [`cloudhsm.yaml`](cloudhsm.yaml) CloudFormation template creates a CloudHSM cluster with HSMs and optionally creates a KMS custom key store and connects it to the cluster. 

<img src="images/cloudhsm-cluster.png" alt="CloudHSM Cluster" width="600"/>

In addition to a CloudHSM cluster and HSM resources, the following resources are created in support of the cluster:

* A CloudFormation custom resource AWS Lambda function that is used to create and delete CloudHSM clusters
* AWS Step Functions state machines to orchestrate creation and deletion of CloudHSM clusters
* Lambda functions to support the state machines
* An EC2 client configured to manage the cluster of HSMs
* An initial crypto officer `admin` user password that is stored as a secret in AWS Secrets Manager
* A CloudHSM trust anchor certificate

Deletion of the the CloudFormation stack results in the removal of these resources.

## Usage

### Preparing to create a CloudHSM cluster

You should address the following considerations before using the CloudFormation template.

#### 1. Review AWS CloudHSM and KMS Custom Key Store documentation

* Ensure that you're familiar with the basic architecture and operation of [AWS CloudHSM Clusters](https://docs.aws.amazon.com/cloudhsm/latest/userguide/clusters.html)
* If you intend to use KMS custom key stores, [Using a custom key store](https://docs.aws.amazon.com/kms/latest/developerguide/custom-key-store-overview.html)

#### 2. Determine the system identifier to qualify cloud resource names

If you plan to create a single CloudHSM cluster in an AWS account, you can use the default setting for the [`pSystem`](#cloudformation-template-parameters) CloudFormation template parameter.

If you plan to use this template top create multiple CloudHSM clusters in the same AWS account, then you should set the [`pSystem`](#cloudformation-template-parameters) CloudFormation template parameter to value that will be used to distinguish the resource names associated with each cluster. For example, when testing this template, you may want to create multiple clusters and supporting cloud resources.

If you intend to test creation of multiple CloudHSM clusters in a single AWS account, review [AWS CloudHSM Quotas](https://docs.aws.amazon.com/cloudhsm/latest/userguide/limits.html).

#### 3. Determine the number of HSMs to create

If you intend to create a KMS custom key store, you'll need to specify at least two HSMs via the [`pNumHsms`](#cloudformation-template-parameters) CloudFormation template parameter.

Typically, you will want to create at least two HSMs for each CloudHSM cluster. However, in support of some testing scenarios, you might want to reduce the time required to create the stack by specifying a single HSM.

#### 4. Ensure a suitable VPC and subnets are available

Determine an existing VPC with which you want the HSMs and KMS custom key store associated.  You can optionally use the  [`vpc.yaml`](vpc.yaml) CloudFormation template to automatically create a VPC that is suitable for use with CloudHSM.

Currently, the automation used by the CloudFormation template automatically identifies the compatible Availability Zones (AZs) in the AWS Region and will automatically associate each HSM with a distinct AZ and subnet.

#### 5. Determine the subnet in which to deploy the EC2 client instance

You'll need to determine the VPC and subnet in which an EC2 client instance that interacts with the HSMs in the cluster. Typically, the subnet will be in the same VPC as the HSMs ENIs.

#### 6. Determine whether or not you want to create a KMS custom key store

By default, the template creates a KMS custom key store and connects it to the CloudHSM cluster. If you don't plan on using KMS with your CloudHSM cluster, you can override the [`pStackScope`](#cloudformation-template-parameters) CloudFormation template parameter to specify that only the CloudHSM cluster be created.

### Creating the CloudFormation stack

Once you've addressed the preparation steps, you're ready to create the stack.

#### 1. Create the stack

Use the [`cloudhsm.yaml`](cloudhsm.yaml) CloudFormation template to create a new stack.

##### CloudFormation Template Parameters

|Parameter|Required|Description|Default|
|---------|--------|-----------|-------|
|`pStackScope`|Optional|Scope of the stack to create:<br>`with-custom-key-store`: CloudHSM cluster + EC2 client instance + KMS custom key store<br>`cluster-and-client-only`: CloudHSM cluster + EC2 client instance|`with-custom-key-store`|
|`pVpcId`|Optional|The VPC in which the HSM Elastic Network Interfaces (ENIs) will be provisioned and in which the EC2 client instance will be deployed.|None|
|`pNumHsms`|Optional|Number of HSMs to create in the CloudHSM cluster: `1`, `2`, or `3`|`2`|
|`pClientInstanceSubnet`|Required|The subnet in which the EC2 client will be deployed.|None|
|`pClientInstanceType`|Optional|Instance type to use for the EC2 client|`t3a.small`|
|`pClientInstanceAmiId`|Optional|EC2 image ID to use for the EC2 client.|`/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-ebs`|
|`pSystem`|Optional|Used to qualify cloud resource names. Override if you expect to have multiple instances of the stack in the same AWS account.|`cloudhsm`|

#### 2. Monitor progress of stack creation

Typically, creation of the stack will take from ~10 to ~50 minutes depending on the number of HSMs to be created and whether or not a KMS custom key store is created and connected to the cluster.

The general order in which cloud resources are created is as follows:
* IAM service roles for AWS StepFunctions and Lambda
* Lambda functions to support StepFunction state machines
* StepFunction state machines
* CloudFormation Custom resource Lambda function
* CloudHSM cluster and the first HSM
  * The CloudFormation custom resource is called with the `create` action
  * This action triggers execution of the CloudHSM cluster create state machine in Step Functions
  * That state machine creates the CloudHSM cluster and the first HSM before signaling to CloudFormation that the `create` action is complete
* CloudHSM cluster Crypto Officer (CO) `admin` user password is generated and stored in Secrets Manager
* IAM service role and EC2 instance profile for the EC2 client instance
* EC2 client instance
  * An EC2 UserData script is used in conjunction with [`AWS::CloudFormation::Init`](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-init.html) to bootstrap the CloudHSM client instance
    * CloudWatch agent is configured
    * Package dependencies are installed
    * CloudHSM cluster certificate is generated
    * CloudHSM cluster is initialized
    * CloudHSM client service is started
    * CloudHSM cluster CO password is set and cluster is activated
    * HSMs are added as necessary
    * Optionally, `kmsuser` is added to the cluster and KMS custom key store is created and connected to the cluster

Deletion of the stack generally reverses this process. When the CloudFormation custom resource is called with the `delete` action, a CloudHSM cluster delete state machine is executed to delete the HSMs and the cluster.

##### Monitoring Step Functions state machines

During creation of the stack, you can open the AWS Step Functions console and select the cluster creation state machine to monitor progress of the creation of the cluster and the first HSM.

Since the processes required to create and delete clusters and HSMs may take longer than the maximum Lambda function execution time of 15 minutes, a pair of AWS Step Functions state machines are used to orchestrate these long running workflows.

**CloudHSM cluster create state machine**

<img src="images/state-machine-create-cluster.png" alt="Step Functions create state machine" width="200"/>

**CloudHSM cluster delete state machine**

<img src="images/state-machine-delete-cluster.png" alt="Step Functions delete state machine" width="200"/>

##### Monitoring EC2 client instance configuration

After the CloudHSM cluster and initial HSM are created via the Step Function state machine, the other long duration task is the configuration of the EC2 client instance.

Upon either successful execution of the first boot automation or an error, a notification will be sent to CloudFormation indicating the result of configuring the EC2 client instance. This notification will enable CloudFormation to complete configuration of the EC2 client instance resource.

You have several options for monitoring the progress of EC2 client instance configuration:

**CloudWatch Logs**

Access the CloudWatch console and select the `cloudhsm` log group. The name of the log group is based on the value of the `pSystem` CloudFormation template parameter.

In the proper log group, select the `cfn-init.log` log stream to monitor the progress of the first boot automation.  Review the content of the [`AWS::CloudFormation::Init`](cloudhsm.yaml) section in the CloudFormation template for the sequence of scripts that are executed.

**AWS Systems Manager Session Manager**

You can also connect directly to the EC2 client instance via AWS Systems Manager Session Manager to access a terminal session.

1. Access the EC2 service of the AWS Management Console
1. Choose the EC2 client instance
1. Choose "Connect" in the upper portion of the console
1. Choose the "Session Manager" option
1. Choose "Connect"

Once you're in the terminal session:

1. `$ cd /var/logs`
2. `$ tail -f cfn-init.log`

When you're in the terminal session, you can also review the content of the working directory used by the automation scripts. See the directory `/root/cloudhsm-work/` for the working content.

#### 3. Inspect the created resources

Once the stack has been created, you can tour the environment to review the cloud resources. For example:

##### Inspect CloudHSM cluster

Access the CloudHSM console to view the CloudHSM cluster and HSMs.
* The state of the cluster and the associated HSM(s) should be `Active`
* Note the ENI IP address(es), AZs, and subnets in use
* Selecting `Backups` will show several backups already created due to the fact that changes were made to the cluster during initial provisioning

##### Inspect KMS custom key store (optional)

If you specified creation of a KMS custom key store, access the KMS console to view the custom key store. 

The key store should have a status of `CONNECTED` and the number of HSMs should equal the number of HSMs created in your cluster

##### Inspect Elastic Network Interfaces (ENIs)

Access the EC2 console and select Network Interfaces to inspect the ENIs that were created. Review the Description field.
* A CloudHSM managed ENI should be present for each HSM
* If you specified creation of a KMS custom key store, a KMS managed ENI should be present for each HSM

##### Inspect initial Crypto Office (CO) `admin` user's password

Access the Secrets Manager console to review the initial Crypto Officer`admin` user's secret and associated password value.

##### Inspect CloudHSM via the CloudHSM Management Utility

The EC2 client instance has been configured with the [CloudHSM Management Utility (CMU)](https://docs.aws.amazon.com/cloudhsm/latest/userguide/cloudhsm_mgmt_util.html) to support ongoing inspection and configuration of your cluster.  You can use the `cloudhsm_mgmt_util` CLI to execute the CMU.

Use AWS Systems Manager Session Manager to access a terminal session to the EC2 client instance. See [Monitoring EC2 client instance configuration](#monitoring-ec2-client-instance-configuration) for details.

Once you're in the terminal session:

1. Execute `$ /opt/cloudhsm/bin/cloudhsm_mgmt_util /opt/cloudhsm/etc/cloudhsm_mgmt_util.cfg`
  * For each HSM, you should see a connection being established.
2. A subset of the [CMU commands](https://docs.aws.amazon.com/cloudhsm/latest/userguide/cloudhsm_mgmt_util-reference.html) can be executed before logging in. For example:
  * `getHSMInfo` - Lists details of each HSM
  * `listUsers` - Lists users defined on each HSM. The set of users should be identical across HSMs.
  * `info server 0` - List details of each HSM. Replace `0` with the index of the HSM of interest.

## Known Issues and Limitations

### Deletion of stack may fail due to dependency violation with the EC2 client instance security group

When stack deletion fails on the `rClientInstanceSecurityGroup`, you can attempt to delete the stack a second time, but opt to leave the security group intact. After the stack has been deleted, you can address the dependency and then manually delete the security group.

1. Access "Security Groups" in the EC2 Console.
2. Look for the security group associated with the CloudHSM cluster.
3. Edit the inbound rules and delete the reference to the EC2 client instance security group.
4. Delete both the EC2 client instance security group.

### Deletion of stack doesn't delete the KMS custom key store

Since the KMS custom key store is created via the AWS CLI during first boot of the EC2 client instance, this resource is not managed via CloudFormation and not automatically deleted during deletion of the stack.

You can manually delete the custom key store via the KMS console or AWS CLI.  

1. Disconnect the key store from the CloudHSM cluster. The associated ENIs used to enable the custom key store to connect to the HSMs will be automatically deleted.
2. After the key store is disconnected, you can delete the key store.

### Deletion of stack doesn't delete the security group associated with the CloudHSM cluster

After you've manually disconnected the KMS custom key store, you can manually delete the security group associated with the CloudHSM cluster.

While the custom key store is in a connected state, there will be an ENI for each of the former HSMs and the cluster security group will be associated with those ENIs. Until you disconnect the key store, the ENIs will continue to exist and be a dependency on the cluster security group.

## Troubleshooting Stack Creation

If you notice that stack creation fails on creation of the `rClientInstance` EC2 client instance resource, you should inspect the content of the `cfn-init.log` log file produced by the EC2 client instance. 

By default, when issues occur stack creation, CloudFormation will attempt to rollback the changes by deleting the resources created up to the point of the failure. Consequently, the EC2 client instance and its CloudWatch log group and log streams will be automatically deleted.

You can preserve the state of a failed stack creation attempt by creating the stack with the option to disable rollback on stack creation failure. In CloudFormation console when creating a new stack, see "Configure stack options" -> "Advanced options" -> "Stack creation options".  Select "Disabled" for "Rollback on failure".

Once you attempt to create the stack again, the same failure may occur, but you should be able to inspect the content of the `cfn-init.log` log file. See [Monitoring EC2 client instance configuration](#monitoring-ec2-client-instance-configuration) for details on how to inspect this log data. 

After you've reviewed the cause of the error, you can proceed with deleting the stack, correcting the issue, and attempting to create the stack again.

## Performing Post Stack Creation Steps

### Changing the crypto officer password

As a security best practice, you should change the Crypto Officer (CO) password immediately after the stack is created. 

You will use the [CloudHSM Management Utility](https://docs.aws.amazon.com/cloudhsm/latest/userguide/cloudhsm_mgmt_util.html) from within the EC2 client instance to change the password.

1. Obtain the initial crypto office (CO) password from Secrets Manager
2. Start the CMU CLI. See [Inspect CloudHSM via the CloudHSM Management Utility](#inspect-cloudhsm-via-the-cloudhsm-management-utility) for details on executing the CMU
3. At the `aws-cloudhsm>` prompt, log in via the CO `admin` user:  `loginHSM CO admin -hpswd`
4. Enter the initial password for the CO user that you obtained from Secrets Manager
5. You should see a successful login for each HSH
6. Change the password `changePswd CO admin -hpswd`
7. Specify the password
8. Enter `quit` to quit the CMU

At this stage, you can optionally delete the secret from Secrets Manager given that the initial password is no longer in use.

Note that if you requested creation of a KMS custom key store, KMS has already changed the initial password for the `kmsuser` across the HSMs.

## Monitoring and Managing the Resources

### Monitoring and Managing the CloudHSM cluster

See the following resources for information on monitoring and managing your CloudHSM cluster:

* [Monitoring AWS CloudHSM](https://docs.aws.amazon.com/cloudhsm/latest/userguide/get-logs.html)
* [Managing Backups](https://docs.aws.amazon.com/cloudhsm/latest/userguide/manage-backups.html)

### Managing the EC2 client instance

Although the EC2 client does not need to be running in order for KMS custom key stores to operated against your CloudHSM cluster, you will want to ensure that your EC2 client instance is kept up-to-date with necessary OS patches.

You should also monitor the availability of new releases of the CloudHSM Management Utility (CMU) and consider updating it over time. See [Install and Configure the AWS CloudHSM Client (Linux)](https://docs.aws.amazon.com/cloudhsm/latest/userguide/install-and-configure-client-linux.html).

Given the configuration of the EC2 client instance, you should use your standard practices to backup the EC2 instance so that you can restore it in the future in case the EC2 instance is inadvertently deleted or becomes unavailable.