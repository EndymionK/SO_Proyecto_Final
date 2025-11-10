# Guía de Uso del Minero PoW

Esta guía describe cómo compilar, ejecutar y analizar el minero Proof-of-Work. Para información general, ver `README.md`. Para detalles técnicos, ver `TECHNICAL.md`.

---

## Flujo Principal (Ejecución Maestra)

### 1. Configurar entorno Python

**Windows PowerShell:**
```powershell
.\scripts\setup_env.ps1
.\.venv\Scripts\Activate.ps1
```

**WSL/Linux:**
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

### 2. Compilar el minero

**WSL/Linux:**
```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build -- -j$(nproc)
```

Verifica que `build/miner` sea ejecutable:
```bash
./build/miner --help
```

### 3. Ejecutar todos los experimentos

**Windows PowerShell:**
```powershell
.\scripts\run_all_modes.ps1 -Clean
```

Opciones:
- `-Clean` — Elimina resultados anteriores antes de empezar
- Sin argumentos — Ejecuta todos los experimentos sin limpiar

Este script:
1. Lee todas las configuraciones de `experiments/configs/`
2. Ejecuta cada experimento (30 repeticiones por defecto) invocando `run_experiment.sh` via WSL
3. Llama a `parse_results.py` para generar análisis estadístico y gráficas
4. Crea un reporte consolidado en `results/processed/REPORT.md`

**Tiempo estimado:** 10-30 minutos dependiendo del hardware y número de configuraciones.

### 4. Revisar resultados

Después de la ejecución, revisa:

- **`results/processed/REPORT.md`** — Reporte consolidado con información del PC, configuración y resultados
- **`results/processed/summary.csv`** — Métricas agregadas (media, std, speedup, efficiency)
- **`results/processed/stats_summary.csv`** — Tests estadísticos (ANOVA, Kruskal-Wallis)
- **`results/processed/stats_summary.txt`** — Análisis estadístico legible
- **`results/processed/plots/`** — Gráficas de throughput vs threads por experimento

### 5. Análisis interactivo (opcional)

Abre el notebook de Jupyter:
```bash
source .venv/bin/activate
jupyter notebook notebooks/analysis.ipynb
```

El notebook carga automáticamente los CSVs de `results/experiments/` y genera gráficas adicionales.

---

## Uso Avanzado

### Ejecutar un experimento individual

```bash
./scripts/run_experiment.sh experiments/configs/exp_seq_low.json
```

Esto ejecuta las repeticiones configuradas en el JSON y guarda CSVs en `results/raw/` y metadata en `results/meta/`.

### Ejecutar el minero manualmente

#### Modo Secuencial (baseline)
```bash
./build/miner \
  --mode sequential \
  --difficulty 18 \
  --threads 1 \
  --timeout 60 \
  --seed 42 \
  --metrics-out results/raw/manual_seq.csv
```

#### Modo Paralelo (4 hilos)
```bash
./build/miner \
  --mode parallel \
  --difficulty 18 \
  --threads 4 \
  --timeout 60 \
  --seed 42 \
  --metrics-out results/raw/manual_par.csv
```

#### Modo Concurrente (2 hilos con CPU pinning)
```bash
./build/miner \
  --mode concurrent \
  --difficulty 18 \
  --threads 2 \
  --affinity true \
  --timeout 60 \
  --seed 42 \
  --metrics-out results/raw/manual_con.csv
```

**Nota:** El modo concurrente con `--affinity true` fija todos los hilos al CPU 0 para simular ejecución concurrente en un solo núcleo.

### Análisis manual de resultados

Si ejecutaste experimentos manualmente o quieres reprocesar resultados:

```bash
source .venv/bin/activate
python scripts/parse_results.py --raw-dir results/raw --out-dir results/processed
```

### Limpiar resultados anteriores

**Windows PowerShell:**
```powershell
.\scripts\clean_results.ps1 -Archive -Force
```

Opciones:
- `-Archive` — Crea un ZIP con los archivos antes de eliminarlos
- `-RemoveRaw` — Elimina CSVs crudos (default: true)
- `-RemoveProcessed` — Elimina resultados procesados (default: false)
- `-RemoveExperiments` — Elimina carpetas de experimentos (default: true)
- `-Force` — No pide confirmación

---

## Pruebas Básicas

### Smoke Test

Compila y ejecuta una prueba rápida:
```bash
./tests/smoke_test.sh
```

Esto verifica que:
- El proyecto compila correctamente
- El minero encuentra un nonce válido
- Se generan métricas en CSV

---

## Configuración de Experimentos

Los experimentos se definen en `experiments/configs/*.json`. Ejemplo:

```json
{
  "id": "exp_seq_low",
  "mode": "sequential",
  "difficulty": 16,
  "threads": 1,
  "affinity": false,
  "repetitions": 30,
  "timeout": 60,
  "seed": 42,
  "notes": "Sequential baseline - low difficulty"
}
```

### Campos

- **id**: Identificador único del experimento
- **mode**: `sequential`, `parallel` o `concurrent`
- **difficulty**: Número de bits iniciales en cero (16-24 recomendado)
- **threads**: Número de hilos (1-8)
- **affinity**: `true` para forzar CPU pinning (solo en modo concurrent)
- **repetitions**: Número de ejecuciones (mínimo 30 recomendado para validez estadística)
- **timeout**: Tiempo máximo en segundos
- **seed**: Semilla para reproducibilidad

### Crear nuevos experimentos

1. Copia un config existente:
```bash
cp experiments/configs/exp_seq_low.json experiments/configs/exp_custom.json
```

2. Edita los parámetros según necesites

3. Ejecuta:
```bash
./scripts/run_experiment.sh experiments/configs/exp_custom.json
```

O incluye el nuevo config en `run_all_modes.ps1` (se detecta automáticamente si está en `experiments/configs/`).

---

## Interpretación de Resultados

### Métricas Clave

- **hashes_per_second (throughput):** Rendimiento bruto del minero
- **elapsed_s:** Tiempo total de ejecución
- **cpu_time_s:** Tiempo de CPU consumido
- **memory_mb:** Memoria residente (RSS)
- **speedup:** Aceleración relativa al baseline secuencial (threads=1)
- **efficiency:** Speedup / threads (0-1, ideal = 1)

### Análisis Estadístico

El archivo `results/processed/stats_summary.txt` contiene:

- **ANOVA:** Test paramétrico para diferencias entre grupos
- **Kruskal-Wallis:** Test no paramétrico (alternativa robusta)
- **Pairwise Mann-Whitney U:** Comparaciones entre pares de modos con corrección de Bonferroni

**Interpretación:**
- p-value < 0.05 → Diferencias estadísticamente significativas
- p-value ≥ 0.05 → No hay evidencia suficiente de diferencia

### Gráficas

- **Throughput vs Threads:** Muestra escalabilidad de cada modo
- **Speedup:** Compara aceleración de parallel/concurrent vs sequential
- **Boxplots (notebook):** Muestran distribución y outliers

---

## Solución de Problemas

### Error: miner not found
```bash
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Error: pandas not found
```bash
source .venv/bin/activate
pip install -r requirements.txt
```

### WSL: Permission denied en /mnt
Crea el proyecto en home WSL:
```bash
cd ~
cp -a /mnt/d/Proyectos_programacion/SO_Proyecto_Final ./
cd SO_Proyecto_Final
```

### Error: timeout too short, no nonce found
Aumenta `timeout` en el config JSON o reduce `difficulty`.

---

## Referencias

- **README.md** — Inicio rápido y estructura del proyecto
- **TECHNICAL.md** — Detalles de implementación
- **instrucciones.md** — Enunciado completo del proyecto

---

*Última actualización: 2025-11-07*

El resumen incluye:
- Media y desviación estándar de hashes/segundo
- Conteo de repeticiones
- Tiempo promedio de ejecución

## Configuración de Experimentos

Los archivos JSON en `experiments/configs/` definen experimentos.

### Estructura del JSON

```json
{
  "id": "exp_unique_id",
  "mode": "sequential|concurrent|parallel",
  "difficulty": 16,
  "threads": 1,
  "affinity": false,
  "repetitions": 30,
  "timeout": 60,
  "seed": 42,
  "notes": "Descripción del experimento"
}
```

### Crear Nuevo Experimento

1. Copiar un template: `cp experiments/configs/exp_template.json experiments/configs/exp_custom.json`
2. Editar parámetros
3. Ejecutar: `./scripts/run_experiment.sh experiments/configs/exp_custom.json`

## Parámetros Importantes

### Dificultad

- **16 bits**: Muy rápido (~0.05s en secuencial)
- **20 bits**: Rápido (~2-10s en secuencial)
- **24 bits**: Moderado (~1-5min en secuencial)
- **28+ bits**: Muy lento (puede requerir horas)

**Recomendación:** Empezar con 16-20 para pruebas, 20-24 para experimentos.

### Número de Hilos

- **1**: Baseline secuencial
- **2**: Comparación básica paralelo vs concurrente
- **4**: Típico para laptops/desktops modernos
- **8+**: Workstations/servidores

**Recomendación:** Usar potencias de 2 (1, 2, 4, 8) para claridad en análisis.

### Timeout

- Debe ser suficiente para que al menos algunos runs encuentren solución
- Si todos los runs expiran, reducir dificultad o aumentar timeout
- Para experimentos: 60-120 segundos suele ser suficiente

### Affinity

- `false`: Los hilos pueden migrar entre núcleos (modo paralelo)
- `true`: Los hilos se fijan a un núcleo (modo concurrente)

**Importante:** El flag `affinity` solo tiene efecto real en modo `concurrent`.

## Análisis Estadístico

### Calcular Speedup

```python
import pandas as pd

df = pd.read_csv('results/processed/summary.csv')

# Speedup = Throughput(N threads) / Throughput(1 thread)
baseline = df[df['threads'] == 1]['hashes_per_second_mean'].values[0]
df['speedup'] = df['hashes_per_second_mean'] / baseline
```

### Calcular Eficiencia

```python
# Eficiencia = Speedup / N threads
df['efficiency'] = df['speedup'] / df['threads']
```

### Visualización

```python
import matplotlib.pyplot as plt

# Throughput por número de hilos
plt.figure(figsize=(10, 6))
for mode in df['mode'].unique():
    subset = df[df['mode'] == mode]
    plt.plot(subset['threads'], subset['hashes_per_second_mean'], 
             marker='o', label=mode)
plt.xlabel('Número de hilos')
plt.ylabel('Hashes por segundo')
plt.legend()
plt.title('Throughput vs. Hilos por Modo')
plt.grid(True)
plt.savefig('results/throughput_analysis.png')
```

## Troubleshooting

### Error: "miner: command not found"

Recompilar:
```bash
cmake --build build -- -j$(nproc)
```

### Error: OpenSSL no encontrado

Instalar:
```bash
sudo apt install libssl-dev
```

### Todos los experimentos timeout

- Reducir dificultad en configs JSON
- Aumentar timeout
- Verificar que el sistema no esté sobrecargado

### CSVs vacíos

Verificar permisos:
```bash
chmod -R 755 results/
```

### Python: "No module named pandas"

Activar venv e instalar:
```bash
python3 -m venv .venv
source .venv/bin/activate
pip install pandas scipy matplotlib
```

## Estructura de Resultados

```
results/
├── raw/                    # CSVs individuales de cada ejecución
│   ├── exp_seq_low_run_20250107_rep1.csv
│   ├── exp_seq_low_run_20250107_rep2.csv
│   └── ...
├── processed/              # Análisis agregados
│   └── summary.csv
└── meta/                   # Metadata de experimentos
    └── *.meta.json
```

## Consejos para el Informe

1. **Baseline claro**: Siempre incluir modo secuencial (threads=1)
2. **Repeticiones suficientes**: Mínimo 30 por configuración para validez estadística
3. **Condiciones controladas**: Cerrar aplicaciones innecesarias durante experimentos
4. **Documentar hardware**: Incluir specs de CPU (núcleos, frecuencia)
5. **Gráficas comparativas**: Speedup, eficiencia, throughput
6. **Intervalos de confianza**: Usar desviación estándar para mostrar variabilidad
7. **Discutir overhead**: Comparar modo concurrente vs secuencial

## Comandos Útiles

### Ver todos los CSVs generados
```bash
ls -lh results/raw/
```

### Contar experimentos completados
```bash
wc -l results/raw/*.csv
```

### Limpiar resultados anteriores
```bash
rm -rf results/raw/* results/processed/*
```

### Ver uso de CPU durante ejecución
```bash
htop
```

### Verificar núcleos disponibles
```bash
nproc
lscpu
```
