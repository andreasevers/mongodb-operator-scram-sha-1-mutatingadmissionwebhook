#!/bin/bash

DEFAULT_IMAGE="vchrisr/k8smutateregistry:latest"

usage () {
echo -e "usage: $0 -i <docker image> -n <namespace> -a <app name>
description:
    Deploys the scram-256-webhook app and webhook configuration

options:
    -i [image]             The docker image to use (defaults to: $DEFAULT_IMAGE)
    -n [namespace]         Namespace the mutator will be deployed to
    -a [app name]          Mutator name to use
"
}

while getopts i:n:a:c: flag
do
  case $flag in
    i) IMAGE=$OPTARG;;
    n) NAMESPACE=$OPTARG;;
    a) APP=$OPTARG;;
    *) usage ; exit 1;;
  esac
done
shift $(( $OPTIND -1))

if [[ -z $IMAGE ]]; then
  echo "Image not defined. Using default: ${DEFAULT_IMAGE}"
  IMAGE=$DEFAULT_IMAGE
fi

if [[ -z $NAMESPACE ]]; then
  echo "No namespace defined"
  usage
  exit 1
fi

FULLPATH=$(dirname  "$0")

echo "Creating TLS cert... "
$FULLPATH/ssl.sh -a $APP -n $NAMESPACE

echo "Parsing template..."
export CA_BUNDLE=$(cat ${APP}.cabundle)
sed -i "s;\$IMAGE;${IMAGE};g" k8s-scram-256-webhook.yml
sed -i "s;\$CA_BUNDLE;${CA_BUNDLE};g" k8s-scram-256-webhook.yml
sed -i "s;\$NAMESPACE;${NAMESPACE};g" k8s-scram-256-webhook.yml
sed -i "s;\$APP;${APP};g" k8s-scram-256-webhook.yml

echo "Applying yaml..."
kubectl delete deployment $APP -n $NAMESPACE
kubectl apply -f k8s-scram-256-webhook.yml
