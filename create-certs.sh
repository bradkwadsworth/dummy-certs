#!/bin/sh
set -e

CA_ROOT_KEY=$CERTSDIR/private/ca.key
CA_ROOT_CERT=$CERTSDIR/certs/ca.pem
CA_INTERMEDIATE_KEY=$CERTSDIR/private/intermediate.key
CA_INTERMEDIATE_CERT=$CERTSDIR/certs/intermediate.pem
KEY=$CERTSDIR/private/server.key
CERT=$CERTSDIR/certs/server.pem
CSR=$CERTSDIR/csr/server.csr

if [ ! $(ls -A $CERTSDIR 2>/dev/null) ]; then
  mkdir -p $CERTSDIR/crl \
    $CERTSDIR/csr \
    $CERTSDIR/newcerts \
    $CERTSDIR/CA \
    $CERTSDIR/intermediate \
    $CERTSDIR/private \
    $CERTSDIR/certs
  touch ${CERTSDIR}/CA/index.txt
  echo 1000 > $CERTSDIR/CA/serial
  touch $CERTSDIR/intermediate/index.txt
  echo 1000 > ${CERTSDIR}/intermediate/serial
  echo 1000 > ${CERTSDIR}/intermediate/crlnumber
fi

create_ca () {
  if [ ! -f "${CA_ROOT_KEY}" ]; then
    echo
    echo "----------------------------------------------------------------------"
    echo "Generating CA root key at ${CA_ROOT_KEY}."
    echo "----------------------------------------------------------------------"
    echo
    openssl genrsa -aes256 -out "${CA_ROOT_KEY}" 4096
  fi

  if [ ! -f "${CA_ROOT_CERT}" ]; then
    echo
    echo "----------------------------------------------------------------------"
    echo "Generating CA cert at ${CA_ROOT_CERT}."
    echo "----------------------------------------------------------------------"
    echo
    openssl req -config /etc/ssl/openssl.cnf \
      -key "${CA_ROOT_KEY}" \
      -new -x509 -days 7300 -sha256 -extensions v3_ca \
      -out "${CA_ROOT_CERT}"
  fi
}

create_intermediate () {
  if [ ! -f "${CA_INTERMEDIATE_KEY}" ]
  then
    echo
    echo "----------------------------------------------------------------------"
    echo "Generating CA intermediate key at ${CA_INTERMEDIATE_KEY}."
    echo "----------------------------------------------------------------------"
    echo
    openssl genrsa -aes256 \
      -out "${CA_INTERMEDIATE_KEY}" 4096
  fi

  if [ ! -f "${CA_INTERMEDIATE_CERT}" ]
  then
    echo
    echo "----------------------------------------------------------------------"
    echo "Generating CA intermediate csr."
    echo "----------------------------------------------------------------------"
    echo
    openssl req -config /etc/ssl/openssl.cnf -new -sha256 \
      -key "${CA_INTERMEDIATE_KEY}" \
      -out $CERTSDIR/intermediate.csr

    echo
    echo "-------------------------------------------------------------------------------"
    echo "Signing CA intermediate certificate with root CA at ${CA_INTERMEDIATE_CERT}."
    echo "-------------------------------------------------------------------------------"
    echo
    openssl ca -config /etc/ssl/openssl.cnf -extensions v3_intermediate_ca \
      -days 3650 -notext -md sha256 \
      -in $CERTSDIR/intermediate.csr \
      -out "${CA_INTERMEDIATE_CERT}"
  fi

}

echo
read -p "s - Self-Signed Certificate
c - Certificate signed by a Certificate Authority
i - Certifcate signed by an Intermediate Certificate

Enter the kind of certificate you would like to create:(s) " TYPE
TYPE=${TYPE:-s}

echo
echo "----------------------------------------------------------------------"
echo "Creating server key."
echo "----------------------------------------------------------------------"
echo
openssl genrsa \
  -out "${KEY}" 2048

echo
echo "----------------------------------------------------------------------"
echo "Creating certificate signing request."
echo "----------------------------------------------------------------------"
echo
openssl req -config /etc/ssl/openssl.cnf \
  -key "${KEY}" \
  -new -sha256 -out "${CSR}"

case "${TYPE}" in
  s)
    echo
    echo "----------------------------------------------------------------------"
    echo "Creating self-signed certificate."
    echo "----------------------------------------------------------------------"
    echo
    openssl x509 -req -days 365 -in "${CSR}" \
      -signkey "${KEY}" -out "${CERT}"
    ;;
  c)
    create_ca
    echo
    echo "----------------------------------------------------------------------"
    echo "Signing certificate signing request with CA certificate."
    echo "----------------------------------------------------------------------"
    echo
    openssl ca -config /etc/ssl/openssl.cnf \
      -extensions server_cert -days 375 -notext -md sha256 \
      -in  "${CSR}" \
      -out "${CERT}"

    echo
    echo "----------------------------------------------------------------------"
    echo "Here is your CA key at ${CA_ROOT_KEY}."
    echo "----------------------------------------------------------------------"
    echo
    cat "${CA_ROOT_KEY}"

    echo
    echo "----------------------------------------------------------------------"
    echo "Here is your CA certificate at ${CA_ROOT_CERT}."
    echo "----------------------------------------------------------------------"
    echo
    echo "----------------------------------------------------------------------"
    cat "${CA_ROOT_CERT}"
    echo "----------------------------------------------------------------------"
    ;;
  i)
    create_ca
    create_intermediate
    echo
    echo "----------------------------------------------------------------------"
    echo "Signing certificate signing request with intermediate certificate."
    echo "----------------------------------------------------------------------"
    echo
    openssl ca -config /etc/ssl/openssl.cnf -name CA_intermediate_dummy \
      -extensions server_cert -days 375 -notext -md sha256 \
      -in "${CSR}" \
      -out "${CERT}"

   echo
   echo "----------------------------------------------------------------------"
   echo "Here is your CA key at ${CA_ROOT_KEY}."
   echo "----------------------------------------------------------------------"
   echo
   echo "----------------------------------------------------------------------"
   cat "${CA_ROOT_KEY}"
   echo "----------------------------------------------------------------------"

   echo
   echo "----------------------------------------------------------------------"
   echo "Here is your CA certificate at ${CA_ROOT_CERT}."
   echo "----------------------------------------------------------------------"
   echo
   echo "----------------------------------------------------------------------"
   cat "${CA_ROOT_CERT}"
   echo "----------------------------------------------------------------------"

   echo
   echo "----------------------------------------------------------------------"
   echo "Here is your intermediate key at ${CA_INTERMEDIATE_KEY}."
   echo "----------------------------------------------------------------------"
   echo
   echo "----------------------------------------------------------------------"
   cat "${CA_INTERMEDIATE_KEY}"
   echo "----------------------------------------------------------------------"

   echo
   echo "----------------------------------------------------------------------"
   echo "Here is your intermediate certificate at ${CA_INTERMEDIATE_CERT}."
   echo "----------------------------------------------------------------------"
   echo
   echo "----------------------------------------------------------------------"
   cat "${CA_INTERMEDIATE_CERT}"
   echo "----------------------------------------------------------------------"
   ;;
   *)
      echo
      echo "Must choose s, c or i"
      exit 1
     ;;
 esac

echo
echo "----------------------------------------------------------------------"
echo "Here is your server key."
echo "----------------------------------------------------------------------"
echo
echo "----------------------------------------------------------------------"
cat "${KEY}"
echo "----------------------------------------------------------------------"

echo
echo "----------------------------------------------------------------------"
echo "Here is your server certificate."
echo "----------------------------------------------------------------------"
echo
echo "----------------------------------------------------------------------"
cat "${CERT}"
echo "----------------------------------------------------------------------"

find $CERTSDIR -type d -exec chmod 777 {} \;
find $CERTSDIR -type f -exec chmod 666 {} \;
