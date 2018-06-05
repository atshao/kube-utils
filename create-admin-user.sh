#!/bin/bash
set -o errexit
TOP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

if [ $# -gt 2 -o "x$1" = "x" ]; then
    echo -e "USAGE: $(basename $0) USER_NAME [NAME_SPACE]"
    exit 1
fi


ACCOUNT=$1
NS_DEFAULT=default
NS_WANTED=${2:-$NS_DEFAULT}
NS_DIR=${TOP_DIR}/ns-${NS_WANTED}
NS_YAML=${NS_DIR}/namespace.yaml
ACCOUNT_DIR=${NS_DIR}/user-${ACCOUNT}
ACCOUNT_YAML=${ACCOUNT_DIR}/role.yaml
BINDING_YAML=${ACCOUNT_DIR}/rolebinding.yaml

CA_CRT=${TOP_DIR}/cluster/ca.crt
CA_KEY=${TOP_DIR}/cluster/ca.key

TEMPLATE_NAMESPACE="\
apiVersion: v1
kind: Namespace
metadata:
  name: ${NS_WANTED}
"

TEMPLATE_ROLE="\
kind: Role
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin
  namespace: ${NS_WANTED}
rules:
- apiGroups: ['*']
  resources: ['*']
  verbs: ['*']
"

TEMPLATE_BINDING="\
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1beta1
metadata:
  name: admin-binding
  namespace: ${NS_WANTED}
subjects:
- kind: User
  name: ${ACCOUNT}
  namespace: ${NS_WANTED}
roleRef:
  kind: Role
  name: admin
  apiGroup: rbac.authorization.k8s.io
"


function namespace_existed() {
    kubectl get namespace ${NS_WANTED} &> /dev/null
    return $?
}

function assert_dir_existed() {
    [ -d "$1" ] || mkdir -p "$1"
}

function yaml_from_template() {
    [ -f "$1" ] || echo "$2" > "$1"
}

function create_account_credentials() {
    openssl genrsa \
        -out ${ACCOUNT_DIR}/${1}.key 2048
    openssl req -new \
        -key ${ACCOUNT_DIR}/${1}.key \
        -out ${ACCOUNT_DIR}/${1}.csr \
        -subj "/CN=${1}"
    openssl x509 -req \
        -in ${ACCOUNT_DIR}/${1}.csr \
        -CA ${CA_CRT} \
        -CAkey ${CA_KEY} \
        -CAcreateserial \
        -out ${ACCOUNT_DIR}/${1}.crt \
        -days 365
}


assert_dir_existed "${NS_DIR}"
yaml_from_template "${NS_YAML}" "${TEMPLATE_NAMESPACE}"
[ $(namespace_existed) ] || kubectl create -f ${NS_YAML}

assert_dir_existed "${ACCOUNT_DIR}"
create_account_credentials "${ACCOUNT}"
yaml_from_template "${ACCOUNT_YAML}" "${TEMPLATE_ROLE}"
kubectl create -f "${ACCOUNT_YAML}"

yaml_from_template "${BINDING_YAML}" "${TEMPLATE_BINDING}"
kubectl create -f "${BINDING_YAML}"

