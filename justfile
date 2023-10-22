CLUSTER_NAME_1 := "cilium-01"
CLUSTER_NAME_2 := "cilium-02"

CONTEXT_NAME_1 := "kind-cilium-01"
CONTEXT_NAME_2 := "kind-cilium-02"

cluster: (_cluster "cilium-01" "1" "false") (_cluster "cilium-02" "2" "true") _connect

_cluster name id copyCert:
	#!/bin/bash
	kind create cluster --config={{name}}.yaml --name {{name}}
	helm repo add cilium https://helm.cilium.io/ --force-update

	# Copy the CA into all further clusters
	if [ "{{copyCert}}" = "true" ]
	then
		kubectl --context={{CONTEXT_NAME_1}} get secret -n kube-system cilium-ca -o yaml | \
		kubectl --context kind-{{name}} create -f -
	fi

	helm install cilium cilium/cilium  \
	  --namespace kube-system          \
	  --set cluster.name={{name}}      \
	  --set cluster.id={{id}}          \
	  --set hubble.relay.enabled=true  \
	  --set hubble.ui.enabled=true     \
	  --set encryption.enabled=true    \
	  --set encryption.type=wireguard

	cilium status --wait

_connect:
	# Node port for local kind only use lb for real world
	cilium clustermesh enable --context {{CONTEXT_NAME_1}} --service-type NodePort
	cilium clustermesh enable --context {{CONTEXT_NAME_2}} --service-type NodePort

	cilium clustermesh status --context {{CONTEXT_NAME_1}} --wait
	cilium clustermesh status --context {{CONTEXT_NAME_2}} --wait

	cilium clustermesh connect --context {{CONTEXT_NAME_1}} --destination-context {{CONTEXT_NAME_2}}
	cilium clustermesh status --context {{CONTEXT_NAME_1}} --wait
	cilium clustermesh status --context {{CONTEXT_NAME_2}} --wait

	cilium connectivity test --context {{CONTEXT_NAME_1}} --multi-cluster {{CONTEXT_NAME_2}}

delete: 
	kind delete clusters --all

rebuild: delete cluster