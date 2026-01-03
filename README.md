# Actualizar e instalar ffmpeg

sudo apt update
sudo apt install -y ffmpeg fonts-freefont-ttf

# 2. Inicializar entorno virtual con uv (¡Velocidad luz!)

uv venv

# 3. Activar el entorno

source .venv/bin/activate

# 4. Instalar la herramienta

uv pip install gopro-overlay
