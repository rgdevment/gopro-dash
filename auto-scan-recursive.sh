#!/bin/bash

ROOT_DIR="$1"

# --- 1. Validación de Entrada ---
if [ -z "$ROOT_DIR" ]; then
    echo "❌ Error: Debes indicar la carpeta raíz."
    exit 1
fi

if [ ! -d "$ROOT_DIR" ]; then
    echo "❌ Error: No existe el directorio: $ROOT_DIR"
    exit 1
fi

# --- 2. Configuración de Carpetas ---
READY_DIR="$ROOT_DIR/READY"
# Creamos la carpeta si no existe (-p evita error si ya existe)
mkdir -p "$READY_DIR"

echo "🛡️  Iniciando Modo Seguro (Copiar -> Verificar -> Borrar)"
echo "📂 Procesando: $ROOT_DIR"
echo "📂 Destino: $READY_DIR"
echo "---------------------------------------------------"

# --- 3. Bucle Principal ---
# Usamos -print0 y read -d '' para manejar rutas con espacios correctamente
find "$ROOT_DIR" -maxdepth 1 -type f -name "GX01*.MP4" -print0 | while IFS= read -r -d '' HEAD_FILE; do

    # Extraemos info básica del archivo encontrado
    BASENAME=$(basename "$HEAD_FILE")
    VIDEO_ID="${BASENAME:4:4}"  # Extrae los 4 digitos del ID (ej: 0197)
    DIRNAME=$(dirname "$HEAD_FILE")

    # Definimos el nombre del archivo final estandarizado
    TARGET_MASTER="$READY_DIR/Video_${VIDEO_ID}_Master.mp4"

    # CHEQUEO DE SEGURIDAD: ¿Ya existe el Master final?
    if [ -f "$TARGET_MASTER" ] && [ -s "$TARGET_MASTER" ]; then
        echo "⚠️  El Master $VIDEO_ID ya existe y tiene datos. Se omite."
        continue
    fi

    # Buscamos si tiene partes hermanas (GX02, GX03...) en la misma carpeta
    # find maneja bien los espacios en las rutas
    SEQUENCE_COUNT=$(find "$DIRNAME" -maxdepth 1 -name "GX*${VIDEO_ID}.MP4" | wc -l)

    if [ "$SEQUENCE_COUNT" -gt 1 ]; then
        echo "🔗 Secuencia detectada ID $VIDEO_ID ($SEQUENCE_COUNT partes)"
        echo "   🚀 Uniendo..."

        ./.venv/bin/gopro-join.py "$HEAD_FILE" "$TARGET_MASTER" < /dev/null

        if [ $? -eq 0 ] && [ -s "$TARGET_MASTER" ]; then
            echo "   ✅ Unión exitosa. Borrando originales..."

            # Borrado seguro de todas las partes
            find "$DIRNAME" -maxdepth 1 -name "GX*${VIDEO_ID}.MP4" -delete

            echo "   🗑️  Originales eliminados."
        else
            echo "   ❌ Falló la unión. NO SE BORRA NADA."
            # Limpiamos el archivo destino si quedó corrupto (0 bytes)
            if [ -f "$TARGET_MASTER" ] && [ ! -s "$TARGET_MASTER" ]; then
                rm "$TARGET_MASTER"
            fi
        fi

    else
        echo "👤 Video Solitario ID $VIDEO_ID"
        echo "   📋 Copiando a READY_MASTERS..."

        # 1. COPIAR
        cp "$HEAD_FILE" "$TARGET_MASTER"

        # 2. VERIFICAR INTEGRIDAD
        if [ $? -eq 0 ] && [ -s "$TARGET_MASTER" ]; then
            echo "   ✅ Copia verificada. Eliminando original..."

            # 3. BORRAR ORIGINAL
            rm "$HEAD_FILE"
        else
            echo "   ❌ Error al copiar. El original SE MANTIENE."
            # Limpieza de basura en destino
             if [ -f "$TARGET_MASTER" ] && [ ! -s "$TARGET_MASTER" ]; then
                rm "$TARGET_MASTER"
            fi
        fi
    fi
    echo "---------------------------------------------------"
done

echo "🏁 Proceso terminado. Revisa la carpeta 'READY_MASTERS'."
