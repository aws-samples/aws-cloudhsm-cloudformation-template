# CHANGELOG

## May 2023 - v2.1

* Enable stack update to delete all HSMs yet retain the cluster. Set the `pHsmsPerSubnet` to `0` during a stack update to delete all HSMs. This technique can reduce costs of operating non-production clusters.
* When deleting a stack, avoid waiting for the status of HSMs when no HSMs exist.

## May 2023 - v2.0

### Overall enhancements

Orchestration of all stack create, update, and delete processes has been consolidated in AWS Step Functions state machines. Formerly, orchestration was split between the EC2 client first boot scripts and state machines. Dependencies on EC2 first boot scripts have been minimized. First boot scripts are largely relegated to installing a few packages and creating a small number of helper scripts that are executed via the state machines. State machines now use AWS Systems Manager run documents to remotely execute scripts on the EC2 client.

Error handling and reporting has been improved across all stack actions.

### Stack creation enhancements

* Cluster certificate issuance enhancements:
  * Added option to use your own public key infrastructure (PKI) to issue a cluster certificate.
  * In support of built-in automated certificate issuance, migrated from using `openssl` commands in the EC2 first boot scripts to using AWS Certificate Manager Private CA resources from within the state machines.
* Separated the CloudHSM key store automation into its own CloudFormation template `cloudhsm-key-store.yml`.
* Added support for specifying the subnets in which to represent the CloudHSM HSM ENIs. 
  * Previously, the automation automatically selected subnets.
  * Its now up to the user to specify the appropriate subnets as stack parameters.
  * Added examples of how to determine the AZs in which CloudHSM is supported.
* Added the option to have either CloudHSM SDK 3 `cloudhsm-client` or CloudHSM SDK 5 `cloudhsm-cli` package installed and configured at the end of cluster creation.

### Stack update enhancements

* Added support for expanding and shrinking the number of HSMs in the cluster.
* Added support for replacing the CloudHSM SDK client or CLI package during update.

### Other enhancements

* Improved diagrams.
* Converted state machines from JSON to YAML for ease of reading and maintenance.
* Updated all Lambda functions use Python 3.10.
* Removed `vpc.yaml`. 

## October 2021 - v1.0

Original version.