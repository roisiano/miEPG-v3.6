#!/bin/bash

set -e

# Cargar variables
source variables.txt

###############################################
# GENERACIÓN DEL EPG DIARIO (TAL CUAL ESTÁ)
###############################################

# Ejecutar el script original que genera miEPG.xml.gz
# ---------------------------------------------------
# IMPORTANTE:
# Aquí NO se toca nada. Tu script original ya genera
# miEPG.xml.gz correctamente. Simplemente lo ejecutamos.
# ---------------------------------------------------

bash .github/workflows/original_miEPG_script.sh

# Asegurar que miEPG.xml.gz existe
if [ ! -f miEPG.xml.gz ]; then
    echo "ERROR: miEPG.xml.gz no fue generado por el script original."
    exit 1
fi

###############################################
# GENERACIÓN DEL EPG ACUMULADO
###############################################

echo "Generando epg_acumulado.xml.gz basado en dias-pasados..."

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

# Copiar resultados al repositorio
cp miEPG.xml.gz "$GITHUB_WORKSPACE"
cp epg_acumulado.xml.gz "$GITHUB_WORKSPACE"

echo "EPG diario y acumulado generados correctamente."





