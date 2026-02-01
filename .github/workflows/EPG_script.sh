#!/bin/bash

set -e

###############################################
# CARGAR VARIABLES
###############################################

source variables.txt

###############################################
# GENERAR EPG DEL DÍA (TAL CUAL ESTÁ)
###############################################

WORKDIR=$(mktemp -d)
cd "$WORKDIR"

echo '<?xml version="1.0" encoding="UTF-8"?><tv>' > miEPG.xml

# Descargar y fusionar todas las EPGs
while read -r URL; do
    [ -z "$URL" ] && continue
    wget -q "$URL" -O epg.xml.gz
    gunzip -f epg.xml.gz
    cat epg.xml >> merged.xml
done < "$GITHUB_WORKSPACE/epgs.txt"

# Filtrar canales
while read -r C; do
    [ -z "$C" ] && continue
    xmlstarlet sel -t -c "//channel[@id='$C']" merged.xml >> miEPG.xml
    xmlstarlet sel -t -c "//programme[@channel='$C']" merged.xml >> miEPG.xml
done < "$GITHUB_WORKSPACE/canales.txt"

echo '</tv>' >> miEPG.xml

# Limitar días futuros
if [ "$dias_futuros" -gt 0 ]; then
    FUTURE_LIMIT=$(date -d "+$dias_futuros days" +"%Y%m%d%H%M%S")
    xmlstarlet ed -L -d "/tv/programme[@start > '$FUTURE_LIMIT']" miEPG.xml
fi

gzip -f miEPG.xml
cp miEPG.xml.gz "$GITHUB_WORKSPACE"

###############################################
# GENERAR EPG ACUMULADO
###############################################

echo "Generando epg_acumulado.xml.gz..."

# Descomprimir acumulado si existe
if [ -f "$GITHUB_WORKSPACE/epg_acumulado.xml.gz" ]; then
    gunzip -c "$GITHUB_WORKSPACE/epg_acumulado.xml.gz" > epg_acumulado.xml
else
    echo '<?xml version="1.0" encoding="UTF-8"?><tv></tv>' > epg_acumulado.xml
fi

# Descomprimir EPG del día
gunzip -c miEPG.xml.gz > miEPG.xml

# Calcular fecha límite
FECHA_LIMITE=$(date -d "$dias_pasados days ago" +"%Y%m%d%H%M%S")

# Eliminar programas antiguos
xmlstarlet ed -d "/tv/programme[@start < '$FECHA_LIMITE']" epg_acumulado.xml > epg_tmp.xml
mv epg_tmp.xml epg_acumulado.xml

# Añadir programas del día
xmlstarlet sel -t -c "/tv/programme" miEPG.xml >> epg_acumulado.xml

# Reconstruir XML limpio
echo '<?xml version="1.0" encoding="UTF-8"?>' > epg_final.xml
echo '<tv>' >> epg_final.xml
xmlstarlet sel -t -c "/tv/programme" epg_acumulado.xml >> epg_final.xml
echo '</tv>' >> epg_final.xml

mv epg_final.xml epg_acumulado.xml
gzip -f epg_acumulado.xml

cp epg_acumulado.xml.gz "$GITHUB_WORKSPACE"

echo "EPG diario y acumulado generados correctamente."






