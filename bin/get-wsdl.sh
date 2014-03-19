#!/bin/bash

# Downloads WSDL and XSD Files

# check script call
if [ $# -ne 1 ];
then
  echo "USAGE: $0 zimbra.example.com"
  echo "  optional you can add the SOAP port"
  echo "  $0 zimbra.example.com 7071"
  exit 1
fi

SERVER="$1"
GIVENPORT="$2"
PORT=":${GIVENPORT:7071}"

BASEDIR=$(dirname $0)

CONFIGDIR="${BASEDIR}/../etc/wsdl"
mkdir -p ${CONFIGDIR}
cd ${CONFIGDIR}

echo "download WSDLs"
wget -nc https://${SERVER}${PORT}/service/wsdl/ZimbraAdminService.wsdl
wget -nc https://${SERVER}${PORT}/service/wsdl/ZimbraUserService.wsdl                  
wget -nc https://${SERVER}${PORT}/service/wsdl/ZimbraService.wsdl                   

echo "download XSDs"
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraAccount.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraAdminExt.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraAdmin.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraMail.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraRepl.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraSync.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbraVoice.xsd
wget -nc https://${SERVER}${PORT}/service/wsdl/zimbra.xsd

