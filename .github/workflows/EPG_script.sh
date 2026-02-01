#!/bin/bash

set -e

###############################################
# CARGAR VARIABLES (corregidas)
###############################################

source variables.txt

# Validación mínima
if [ -z "$dias_pasados" ] || [ -z "$dias_futuros" ]; then
    echo "ERROR: variables dias_pasados o dias_futuros no definidas."
    exit 1
fi

###############################################
# GENERACIÓN DEL EPG DIARIO (TAL CUAL ESTÁ)
###############################################

# Ejecutar tu script original SIN MODIFICARLO
bash .github/workflows/original_miEPG_script.sh

# Comprobar que miEPG.xml.gz existe
if [ ! -f miEPG.xml.gz ]; then
    echo "ERROR: miEPG.xml.gz no fue generado por el script original."
    exit 1
fi

###############################################
# GENERACIÓN DEL EPG ACUMULADO
###############################################

echo "Generando epg_acumulado.xml.gz basado en dias_pasados=$dias_pasados..."

# Descomprimir acumulado si existe
if [ -f epg_acumulado.xml.gz ]; then
    gunzip -c epg_acumulado.xml.gz > epg_acumulado.xml
else
    echo '<?xml version="1.0" encoding="UTF-8"?><tv></tv>' > epg_acumulado.xml
fi

# Descomprimir EPG del día
gunzip -c miEPG.xml.gz > miEPG.xml

# Calcular fecha límite para días pasados
FECHA_LIMITE=$(date -d "$dias_pasados days ago" +"%Y%m%d%H%M%S")

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
# COPIAR RESULTADOS AL REPO
###############################################

cp miEPG.xml.gz "$GITHUB_WORKSPACE"
cp epg_acumulado.xml.gz "$GITHUB_WORKSPACE"

echo "EPG diario y acumulado generados correctamente."






