#!/usr/bin/env bash
set -e

source variables.txt

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

echo '<?xml version="1.0" encoding="UTF-8"?><tv>' > miEPG.xml

while read -r URL; do
    [ -z "$URL" ] && continue
    wget -q "$URL" -O epg.xml.gz
    gunzip -f epg.xml.gz
    cat epg.xml >> merged.xml
done < "$GITHUB_WORKSPACE/epgs.txt"

while read -r C; do
    [ -z "$C" ] && continue
    xmlstarlet sel -t -c "//channel[@id='$C']" merged.xml >> miEPG.xml
    xmlstarlet sel -t -c "//programme[@channel='$C']" merged.xml >> miEPG.xml
done < "$GITHUB_WORKSPACE/canales.txt"

echo '</tv>' >> miEPG.xml

if [ "$dias_futuros" -gt 0 ]; then
    FUTURE_LIMIT=$(date -d "+$dias_futuros days" +"%Y%m%d%H%M%S")
    xmlstarlet ed -L -d "/tv/programme[@start > '$FUTURE_LIMIT']" miEPG.xml
fi

gzip -f miEPG.xml
cp miEPG.xml.gz "$GITHUB_WORKSPACE"






