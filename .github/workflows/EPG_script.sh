#!/bin/bash
# ==============================================================================
# Script: miEPG.sh
# Versión: 3.7
# Función: Combina múltiples XMLs, renombra canales, cambia logos,
#          ajusta hora y acumula EPG entre días usando epg_acumulado.xml.gz
# ==============================================================================

set -o pipefail

sed -i '/^ *$/d' epgs.txt
sed -i '/^ *$/d' canales.txt

rm -f EPG_temp* canales_epg*.txt

epg_count=0

echo "─── DESCARGANDO EPGs ───"

while IFS=, read -r epg; do
    ((epg_count++))
    extension="${epg##*.}"

    if [ "$extension" = "gz" ]; then
        echo " │ Descargando y descomprimiendo: $epg"
        wget -q -O EPG_temp00.xml.gz "$epg" || continue
        gzip -t EPG_temp00.xml.gz 2>/dev/null || continue
        gzip -d -f EPG_temp00.xml.gz
    else
        echo " │ Descargando: $epg"
        wget -q -O EPG_temp00.xml "$epg" || continue
    fi

    [ ! -s EPG_temp00.xml ] && continue

    listado="canales_epg${epg_count}.txt"
    echo "# Fuente: $epg" > "$listado"

    awk '
    /<channel / {
        match($0, /id="([^"]+)"/, a); id=a[1]; name=""; logo="";
    }
    /<display-name[^>]*>/ && name == "" {
        match($0, /<display-name[^>]*>([^<]+)<\/display-name>/, a);
        name=a[1];
    }
    /<icon src/ {
        match($0, /src="([^"]+)"/, a); logo=a[1];
    }
    /<\/channel>/ {
        print id "," name "," logo;
    }
    ' EPG_temp00.xml >> "$listado"

    cat EPG_temp00.xml >> EPG_temp.xml
    sed -i 's/></>\n</g' EPG_temp.xml

done < epgs.txt

echo "─── PROCESANDO CANALES ───"

mapfile -t canales < canales.txt

for linea in "${canales[@]}"; do
    IFS=',' read -r old new logo offset <<< "$linea"
    old="$(echo "$old" | xargs)"
    new="$(echo "$new" | xargs)"
    logo="$(echo "$logo" | xargs)"
    offset="$(echo "$offset" | xargs)"

    contar="$(grep -c "channel=\"$old\"" EPG_temp.xml)"

    [ "$contar" -eq 0 ] && continue

    logo_original=$(sed -n "/<channel id=\"$old\"/,/<\/channel>/p" EPG_temp.xml \
        | grep "<icon src" | head -1 | sed 's/^[[:space:]]*//')

    if [ -n "$logo" ]; then
        logo_final="    <icon src=\"$logo\" />"
    else
        logo_final="$logo_original"
    fi

    {
        echo "  <channel id=\"$new\">"

        if [ -f variables.txt ]; then
            sufijos=$(grep "display-name=" variables.txt | cut -d= -f2 | tr ',' '\n')
            for s in $sufijos; do
                s="$(echo "$s" | xargs)"
                [ -n "$s" ] && echo "    <display-name>$new $s</display-name>"
            done
        else
            echo "    <display-name>$new</display-name>"
        fi

        [ -n "$logo_final" ] && echo "$logo_final"
        echo "  </channel>"
    } >> EPG_temp1.xml

    sed -n "/<programme.*\"$old\"/,/<\/programme>/p" EPG_temp.xml > EPG_temp02.xml
    sed -i "s#channel=\"$old\"#channel=\"$new\"#g" EPG_temp02.xml

    if [[ "$offset" =~ ^[+-]?[0-9]+$ ]]; then
        export OFFSET="$offset"
        perl -MDate::Parse -MDate::Format -i'' -pe '
        BEGIN { $o = $ENV{OFFSET} * 3600 }
        if (/<programme start="(\d{14}) ([^"]+)" stop="(\d{14}) ([^"]+)"/) {
            $s = str2time("$1 $2") + $o;
            $e = str2time("$3 $4") + $o;
            $ns = time2str("%Y%m%d%H%M%S $2", $s);
            $ne = time2str("%Y%m%d%H%M%S $4", $e);
            s/start="[^"]+" stop="[^"]+"/start="$ns" stop="$ne"/;
        }' EPG_temp02.xml
    fi

    cat EPG_temp02.xml >> EPG_temp2.xml
done

echo "─── ACUMULANDO HISTÓRICO ───"

if [ -f epg_acumulado.xml.gz ]; then
    echo " Rescatando histórico..."
    zcat epg_acumulado.xml.gz \
    | sed -n '/<programme/,/<\/programme>/p' \
    >> EPG_temp2.xml
fi

dias_pasados=$(grep "dias-pasados=" variables.txt | cut -d= -f2 | xargs)
dias_futuros=$(grep "dias-futuros=" variables.txt | cut -d= -f2 | xargs)
dias_pasados=${dias_pasados:-0}
dias_futuros=${dias_futuros:-99}

c_old=$(date -d "$dias_pasados days ago 00:00" +"%Y%m%d%H%M%S")
c_new=$(date -d "$dias_futuros days 02:00" +"%Y%m%d%H%M%S")

perl -ne '
BEGIN { %v=(); }
if (/<programme start="(\d{14})[^"]+" channel="([^"]+)">/) {
    $k="$1-$2";
    next if $1 < "'$c_old'" || $1 > "'$c_new'";
    next if $v{$k}++;
}
print;
' EPG_temp2.xml > EPG_temp_final.xml

{
    echo '<?xml version="1.0" encoding="UTF-8"?>'
    echo '<tv generator-info-name="miEPG 3.7">'
    cat EPG_temp1.xml
    cat EPG_temp_final.xml
    echo '</tv>'
} > miEPG.xml

xmllint --noout miEPG.xml || exit 1

gzip -c miEPG.xml > epg_acumulado.xml.gz

rm -f EPG_temp*
echo "─── PROCESO FINALIZADO ───"

