#!/bin/bash
set -o errexit


ACCOUNT="${1:-dashboard-admin}"

if ! kubectl get serviceaccount ${ACCOUNT} -n kube-system &> /dev/null; then
    kubectl create serviceaccount ${ACCOUNT} -n kube-system
    kubectl create clusterrolebinding ${ACCOUNT} \
        --clusterrole=cluster-admin \
        --serviceaccount=kube-system:${ACCOUNT}
fi

kubectl describe secret -n kube-system \
    $(kubectl get secrets -n kube-system | grep ${ACCOUNT} | cut -d ' ' -f 1) | grep -E '^token'

