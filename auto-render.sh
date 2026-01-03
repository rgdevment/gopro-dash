#!/bin/bash

# --- 1. Configuración de Rutas Dinámicas ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_BIN="$SCRIPT_DIR/.venv/bin"
LAYOUT_FILE="$SCRIPT_DIR/layout_custom_moto.xml"
FONT_PATH="/mnt/c/Windows/Fonts/arial.ttf"

# --- 2. Validación de Dependencias ---
if [ ! -f "$LAYOUT_FILE" ]; then
    echo "❌ Error Crítico: No encuentro el archivo de diseño."
    echo "   Buscado en: $LAYOUT_FILE"
    exit 1
fi

if [ ! -x "$VENV_BIN/gopro-dashboard.py" ]; then
    echo "❌ Error Crítico: No encuentro el entorno virtual o los scripts."
    echo "   Buscado en: $VENV_BIN"
    exit 1
fi

# --- 3. Validación de Argumentos ---
TARGET_DIR="$1"

if [ -z "$TARGET_DIR" ]; then
    echo "❌ Error: Falta la carpeta de videos."
    echo "Uso: ./auto-render.sh '/ruta/a/READY'"
    exit 1
fi

if [ ! -d "$TARGET_DIR" ]; then
    echo "❌ Error: La carpeta no existe: $TARGET_DIR"
    exit 1
fi

echo "🎬 Iniciando Fábrica de Renders"
echo "📂 Directorio: $TARGET_DIR"
echo "🎨 Layout:     $(basename "$LAYOUT_FILE")"
echo "---------------------------------------------------"

# --- 4. Bucle de Procesamiento ---
find "$TARGET_DIR" -maxdepth 1 -type f -name "*_Master.mp4" -print0 | while IFS= read -r -d '' INPUT_VIDEO; do

    BASENAME=$(basename "$INPUT_VIDEO")
    DIRNAME=$(dirname "$INPUT_VIDEO")

    # Lógica de nombres: Video_XXXX_Master.mp4 -> Video_XXXX_FINAL.mp4
    FINAL_NAME="${BASENAME/_Master/_FINAL}"

    GPX_FILE="${INPUT_VIDEO%.*}.gpx"
    OUTPUT_VIDEO="$DIRNAME/$FINAL_NAME"

    echo "🍿 Procesando: $BASENAME"

    # --- LIMPIEZA PREVIA (Sobrescritura forzada) ---
    if [ -f "$GPX_FILE" ]; then
        rm "$GPX_FILE"
    fi
    # dejamos que ffmpeg lo sobrescriba con -y (yes) si el proceso inicia bien.

    # --- PASO A: EXTRACCIÓN DE TELEMETRÍA ---
    echo "   📍 Extrayendo GPS..."

    "$VENV_BIN/gopro-to-gpx.py" --gps-speed-max 300 "$INPUT_VIDEO" "$GPX_FILE" > /dev/null 2>&1

    if [ ! -f "$GPX_FILE" ] || [ ! -s "$GPX_FILE" ]; then
        echo "   ❌ Error: Falló la extracción del GPX (o el archivo está vacío)."
        echo "   ⚠️  Saltando este video."
        echo "---------------------------------------------------"
        continue
    fi
    echo "   ✅ GPX Generado correctamente."

    # --- PASO B: RENDERIZADO DEL DASHBOARD ---
    echo "   🎨 Renderizando Dashboard (Esto tomará tiempo)..."

    "$VENV_BIN/gopro-dashboard.py" \
        --profile "nvenc_av1" \
        --layout "xml" \
        --layout-xml "$LAYOUT_FILE" \
        --double-buffer \
        --gps-speed-max 300 \
        --font "$FONT_PATH" \
        --gpx "$GPX_FILE" \
        "$INPUT_VIDEO" \
        "$OUTPUT_VIDEO" < /dev/null

    if [ $? -eq 0 ] && [ -s "$OUTPUT_VIDEO" ]; then
        echo "   🏆 EXITO! Video guardado en:"
        echo "      $OUTPUT_VIDEO"
    else
        echo "   ❌ ERROR CRÍTICO EN RENDERIZADO."
        # Si quedó un archivo corrupto (0 bytes), borrarlo
        if [ -f "$OUTPUT_VIDEO" ] && [ ! -s "$OUTPUT_VIDEO" ]; then
            rm "$OUTPUT_VIDEO"
        fi
    fi

    echo "---------------------------------------------------"
done

echo "🏁 Todos los procesos terminados."
