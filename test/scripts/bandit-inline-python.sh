#!/bin/bash
#
# Run static analysis against inline Python-based Lambda functions
#
# This script depends on the following tools:
#  * cfn_lambda_extractor: https://github.com/intuit/cfn_lambda_extractor
#  * bandit: https://pypi.org/project/bandit/  
#
# Command line arguments:
#  -e <EXTRACT_SRC_DIR> - Optional directory in which to place extracted Lambda function source code files
#  <TEMPLATE_FILE> - Path to CloudFormation template in YAML format

#set -x

usage(){
>&2 cat << EOF
Usage: $(basename $0) [ -e <EXTRACT_SRC_DIR> ] <TEMPLATE_FILE>
EOF
exit 1
}
 
while getopts "e:" opt; do
  case $opt in
    e)
      EXTRACT_SRC_DIR=${OPTARG}
      ;;
    *)
      usage
      ;;
  esac
done
shift $((OPTIND-1))

if [ ! -z ${@+x} ] ; then 
  TEMPLATE_FILE=${@}
else
  echo "Error: <TEMPLATE_FILE> argument is required"
  usage
fi

if [ -z ${EXTRACT_SRC_DIR+x} ] ; then 
  EXTRACT_SRC_DIR=$(mktemp -d)
else
  if [ ! -d ${EXTRACT_SRC_DIR} ] ; then
    mkdir -p ${EXTRACT_SRC_DIR}
  fi
fi

cfn_lambda_extractor -c $TEMPLATE_FILE -o $EXTRACT_SRC_DIR

bandit -r $EXTRACT_SRC_DIR