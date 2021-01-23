package main

import (
	b64 "encoding/base64"
	"encoding/json"
	"fmt"
	"log"
	"strings"

	"k8s.io/api/admission/v1beta1"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

type Mutator struct {}

func (m Mutator) mutate(r v1beta1.AdmissionReview) (v1beta1.AdmissionResponse, error) {
	patchType := v1beta1.PatchTypeJSONPatch
	response := v1beta1.AdmissionResponse{
		Allowed:   true,
		UID:       r.Request.UID,
		PatchType: &patchType,
		AuditAnnotations: map[string]string{
			"k8s-mutate-scram-256": "Cluster-config.json mutated by MutatingAdmissionWebhook scram-256-webhook",
		},
	}

	if r.Request == nil {
		return response, nil
	}

	var secret corev1.Secret
	err := json.Unmarshal(r.Request.Object.Raw, &secret)
	if err != nil {
		log.Println("Unable to unmarshall secret json. received json below: ")
		log.Println(r.Request.Object.Raw)
		return response, fmt.Errorf("Unable to unmarshall secret json: %v", err.Error())
	}
	log.Printf("Processing secret: %v\n", secret.ObjectMeta.Name)

	patches := []map[string]string{}
	data, found := secret.Data["cluster-config.json"]
	if found {
		newBase64, mutated := m.mutateSecret(bytesToString(data))
		if mutated {
			log.Printf("Mutated secret")
			patch := map[string]string{
				"op":    "replace",
				"path":  "/data/cluster-config.json",
				"value": newBase64,
			}
			patches = append(patches, patch)
		}
	}

	response.Patch, _ = json.Marshal(patches)
	response.Result = &metav1.Status{
		Status: "Success",
	}

	return response, nil
}

func (m Mutator) mutateSecret(mongoConfigJson string) (string, bool) {
	mutated := false
	// log.Printf("Processing mongoConfigJson: %v\n", mongoConfigJson)

	oldArray := "[\"SCRAM-SHA-256\"]"
	newArray := "[\"SCRAM-SHA-256\",\"SCRAM-SHA-1\"]"
	newMongoConfigJson := strings.ReplaceAll(mongoConfigJson, oldArray, newArray)
	if mongoConfigJson != newMongoConfigJson {
		mutated = true
		// log.Printf("Changed the mongoConfigJson: %v\n", newMongoConfigJson)
	}

	newBase64 := b64.StdEncoding.EncodeToString([]byte(newMongoConfigJson))
	// log.Printf("New base64: %v\n", newBase64)

	return newBase64, mutated
}

func bytesToString(data []byte) string {
	return string(data[:])
}
