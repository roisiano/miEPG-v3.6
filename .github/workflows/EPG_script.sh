#!/bin/bash

set -e

# Cargar variables
source variables.txt

# Directorio temporal
WORKDIR=$(mktemp -d)
cd "$WORKDIR"

# Descargar y descomprimir todas las fuentes
for URL in $URLS; do
    wget -q "$URL" -O source.xml.gz
    gunzip -f source.xml.gz
    cat source.xml >> merged.xml
done

# Normalizar nombres de canales
for R in $RENAME; do
    OLD=$(echo "$R" | cut -d= -f1)
    NEW=$(echo "$R" | cut -d= -f2)
    xmlstarlet ed -L -u "//channel[@id='$OLD']/display-name" -v "$NEW" merged.xml
    xmlstarlet ed -L -u "//programme[@channel='$OLD']/@channel" -v "$NEW" merged.xml
done

# Eliminar canales excluidos
for C in $EXCLUDE_CHANNELS; do
    xmlstarlet ed -L -d "//channel[@id='$C']" merged.xml
    xmlstarlet ed -L -d "//programme[@channel='$C']" merged.xml
done

# Filtrar solo los canales permitidos
echo '<?xml version="1.0" encoding="UTF-8"?><tv>' > miEPG.xml
for C in $CHANNELS; do
    xmlstarlet sel -t -c "//channel[@id='$C']" merged.xml >> miEPG.xml
    xmlstarlet sel -t -c "//programme[@channel='$C']" merged.xml >> miEPG.xml
done
echo '</tv>' >> miEPG.xml

# Limitar días futuros
if [ "$dias-futuros" -gt 0 ]; then
    FUTURE_LIMIT=$(date -d "+$dias-futuros days" +"%Y%m%d%H%M%S")
    xmlstarlet ed -L -d "/tv/programme[@start > '$FUTURE_LIMIT']" miEPG.xml
fi

# Comprimir EPG del día
gzip -f miEPG.xml

###############################################
# ACUMULADO REAL BASADO EN dias-pasados
###############################################

# Descomprimir acumulado si existe
if [ -f epg_acumulado.xml.gz ]; then
    gunzip -c epg_acumulado.xml.gz > epg_acumulado.xml
else
    echo '<?xml version="1.0" encoding="UTF-8"?><tv></tv>' > epg_acumulado.xml
fi

# Descomprimir EPG del día
gunzip -c miEPG.xml.gz > miEPG.xml

# Calcular fecha límite para días pasados
DIAS_PASADOS=$(grep "^dias-pasados=" variables.txt | cut -d= -f2)
FECHA_LIMITE=$(date -d "$DIAS_PASADOS days ago" +"%Y%m%d%H%M%S")

# Eliminar programas demasiado antiguos del acumulado
xmlstarlet ed -d "/tv/programme[@start < '$FECHA_LIMITE']" epg_acumulado.xml > epg_tmp.xml
mv epg_tmp.xml epg_acumulado.xml

# Añadir los programas del día
xmlstarlet sel -t -c "/tv/programme" miEPG.xml >> epg_acumulado.xml

# Reconstruir XML limpio
echo '<?xml version="1.0" encoding="UTF-8"?>' > epg_final.xml
echo '<tv>' >> epg_final.xml
xmlstarlet sel -t -c "/tv/programme" epg_acumulado.xml >> epg_final.xml
echo '</tv>' >> epg_final.xml

mv epg_final.xml epg_acumulado.xml

# Comprimir acumulado
gzip -f epg_acumulado.xml

###############################################

# Copiar resultados al repositorio
cp miEPG.xml.gz "$GITHUB_WORKSPACE"
cp epg_acumulado.xml.gz "$GITHUB_WORKSPACE"





