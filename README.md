# Minero PoW (entorno WSL2) — Guía rápida

Este README contiene los pasos mínimos para preparar el entorno de desarrollo usando WSL2 en Windows, crear un entorno virtual Python y ejecutar el proyecto desde Visual Studio Code (Remote - WSL).

## Resumen
- Recomendado: usar WSL2 (Ubuntu) para compilar/ejecutar y reproducir las instrucciones Linux del proyecto.
- Objetivo: tener toolchain C++ (g++, cmake), Python y un `venv` aislado.

---

## 1) Instalar WSL2 (PowerShell como Administrador)
Ejecuta en PowerShell (Admin):

```powershell
wsl --install -d Ubuntu
# Forzar WSL2 (si es necesario):
wsl --set-default-version 2
wsl --set-version Ubuntu 2
```

Abre la distro Ubuntu desde el menú o con:

```powershell
wsl -d Ubuntu
```

La primera ejecución pedirá crear un usuario y contraseña.

---

## 2) Dentro de WSL (Ubuntu): instalar herramientas de desarrollo
Abre la terminal WSL (Ubuntu) y ejecuta:

```bash
sudo apt update
sudo apt upgrade -y

# Compilador, CMake, Ninja, Git
sudo apt install -y build-essential cmake ninja-build git

# Python y virtualenv
sudo apt install -y python3 python3-pip python3-venv

# (Opcional) utilidades: htop, procps
sudo apt install -y htop procps
```

Si alguna instalación falla por paquetes faltantes (p. ej. `python3-distutils`), se recomiendan las alternativas de este README (crear venv en home o usar `--copies`).

---

## 3) Crear y usar un virtual environment (recomendado)
Se recomienda crear el `venv` en el filesystem de WSL (home) para evitar problemas de permisos en discos montados (`/mnt/*`).

```bash
# opción recomendada: crear venv dentro del home WSL
cd ~
cp -a /mnt/d/Proyectos_programacion/SO_Proyecto_FInal ./SO_Proyecto_FInal || true
cd SO_Proyecto_FInal
python3 -m venv .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install pandas scipy matplotlib
```

Si prefieres mantener el `venv` dentro de `/mnt/d`, intenta crear con la opción `--copies`:

```bash
cd /mnt/d/Proyectos_programacion/SO_Proyecto_FInal
python3 -m venv --copies .venv
source .venv/bin/activate
python -m pip install --upgrade pip
pip install pandas scipy matplotlib
```

Si encuentras errores de permisos al crear el venv en `/mnt`, otra opción es habilitar `metadata` en `/etc/wsl.conf` y reiniciar WSL (ver nota abajo).

---

## 4) Nota sobre montaje `/mnt` y `metadata`
Los discos Windows se montan en WSL como `drvfs`. Por defecto no siempre permiten symlinks/permisos Unix necesarios para `venv`. Si quieres permitir permisos/symlinks en `/mnt`, añade:

```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[automount]
options = "metadata"
EOF

# Luego, desde PowerShell en Windows:
# wsl --shutdown
# y volver a abrir la distro
```

Esto cambia el montaje y suele resolver problemas de venv dentro de `/mnt`, pero altera cómo Windows ve permisos de esos archivos.

---

## 5) Visual Studio Code — Remote - WSL
- Instalar VS Code en Windows.
- Instalar la extensión Remote - WSL en VS Code.
- Abrir la carpeta del proyecto desde WSL (desde WSL: `cd ~/SO_Proyecto_FInal && code .` o desde VS Code: Remote-WSL → Open Folder).
- Seleccionar el intérprete Python del venv: Ctrl+Shift+P → "Python: Select Interpreter" → elegir `/home/<usuario>/SO_Proyecto_FInal/.venv/bin/python`.

Consejo: en `.vscode/settings.json` puedes fijar el intérprete del workspace con `python.defaultInterpreterPath`.

---

## 6) Compilación y Prueba Rápida

```bash
# Configurar y compilar
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release
cmake --build build -- -j$(nproc)

# Ejecutar smoke test
./tests/smoke_test.sh

# O ejecutar manualmente
./build/miner --mode sequential --difficulty 16 --threads 1 --timeout 10 --seed 42 --metrics-out results/raw/test.csv
```

---

## 7) Documentación del Proyecto

El proyecto incluye documentación completa:

- **[USAGE.md](USAGE.md)**: Guía de uso paso a paso, ejecución de experimentos y análisis
- **[TECHNICAL.md](TECHNICAL.md)**: Arquitectura del sistema, algoritmos y detalles técnicos
- **[instrucciones.md](instrucciones.md)**: Especificaciones del proyecto y objetivos académicos

### Inicio Rápido

1. **Compilar**: `./tests/smoke_test.sh`
2. **Ejecutar experimento**: `./scripts/run_experiment.sh experiments/configs/exp_seq_low.json`
3. **Analizar resultados**: `source .venv/bin/activate && python3 scripts/parse_results.py`

---

## 8) Estructura del Proyecto

```
SO_Proyecto_Final/
├── CMakeLists.txt           # Configuración de compilación
├── src/                     # Código fuente C++
│   ├── main.cpp            # Entry point y parseo de argumentos
│   ├── miner.{h,cpp}       # Lógica de minería PoW
│   ├── sha256_hash.{h,cpp} # Wrapper SHA-256
│   ├── metrics.{h,cpp}     # Recolección de métricas
│   └── config.h            # Estructuras de configuración
├── experiments/configs/     # Configuraciones de experimentos (JSON)
├── scripts/                 # Scripts de automatización
│   ├── run_experiment.sh   # Ejecutor de experimentos
│   ├── run_all_experiments.sh
│   ├── parse_results.py    # Análisis estadístico
│   └── collect_proc_metrics.sh
├── tests/                   # Pruebas
│   └── smoke_test.sh
└── results/                 # Resultados de experimentos
    ├── raw/                # CSVs individuales
    └── processed/          # Análisis agregados
```

---

## 9) Registro y Reproducibilidad

```bash
# Guardar dependencias Python
source .venv/bin/activate
pip freeze > requirements.txt

# Información del sistema
lscpu > system_info.txt
uname -a >> system_info.txt
```

Para experimentos, incluir en el informe:
- Especificaciones de CPU (núcleos, frecuencia)
- Versión del sistema operativo
- Versión del compilador (`g++ --version`)
- Commit de git del código usado