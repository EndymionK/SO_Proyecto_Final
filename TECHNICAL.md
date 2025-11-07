# Minero PoW - Documentación Técnica

## Arquitectura del Sistema

### Componentes Principales

#### 1. SHA-256 Hash (`sha256_hash.h/cpp`)
Implementa el wrapper de OpenSSL para cálculo de hashes SHA-256.

**Función principal:**
- `std::string sha256(const std::string& input)`: Calcula el hash SHA-256 de una cadena.

#### 2. Sistema de Métricas (`metrics.h/cpp`)
Recolección de métricas de sistema y exportación a CSV.

**Métodos principales:**
- `get_cpu_time()`: Obtiene tiempo de CPU usando `getrusage()`
- `get_memory_mb()`: Lee memoria RSS desde `/proc/self/status`
- `export_to_csv()`: Exporta resultados en formato CSV

#### 3. Clase Miner (`miner.h/cpp`)
Núcleo del sistema de minería PoW.

**Métodos principales:**
- `mine()`: Punto de entrada que delega al modo correspondiente
- `mine_sequential()`: Búsqueda lineal en un solo hilo
- `mine_parallel()`: Búsqueda paralela con múltiples hilos en diferentes núcleos
- `mine_concurrent()`: Múltiples hilos fijados al mismo núcleo con `sched_setaffinity`
- `check_difficulty()`: Valida que un hash cumpla con la dificultad (bits iniciales en cero)
- `create_block_data()`: Genera datos del bloque a hashear

#### 4. Main (`main.cpp`)
Parseo de argumentos CLI y orquestación del flujo principal.

## Modos de Ejecución

### Sequential
- Un solo hilo
- Búsqueda lineal desde el nonce inicial
- Baseline para comparaciones

### Parallel
- N hilos distribuidos en múltiples núcleos
- Cada hilo busca en un rango diferente del espacio de nonces
- Sincronización mediante `std::atomic<bool>` para señal de "encontrado"
- Escalabilidad horizontal en sistemas multi-core

### Concurrent
- N hilos fijados al **mismo núcleo** usando `pthread_setaffinity_np`
- Simula concurrencia mediante context switching del scheduler
- Permite medir overhead de sincronización vs. modo secuencial
- Útil para estudiar el impacto de la planificación en un solo núcleo

## Validación de Dificultad

La dificultad se mide en **bits iniciales en cero** del hash hexadecimal.

**Algoritmo:**
1. Recorrer cada carácter hexadecimal del hash
2. Convertir a valor numérico (0-15)
3. Contar bits en cero de izquierda a derecha
4. Si se alcanza la dificultad requerida → válido
5. Si se encuentra un bit en 1 antes → inválido

**Ejemplo:** Dificultad = 16
- Hash: `0000abcd...` → 16 bits en cero (4 caracteres hex × 4 bits) → **VÁLIDO**
- Hash: `0001abcd...` → 11 bits en cero → **INVÁLIDO**

## Métricas Recolectadas

| Métrica | Descripción | Fuente |
|---------|-------------|--------|
| `total_hashes` | Total de hashes calculados | Contador interno |
| `elapsed_s` | Tiempo transcurrido (wall-clock) | `std::chrono::steady_clock` |
| `cpu_time_s` | Tiempo de CPU (user + system) | `getrusage(RUSAGE_SELF)` |
| `memory_mb` | Memoria RSS en MB | `/proc/self/status` (VmRSS) |
| `hashes_per_second` | Throughput | `total_hashes / elapsed_s` |
| `found` | Si se encontró un nonce válido | Booleano |
| `nonce` | Valor del nonce encontrado | uint64_t |

## Formato de Salida CSV

```csv
experiment_id,mode,difficulty,threads,affinity,found,nonce,total_hashes,elapsed_s,cpu_time_s,memory_mb,hashes_per_second
exp_001,sequential,16,1,false,true,36910,36911,0.051,0.045,6.75,726085
```

## Compilación

### Requisitos
- CMake >= 3.15
- Compilador C++17 (GCC/Clang)
- OpenSSL (libssl-dev)
- Ninja (opcional, recomendado)

### Comandos
```bash
# Configurar
cmake -S . -B build -G "Ninja" -DCMAKE_BUILD_TYPE=Release

# Compilar
cmake --build build -- -j$(nproc)

# Ejecutar
./build/miner --mode sequential --difficulty 16 --threads 1 --timeout 60 --seed 42 --metrics-out results.csv
```

## Uso

### Argumentos CLI

```
--mode <sequential|concurrent|parallel>  Modo de ejecución (requerido)
--difficulty <N>                         Bits iniciales en cero (requerido)
--threads <N>                            Número de hilos (requerido)
--timeout <seconds>                      Timeout en segundos (requerido)
--seed <N>                               Nonce inicial (default: 0)
--affinity <true|false>                  Habilitar CPU pinning (default: false)
--metrics-out <path>                     Archivo CSV de salida (requerido)
```

### Ejemplo
```bash
./build/miner \
  --mode parallel \
  --difficulty 20 \
  --threads 4 \
  --timeout 120 \
  --seed 42 \
  --affinity false \
  --metrics-out results/raw/exp_001.csv
```

## Experimentos

### Ejecución de Experimentos

```bash
# Ejecutar un experimento
./scripts/run_experiment.sh experiments/configs/exp_seq_low.json

# Analizar resultados
python3 scripts/parse_results.py
```

### Configuraciones de Experimento

Archivo JSON con estructura:
```json
{
  "id": "exp_001",
  "mode": "sequential",
  "difficulty": 20,
  "threads": 1,
  "affinity": false,
  "repetitions": 30,
  "timeout": 60,
  "seed": 42,
  "notes": "Description"
}
```

## Consideraciones de Rendimiento

### Factores que Afectan el Throughput

1. **Dificultad**: Mayor dificultad → más hashes necesarios
2. **Número de hilos**: Escalabilidad depende de núcleos disponibles
3. **CPU Pinning**: Reduce overhead en modo paralelo, esencial en modo concurrente
4. **Cache**: Modos paralelo/concurrente sufren más cache misses
5. **Sincronización**: Overhead de atomics en modos multi-thread

### Optimizaciones Aplicadas

- `-O3 -march=native`: Optimizaciones agresivas del compilador
- `std::atomic` con `memory_order_relaxed`: Sincronización eficiente
- División de rangos sin overlap: Evita trabajo duplicado
- Early exit: Todos los hilos se detienen al encontrar solución

## Estructura de Directorios

```
SO_Proyecto_Final/
├── CMakeLists.txt           # Configuración de compilación
├── src/                     # Código fuente
│   ├── main.cpp            # Entry point
│   ├── miner.{h,cpp}       # Lógica de minería
│   ├── sha256_hash.{h,cpp} # Wrapper SHA-256
│   ├── metrics.{h,cpp}     # Sistema de métricas
│   └── config.h            # Estructuras de datos
├── experiments/
│   └── configs/            # Configuraciones JSON
├── scripts/
│   ├── run_experiment.sh   # Ejecutor de experimentos
│   ├── parse_results.py    # Análisis de datos
│   └── collect_proc_metrics.sh
├── tests/
│   └── smoke_test.sh       # Prueba básica
└── results/
    ├── raw/                # CSVs individuales
    └── processed/          # Datos agregados
```

## Análisis Estadístico

El script `parse_results.py` genera:
- Media y desviación estándar de throughput por configuración
- Conteo de experimentos exitosos
- Tiempo promedio de ejecución
- Archivo `summary.csv` con resultados agregados

### Métricas de Análisis Recomendadas

- **Speedup**: S(n) = T(1) / T(n)
- **Eficiencia**: E(n) = S(n) / n
- **Throughput relativo**: HPS(parallel) / HPS(sequential)
- **Overhead concurrente**: HPS(concurrent) / HPS(sequential)

## Troubleshooting

### Error: "Could NOT find OpenSSL"
```bash
sudo apt install libssl-dev
```

### Error: "Permission denied" en scripts
```bash
chmod +x tests/*.sh scripts/*.sh
```

### Timeout constante
- Reducir dificultad (e.g., de 20 a 16)
- Aumentar timeout
- Verificar que el modo paralelo usa múltiples núcleos

### CSV vacío
- Verificar permisos de escritura en `results/`
- Confirmar que `--metrics-out` apunta a ruta válida
