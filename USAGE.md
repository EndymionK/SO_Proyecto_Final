# Guía de Uso del Minero PoW

## Inicio Rápido

### 1. Compilación

Desde WSL (Ubuntu):

```bash
cd /mnt/c/d/Proyectos_programacion/SO_Proyecto_FInal

# Primera vez: configurar CMake
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release

# Compilar
cmake --build build -- -j$(nproc)
```

### 2. Prueba Básica

```bash
# Ejecutar smoke test
./tests/smoke_test.sh
```

Si todo funciona, verás métricas y se creará `results/raw/smoke_test.csv`.

### 3. Ejecutar Modos Individualmente

#### Modo Secuencial
```bash
./build/miner \
  --mode sequential \
  --difficulty 16 \
  --threads 1 \
  --timeout 30 \
  --seed 42 \
  --metrics-out results/raw/test_seq.csv
```

#### Modo Paralelo (4 hilos)
```bash
./build/miner \
  --mode parallel \
  --difficulty 16 \
  --threads 4 \
  --timeout 30 \
  --seed 42 \
  --metrics-out results/raw/test_par.csv
```

#### Modo Concurrente (2 hilos en mismo núcleo)
```bash
./build/miner \
  --mode concurrent \
  --difficulty 16 \
  --threads 2 \
  --affinity true \
  --timeout 30 \
  --seed 42 \
  --metrics-out results/raw/test_con.csv
```

## Ejecutar Experimentos Completos

### Experimento Individual

Un experimento ejecuta N repeticiones (default: 30) de una configuración:

```bash
./scripts/run_experiment.sh experiments/configs/exp_seq_low.json
```

### Todos los Experimentos

Para ejecutar todos los experimentos predefinidos:

```bash
chmod +x scripts/run_all_experiments.sh
./scripts/run_all_experiments.sh
```

**Nota:** Esto puede tomar varios minutos dependiendo de las configuraciones.

## Análisis de Resultados

### Script de Análisis

```bash
source .venv/bin/activate
python3 scripts/parse_results.py
```

Esto genera `results/processed/summary.csv` con estadísticas agregadas.

### Ver Resumen

```bash
cat results/processed/summary.csv
```

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
