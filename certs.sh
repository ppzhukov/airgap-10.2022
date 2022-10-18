#!/bin/sh

#set -e

if [ "${DEBUG}" = 1 ]; then
    set -x
fi

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--registry_fqdn)
        registry_fqdn="$2"
        shift # past argument
        shift # past value
        ;;
        -t|--registry_ip)
        registry_ip="$2"
        shift # past argument
        shift # past value
        ;;
        -h|--help)
        help="true"
        shift
        ;;
        *)
        echo "Error! invalid flag: ${key}"
        help="true"

        break
        ;;
    esac
done

usage () {
    echo "USAGE: $0 --registry_fqdn 192.168.0.10.sslip.io --registry_ip 192.168.0.10"
    echo " Create directory and copy $0 in it"
    echo " Generate CA and certificate for Rancher Server and registry node"
    echo " [-h|--help] Usage message"
}

if [[ $help ]]; then
    usage
    exit 0
fi

if [[ -z registry_fqdn ]]; then
    echo "Registry FQDN must be set"
    usage
    exit 0
fi

cat > ca.cfg <<EOF
organization = "Demo Zone"
unit = "Demo Zone IT"
country = RU
cn = "SUSE stends CA"
serial = 013
expiration_days = 3650
email = "noreply@example.com"
ca
path_len = -1
EOF

certtool --generate-privkey --sec-param High --outfile cakey.pem     
certtool --generate-self-signed --load-privkey cakey.pem --outfile cacert.pem --template ca.cfg

openssl x509 -inform PEM -in cacert.pem -out ca.crt
cp cacert.pem cacerts.pem

cp cacert.pem /etc/pki/trust/anchors/rancher-stend.pem
update-ca-certificates
c_rehash

if [[ -n registry_fqdn ]]; then

cat > registry-cert.cfg <<EOF
organization = "Demo Zone"
unit = "Demo Zone IT"
country = RU
cn = "Registry Server"
serial = 013
expiration_days = 365
email = "noreply@example.com"
dns_name = "${registry_fqdn}"
signing_key
encryption_key
tls_www_server
EOF

    if [[ -n registry_ip ]]; then

cat >> registry-cert.cfg <<EOF
ip_address = "${registry_ip}"
EOF

    fi

    certtool --generate-privkey --sec-param High --outfile registry.key.pem
    certtool --generate-request --load-privkey registry.key.pem --outfile registry.csr.pem --template registry-cert.cfg
    certtool --generate-certificate --load-request registry.csr.pem --load-ca-certificate cacert.pem --load-ca-privkey cakey.pem --outfile registry.cert.pem --template registry-cert.cfg

    cp registry.key.pem ${registry_fqdn}.key
    openssl x509 -inform PEM -in registry.cert.pem -out ${registry_fqdn}.cert

    certtool --verify --load-ca-certificate cacert.pem --infile registry.cert.pem

fi
