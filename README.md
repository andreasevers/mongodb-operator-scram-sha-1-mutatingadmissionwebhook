## MongoDB Operator SCRAM-SHA-1 MutatingAdmissionWebhook
A Kubernetes Mutating Admission Webhook, using Go.  
This is a solution to the lack of `SCRAM-SHA-1` support in [MongoDB's Community Operator](https://github.com/mongodb/mongodb-kubernetes-operator).  
The operator writes the authentication method options to the `mongodb-config` Secret, which this webhook changes.  
Related issue on the Operator GitHub: https://github.com/mongodb/mongodb-kubernetes-operator/issues/217

This is proof of concept code, make sure to review carefully before using in a production system.  
Reused some code from https://github.com/orangeglasses/k8s-mutate-registry

#### Run tests
Sadly we don't have tests for now :(
```bash
$ go test ./...
```

#### Build
```bash
$ go build .
$ docker build .
```

#### Deploy
Define shell env:
```bash
$ export CONTAINER_REPO=<CONTAINER_REPO>
$ export NAMESPACE=mongodb
```

Deploy to K8s cluster
```bash
$ cd deploy
$ ./deploy.sh -a scram-256-webhook -n mongodb -i <CONTAINER_IMAGE>
```

#### Test example
```bash
$ kubectl create secret generic testsecret --from-literal cluster-config.json="[\"SCRAM-SHA-256\"]"
$ kubectl get secret testsecret -o "jsonpath={.data['cluster-config\.json']}" | base64 -D | jq
# The output should be:
[
  "SCRAM-SHA-256",
  "SCRAM-SHA-1"
]
```
You can now validate the mongodb-config secret as well:
```bash
$ kubectl get secret mongodb-config -o "jsonpath={.data['cluster-config\.json']}" | base64 -D | jq
```

We successfully mutated our secret spec and added `SCRAM-SHA-1` in there, yay !
