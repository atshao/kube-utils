#!/bin/bash -x
TOP_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

if [ $# -gt 2 -o "x$1" = "x" ]; then
    echo -e "USAGE: $(basename $0) USER_NAME [NAME_SPACE]"
    exit 1
fi


export ACCOUNT=$1
export NS_DEFAULT=default
export NS_WANTED=${2:-$NS_DEFAULT}

export PKI_DIR=${TOP_DIR}/pki
export CONFIG_DIR=${TOP_DIR}/config
export TEMPLATE_DIR=${TOP_DIR}/template
export NS_DIR=${CONFIG_DIR}/namespace/${NS_WANTED}
export ACCOUNT_DIR=${CONFIG_DIR}/account/${ACCOUNT}

export CA_CRT=${PKI_DIR}/ca.crt
export CA_KEY=${PKI_DIR}/ca.key


function assert_dir_existed() {
    [ -d "$1" ] || mkdir -p "$1"
}


#
# namespace
#
assert_dir_existed "${NS_DIR}"
(
    cd "${NS_DIR}"

    cat "${TEMPLATE_DIR}/namespace.yaml" | envsubst > namespace.yaml
    kubectl get namespace "${NS_WANTED}" &> /dev/null
    [ $? -ne 0 ] && kubectl create -f namespace.yaml
)


#
# account
#
assert_dir_existed "${ACCOUNT_DIR}"
(
    cd "${ACCOUNT_DIR}"

    openssl genrsa \
        -out ${ACCOUNT}.key 2048
    openssl req -new \
        -key ${ACCOUNT}.key \
        -out ${ACCOUNT}.csr \
        -subj "/CN=${ACCOUNT}"
    openssl x509 -req \
        -in ${ACCOUNT}.csr \
        -CA ${CA_CRT} \
        -CAkey ${CA_KEY} \
        -CAcreateserial \
        -out ${ACCOUNT}.crt \
        -days 365

    cat "${TEMPLATE_DIR}/role.yaml" | envsubst > role.yaml
    kubectl -n "${NS_WANTED}" get role admin &> /dev/null
    [ $? -ne 0 ] && kubectl create -f role.yaml

    cat "${TEMPLATE_DIR}/admin-binding.yaml" | envsubst > admin-binding.yaml
    kubectl -n "${NS_WANTED}" get rolebinding admin-binding &> /dev/null
    [ $? -ne 0 ] && kubectl create -f admin-binding.yaml
)


