#!/bin/bash

usage () {
echo -e "usage: $0 -a <app name> -n <namespace>
description:
    Creates a TLS cert for a k8s app. Signs the cert in k8s. Operates on current context in kubeconfig.
    Developed for deploying the k8s-mutate-registry app
options:
    -a [app name]          The name of the app
    -n [namespace]         Namespace the app will be deployed to
"
}


while getopts a:n: flag
do
  case $flag in
    a) APP=$OPTARG;;
    n) NAMESPACE=$OPTARG;;
    *) usage ; exit 1;;
  esac
done
shift $(( $OPTIND -1))

if [[ -z $APP ]]; then
  echo "App name not defined"
  usage
  exit 1
fi

if [[ -z $NAMESPACE ]]; then
  echo "No namespace defined"
  usage
  exit 1
fi

CSR_NAME="${APP}.${NAMESPACE}.svc"

echo "Creating ${APP}.key ..."
openssl genrsa -out ${APP}.key 2048

echo "Creating ${APP}.csr ..."
cat >csr.conf<<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${APP}
DNS.2 = ${APP}.${NAMESPACE}
DNS.3 = ${CSR_NAME}
DNS.4 = ${CSR_NAME}.cluster.local
EOF
openssl req -new -key ${APP}.key -subj "/CN=${CSR_NAME}" -out ${APP}.csr -config csr.conf

echo "Deleting existing csr, if any ..."
kubectl delete csr ${CSR_NAME} || :

echo "Creating kubernetes CSR object ..."
kubectl create -f - <<EOF
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: ${CSR_NAME}
spec:
  groups:
  - system:authenticated
  request: $(cat ${APP}.csr | base64 | tr -d '\n')
  usages:
  - digital signature
  - key encipherment
  - server auth
EOF

echo "Waiting for CSR to be availabe..."
kubectl wait csr/${CSR_NAME} --for=condition="available" --timeout=5s
echo "Signing CSR..."
kubectl certificate approve ${CSR_NAME}

SECONDS=0
while true; do
  echo "Waiting for serverCert to be present in kubernetes ..."
  serverCert=$(kubectl get csr ${CSR_NAME} -o jsonpath='{.status.certificate}')
  if [ $serverCert != "" ]; then
    break
  fi
  if [ $SECONDS -ge 60 ]; then
    echo "[!] timed out waiting for serverCert"
    exit 1
  fi
  sleep 2
done

echo $serverCert > ${APP}.cabundle
echo "creating ${APP}.pem cert file"
echo ${serverCert} | openssl base64 -d -A -out ${APP}.pem

echo "create tls secret ${APP}-tls in namespace ${NAMESPACE}"
kubectl delete secret ${APP}-tls -n $NAMESPACE  || :
kubectl create secret tls ${APP}-tls --cert=${APP}.pem --key=${APP}.key -n ${NAMESPACE}
