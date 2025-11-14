# Minero PoW — Proof-of-Work Miner (CPU)

Este proyecto implementa y evalúa experimentalmente un minero Proof-of-Work simplificado en C++ con tres modos de ejecución: **secuencial**, **concurrente** (con CPU pinning) y **paralelo** (multi-thread). El objetivo es comparar rendimiento, escalabilidad y overhead en función del número de hilos, dificultad y afinidad de CPU.

## 📋 Tabla de Contenidos
- [Resumen](#resumen)
- [Inicio Rápido](#inicio-rápido-flujo-completo)
- [Estructura del Proyecto](#estructura-del-proyecto)
- [Requisitos](#requisitos)
- [Uso Avanzado](#uso-avanzado)
  - [Configuración de Experimentos](#configuración-de-experimentos)
  - [Ejecución Manual del Minero](#ejecutar-el-minero-directamente)
- [Análisis de Resultados](#análisis-de-resultados-notebook)
- [Arquitectura Técnica](#arquitectura-técnica)
  - [Componentes del Sistema](#componentes-principales)
  - [Modos de Ejecución](#modos-de-ejecución-detallados)
  - [Validación de Dificultad](#validación-de-dificultad)
  - [Métricas Recolectadas](#métricas-recolectadas)
- [Troubleshooting](#soporte-y-troubleshooting)
- [Guía Rápida](#guía-rápida-de-referencia)

## Resumen
- **Lenguaje:** C++ (con `std::thread`, `std::atomic`, Windows Threading API)
- **Hashing:** SHA-256 (OpenSSL)
- **Métricas:** Throughput (hashes/s), tiempo, uso de CPU/memoria
- **Análisis:** Python (pandas, scipy, matplotlib) para estadística y gráficas
- **Plataforma:** Windows nativo (MinGW-w64 + MSYS2)

---

## Inicio rápido (flujo completo)

### 1. Clonar el repositorio
```powershell
git clone <repo-url>
cd SO_Proyecto_Final
```

### 2. Configurar entorno Python (Windows PowerShell)
```powershell
.\scripts\setup_env.ps1
.\.venv\Scripts\Activate.ps1
```

### 3. Compilar el minero (Windows nativo con MinGW)
```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_CXX_COMPILER=g++
cmake --build build
```

### 4. Ejecutar experimentos completos (Windows PowerShell)
```powershell
.\scripts\run_all_modes.ps1 -Clean
```

Este script:
- Limpia resultados anteriores (opcional con `-Clean`)
- Ejecuta todos los experimentos desde `experiments/configs/` (5 repeticiones por defecto)
- Genera metadata del sistema en `results/EXPERIMENT_INFO.md`

### 5. Analizar resultados con el notebook
```powershell
# Activar entorno Python si no está activo
.\.venv\Scripts\Activate.ps1

# Abrir Jupyter Notebook
jupyter notebook notebooks/analisis_rendimiento.ipynb
```

En el notebook:
1. Ejecuta todas las celdas (Cell > Run All)
2. El notebook generará automáticamente:
   - **Summary CSV:** `results/processed/summary.csv`
   - **Estadísticas:** `results/processed/statistical_summary.txt`
   - **Config stats:** `results/processed/config_stats.csv`
   - **Gráficas:** `results/processed/plots/*.png`

### 6. Revisar resultados
- **📊 Análisis completo:** `notebooks/analisis_rendimiento.ipynb` (recomendado)
- **Metadata del sistema:** `results/EXPERIMENT_INFO.md`
- **Datos crudos:** `results/raw/*.csv`
- **Resultados procesados:** `results/processed/`

---

## Estructura del proyecto
```
SO_Proyecto_Final/
├── src/                    # Código C++ del minero
│   ├── main.cpp
│   ├── miner.cpp/h
│   ├── metrics.cpp/h
│   ├── config.h
│   └── sha256_hash.cpp/h
├── experiments/configs/    # Configuraciones JSON de experimentos
├── scripts/
│   ├── run_all_modes.ps1   # Orquestador maestro (Windows/PowerShell)
│   ├── Run-Experiment.ps1  # Ejecuta un experimento individual
│   ├── Collect-ProcessMetrics.ps1  # Captura métricas de proceso
│   ├── setup_env.ps1       # Configura entorno Python (Windows)
│   └── clean_results.ps1   # Limpia resultados anteriores
├── notebooks/
│   └── analisis_rendimiento.ipynb  # Análisis completo (PROCESAMIENTO MANUAL)
├── results/
│   ├── raw/                # CSVs crudos de cada ejecución
│   ├── meta/               # Metadata de experimentos
│   ├── processed/          # Resúmenes, estadísticas y gráficas (generados por notebook)
│   └── EXPERIMENT_INFO.md  # Metadata del sistema
├── CMakeLists.txt
├── requirements.txt        # Dependencias Python
├── README.md               # Este archivo
├── USAGE.md                # Guía de uso detallada
├── TECHNICAL.md            # Documentación técnica
└── instrucciones.md        # Enunciado del proyecto
```

---

## Requisitos

### Sistema operativo
- **Windows** con MinGW-w64 (MSYS2)
- Windows PowerShell 5.1+

### Compilación (C++)
- MinGW-w64 GCC 7+ con soporte C++17
- CMake 3.10+
- Ninja build system
- OpenSSL (incluido en MSYS2)

Instalar toolchain:
```powershell
# Descargar MSYS2 desde https://www.msys2.org/
# En terminal MSYS2:
pacman -S mingw-w64-x86_64-gcc mingw-w64-x86_64-cmake mingw-w64-x86_64-ninja mingw-w64-x86_64-openssl
```

### Análisis (Python)
- Python 3.7+
- pandas, scipy, matplotlib, seaborn, jupyter

Instala con:
```powershell
pip install -r requirements.txt
```

---

## Uso avanzado

### Ejecutar un experimento individual
```powershell
.\scripts\Run-Experiment.ps1 -ConfigPath experiments\configs\exp_seq_low.json
```

### Limpiar resultados anteriores
```powershell
.\scripts\clean_results.ps1 -Archive -Force
```

### Ejecutar prueba rápida (smoke test)
```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
.\build\miner.exe --mode sequential --difficulty 18 --threads 1 --timeout 10 --metrics-out smoke_test.csv
```

### Análisis manual de resultados
1. Ejecutar experimentos con `.\scripts\run_all_modes.ps1`
2. Abrir el notebook: `notebooks\analisis_rendimiento.ipynb`
3. Ejecutar todas las celdas (Run All) para generar análisis completo

### Ejecutar el minero directamente

#### Modo Sequential (baseline)
```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
.\build\miner.exe --mode sequential --difficulty 18 --threads 1 --timeout 60 --seed 42 --metrics-out results\raw\manual_seq.csv
```

#### Modo Parallel (4 hilos en múltiples núcleos)
```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
.\build\miner.exe --mode parallel --difficulty 18 --threads 4 --timeout 60 --seed 42 --metrics-out results\raw\manual_par.csv
```

#### Modo Concurrent (2 hilos con CPU pinning)
```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
.\build\miner.exe --mode concurrent --difficulty 18 --threads 2 --affinity true --timeout 60 --seed 42 --metrics-out results\raw\manual_con.csv
```

**Nota:** El modo concurrent con `--affinity true` fija todos los hilos a un solo CPU para simular ejecución concurrente en un núcleo.

#### Opciones CLI disponibles

| Opción | Valores | Descripción |
|--------|---------|-------------|
| `--mode` | `sequential`, `parallel`, `concurrent` | Modo de ejecución (requerido) |
| `--difficulty` | 16-24 | Bits iniciales en cero requeridos (requerido) |
| `--threads` | 1-16 | Número de threads (requerido) |
| `--timeout` | segundos | Tiempo máximo de ejecución (requerido) |
| `--seed` | número | Nonce inicial para reproducibilidad (default: 0) |
| `--affinity` | `true`/`false` | Habilitar CPU pinning (default: false) |
| `--metrics-out` | path | Archivo CSV de salida (requerido) |

### Configuración de Experimentos

Los experimentos se definen en archivos JSON en `experiments/configs/`:

```json
{
  "id": "exp_custom",
  "mode": "parallel",
  "difficulty": 20,
  "threads": 4,
  "affinity": false,
  "repetitions": 30,
  "timeout": 120,
  "seed": 42,
  "notes": "Descripción del experimento"
}
```

#### Campos del JSON

- **id**: Identificador único del experimento
- **mode**: `sequential`, `parallel` o `concurrent`
- **difficulty**: Bits iniciales en cero (16-24 recomendado)
  - 16 bits: Muy rápido (~0.05s secuencial)
  - 20 bits: Rápido (~2-10s secuencial)
  - 24 bits: Moderado (~1-5min secuencial)
- **threads**: Número de hilos (usar potencias de 2: 1, 2, 4, 8)
- **affinity**: `true` fija hilos al CPU 0 (solo efectivo en concurrent)
- **repetitions**: Número de ejecuciones (mínimo 30 para validez estadística)
- **timeout**: Tiempo máximo en segundos (60-120 recomendado)
- **seed**: Semilla para reproducibilidad

#### Crear nuevo experimento

```powershell
# Copiar template
Copy-Item experiments\configs\exp_seq_low.json experiments\configs\exp_custom.json

# Editar parámetros con tu editor favorito
notepad experiments\configs\exp_custom.json

# Ejecutar
.\scripts\Run-Experiment.ps1 -ConfigPath experiments\configs\exp_custom.json
```

---

---

## Análisis de Resultados (Notebook)

El proyecto incluye un **notebook Jupyter interactivo** que centraliza TODO el análisis estadístico:

### 📊 `notebooks/analisis_rendimiento.ipynb`

**Contenido completo:**

1. **Carga de Datos**
   - Agregación automática de todos los CSVs en `results/raw/`
   - Normalización de nombres de columnas
   - Validación de integridad

2. **Estadísticas Descriptivas**
   - Tablas resumen por modo, threads y dificultad
   - Distribución de métricas (throughput, tiempo, CPU, memoria)
   - Conteo de ejecuciones por configuración

3. **Análisis Comparativo por Modo**
   - Comparación Sequential vs Parallel vs Concurrent
   - Speedup relativo al baseline (Sequential)
   - Análisis por número de hilos

4. **Speedup y Eficiencia**
   - Cálculo de speedup real vs ideal (lineal)
   - Eficiencia de paralelización (%)
   - Gráficas comparativas con línea ideal

5. **Análisis Estadístico Riguroso**
   - **ANOVA** paramétrico (f_oneway)
   - **Kruskal-Wallis** no paramétrico
   - **Mann-Whitney U** con corrección de Bonferroni
   - Interpretación automática de significancia (p < 0.001, p < 0.05)

6. **Visualizaciones Completas**
   - Throughput vs Threads por modo
   - Speedup y eficiencia vs ideal
   - Boxplots y violin plots de distribuciones
   - Gráfico de barras con error bars (desviación estándar)
   - Heatmap threads × modo
   - Scatter plot tiempo vs memoria

7. **Resumen Ejecutivo Automatizado**
   - Mejor configuración detectada
   - Comparación Parallel vs Concurrent
   - Recomendaciones basadas en resultados
   - Análisis del impacto de CPU pinning

8. **Exportación de Resultados**
   - `results/processed/summary.csv` — Speedup y eficiencia
   - `results/processed/config_stats.csv` — Estadísticas por configuración
   - `results/processed/statistical_summary.txt` — Tests estadísticos
   - `results/processed/plots/*.png` — 5 gráficas de alta resolución (300 DPI)

### Uso del Notebook

```powershell
# Activar entorno Python
.\.venv\Scripts\Activate.ps1  # Windows PowerShell

# Iniciar Jupyter
jupyter notebook notebooks\analisis_rendimiento.ipynb
```

En VS Code:
1. Abrir `notebooks\analisis_rendimiento.ipynb`
2. Seleccionar kernel Python 3.13
3. Ejecutar todas las celdas (Cell > Run All)
4. Los resultados procesados se guardarán automáticamente en `results/processed/`

### Resultados Principales

**Hallazgos clave del análisis:**

✅ **PARALLEL (4 threads):** MEJOR rendimiento
- Speedup: **2.68×** (167% más rápido que sequential)
- Efficiency: **67%** (buena escalabilidad)
- Throughput: **1.68M hashes/s**

⚠️ **CONCURRENT (4 threads):** Overhead severo
- Speedup: **1.12×** (solo 12% mejor que sequential)
- Efficiency: **28%** (contención de locks dominante)
- Throughput: **708k hashes/s**

📊 **Diferencia:** Parallel es **138%** más rápido que Concurrent
- p-value < 0.001 (altamente significativo estadísticamente)
- Concurrent sufre de: `std::atomic` overhead, false sharing, coherencia de caché

**✅ Validación:** 210/210 ejecuciones exitosas, CV < 0.5, sin anomalías detectadas

### Archivos de Análisis

| Archivo | Descripción | Uso |
|---------|-------------|-----|
| `notebooks/analisis_rendimiento.ipynb` | **Análisis completo interactivo** | ✅ USAR ESTE |
| `results/processed/summary.csv` | Speedup y eficiencia (generado por notebook) | Referencia |
| `results/processed/statistical_summary.txt` | Tests estadísticos (generado por notebook) | Revisión rápida |
| `results/EXPERIMENT_INFO.md` | Metadata del sistema | Contexto |

**Recomendación:** Ejecutar el notebook para generar todo el análisis automáticamente.

---

## Arquitectura Técnica

### Componentes Principales

#### 1. SHA-256 Hash (`sha256_hash.h/cpp`)
Implementa el wrapper de OpenSSL para cálculo de hashes SHA-256.

**Función principal:**
```cpp
std::string sha256(const std::string& input);
```

Calcula el hash SHA-256 de una cadena y retorna representación hexadecimal.

#### 2. Sistema de Métricas (`metrics.h/cpp`)
Recolección de métricas de sistema y exportación a CSV usando **Windows API nativo**.

**Métodos principales:**
- `get_cpu_time()`: Obtiene tiempo de CPU usando `GetProcessTimes()` (Windows API)
- `get_memory_mb()`: Lee memoria de trabajo (Working Set) usando `GetProcessMemoryInfo()` (Windows API)
- `export_to_csv()`: Exporta resultados en formato CSV estándar

#### 3. Clase Miner (`miner.h/cpp`)
Núcleo del sistema de minería PoW.

**Métodos principales:**
- `mine()`: Punto de entrada que delega al modo correspondiente
- `mine_sequential()`: Búsqueda lineal en un solo hilo
- `mine_parallel()`: Búsqueda paralela con múltiples hilos en diferentes núcleos
- `mine_concurrent()`: Múltiples hilos fijados al mismo núcleo
- `check_difficulty()`: Valida que un hash cumpla con la dificultad
- `create_block_data()`: Genera datos del bloque a hashear

#### 4. Main (`main.cpp`)
Parseo de argumentos CLI y orquestación del flujo principal.

### Modos de Ejecución Detallados

#### Sequential
- **Un solo hilo**
- Búsqueda lineal desde el nonce inicial
- Baseline para todas las comparaciones
- Sin overhead de sincronización
- Rendimiento: ~600k hashes/s (dificultad 16, AMD Ryzen 7 5700X)

#### Parallel
- **N hilos distribuidos en múltiples núcleos**
- Cada hilo busca en un rango diferente del espacio de nonces
- División: `range = MAX_NONCE / threads`
- Sincronización mediante `std::atomic<bool>` para señal de "encontrado"
- Early exit: todos los hilos se detienen al encontrar solución
- Escalabilidad horizontal en sistemas multi-core
- **Rendimiento:** ~1.68M hashes/s con 4 threads (speedup 2.68×)

**Código simplificado:**
```cpp
void mine_parallel(uint64_t start_nonce, int num_threads) {
    std::atomic<bool> found(false);
    std::vector<std::thread> threads;
    
    uint64_t range = UINT64_MAX / num_threads;
    for (int i = 0; i < num_threads; i++) {
        threads.emplace_back([&, i]() {
            uint64_t my_start = start_nonce + i * range;
            uint64_t my_end = my_start + range;
            
            for (uint64_t nonce = my_start; nonce < my_end && !found; nonce++) {
                if (check_difficulty(hash(create_block_data(nonce)))) {
                    found = true;
                    result_nonce = nonce;
                    break;
                }
            }
        });
    }
    
    for (auto& t : threads) t.join();
}
```

#### Concurrent
- **N hilos fijados al mismo núcleo** usando `SetThreadAffinityMask()` (Windows API)
- Simula concurrencia mediante context switching del scheduler
- Todos los hilos compiten por el mismo core
- Permite medir overhead de sincronización vs. modo secuencial
- **Rendimiento:** ~708k hashes/s con 4 threads (speedup 1.12×, apenas mejor que sequential)

**CPU Pinning (Windows API):**
```cpp
void mine_concurrent(uint64_t start_nonce, int num_threads) {
    // Detectar CPU disponible
    DWORD_PTR process_affinity, system_affinity;
    GetProcessAffinityMask(GetCurrentProcess(), &process_affinity, &system_affinity);
    
    DWORD target_cpu = 0;  // CPU 0 por defecto
    if (config_.affinity && process_affinity != 0) {
        for (DWORD i = 0; i < sizeof(DWORD_PTR) * 8; i++) {
            if ((process_affinity & (1ULL << i)) != 0) {
                target_cpu = i;
                break;
            }
        }
    }
    
    for (int i = 0; i < num_threads; i++) {
        threads.emplace_back([&, i, target_cpu]() {
            // Fijar al CPU target_cpu usando Windows API
            if (config_.affinity) {
                DWORD_PTR thread_affinity = 1ULL << target_cpu;
                SetThreadAffinityMask(GetCurrentThread(), thread_affinity);
            }
            
            // Minería igual que parallel
            // ...
        });
    }
}
```

### Validación de Dificultad

La dificultad se mide en **bits iniciales en cero** del hash hexadecimal.

**Algoritmo:**
1. Convertir hash a representación hexadecimal
2. Recorrer cada carácter hex del inicio
3. Convertir a valor numérico (0-15)
4. Contar bits en cero de izquierda a derecha
5. Si se alcanza la dificultad requerida → válido
6. Si se encuentra un bit en 1 antes → inválido

**Ejemplo con dificultad = 16:**
- Hash: `0000abcd...` → 16 bits en cero (4 chars × 4 bits) → ✅ **VÁLIDO**
- Hash: `0001abcd...` → 11 bits en cero → ❌ **INVÁLIDO**

**Código:**
```cpp
bool check_difficulty(const std::string& hash_hex, int difficulty) {
    int bits_zero = 0;
    for (char c : hash_hex) {
        int val = (c >= '0' && c <= '9') ? (c - '0') : (c - 'a' + 10);
        
        for (int bit = 3; bit >= 0; bit--) {
            if (val & (1 << bit)) {
                return bits_zero >= difficulty;
            }
            bits_zero++;
            if (bits_zero >= difficulty) return true;
        }
    }
    return bits_zero >= difficulty;
}
```

### Métricas Recolectadas

| Métrica | Descripción | Fuente | Tipo |
|---------|-------------|--------|------|
| `experiment_id` | ID del experimento | Config JSON | string |
| `mode` | Modo de ejecución | CLI arg | string |
| `difficulty` | Bits cero requeridos | CLI arg | int |
| `threads` | Número de hilos | CLI arg | int |
| `affinity` | CPU pinning habilitado | CLI arg | bool |
| `found` | Nonce válido encontrado | Resultado | bool |
| `nonce` | Valor del nonce | uint64_t | uint64_t |
| `total_hashes` | Total de hashes calculados | Contador | uint64_t |
| `elapsed_s` | Tiempo wall-clock | `std::chrono::steady_clock` | double |
| `cpu_time_s` | Tiempo de CPU | `GetProcessTimes()` (Windows API) | double |
| `memory_mb` | Memoria de trabajo | `GetProcessMemoryInfo()` (Windows API) | double |
| `hashes_per_second` | Throughput | `total_hashes / elapsed_s` | double |

**Formato CSV de salida:**
```csv
experiment_id,mode,difficulty,threads,affinity,found,nonce,total_hashes,elapsed_s,cpu_time_s,memory_mb,hashes_per_second
exp_001,sequential,16,1,false,true,36910,36911,0.051,0.045,6.75,726085
exp_001,parallel,16,4,false,true,688,1321,0.011,0.007,6.62,118270
```

### Optimizaciones Aplicadas

1. **Compilación:**
   - `-O3`: Optimizaciones agresivas del compilador
   - `-march=native`: Instrucciones específicas del CPU
   - `-DCMAKE_BUILD_TYPE=Release`: Modo release sin símbolos de debug

2. **Sincronización:**
   - `std::atomic<bool>` con `memory_order_relaxed`: Mínimo overhead
   - Early exit: todos los hilos se detienen al encontrar solución

3. **División del trabajo:**
   - Rangos sin overlap: evita trabajo duplicado
   - Balanceo estático: cada thread conoce su rango desde el inicio

4. **Caché:**
   - Cada thread trabaja en su rango → mejor localidad espacial
   - Minimiza false sharing

### Factores que Afectan el Rendimiento

1. **Dificultad**: Mayor dificultad → más hashes necesarios (exponencial)
2. **Número de hilos**: Escalabilidad depende de núcleos físicos disponibles
3. **CPU Pinning**: Reduce overhead en parallel, degrada en concurrent
4. **Caché**: Modos multi-thread sufren más cache misses
5. **Sincronización**: Overhead de atomics y barreras de memoria
6. **Context Switching**: Penaliza modo concurrent severamente

---

## Documentación adicional
- **CUMPLIMIENTO.md** — Verificación de requisitos del proyecto
- **instrucciones.md** — Enunciado completo del proyecto

---

## Soporte y troubleshooting

### Error: miner.exe not found
Compila el proyecto primero:
```powershell
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
cmake -S . -B build -G Ninja -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

### Error: pandas not found
Activa el entorno virtual e instala dependencias:
```powershell
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
```

### Conflictos de dependencias Python
```powershell
.\.venv\Scripts\Activate.ps1
pip install --upgrade pip
pip install -r requirements.txt --force-reinstall
```

### Notebook no encuentra datos
Asegúrate de ejecutar desde la raíz del proyecto:
```powershell
cd C:\d\Proyectos_programacion\SO_Proyecto_Final
.\.venv\Scripts\Activate.ps1
jupyter notebook notebooks\analisis_rendimiento.ipynb
```

### Gráficas no se muestran en el notebook
```python
# Añadir al inicio del notebook si es necesario
%matplotlib inline
```

---

## Licencia
Este proyecto es de uso académico para el curso de Sistemas Operativos.

## Autores
[Tu nombre / equipo]

---

## 📚 Guía Rápida de Referencia

### Comandos Esenciales

```powershell
# 1. Setup completo (primera vez)
.\scripts\setup_env.ps1                    # Windows - Setup Python
$env:Path = "C:\msys64\mingw64\bin;" + $env:Path
cmake -S . -B build -G Ninja               # Compilar
.\scripts\run_all_modes.ps1 -Clean         # Ejecutar experimentos

# 2. Análisis
jupyter notebook notebooks\analisis_rendimiento.ipynb  # Abrir notebook y Run All

# 3. Limpieza
.\scripts\clean_results.ps1 -Force         # Limpiar resultados
```

### Estructura de Archivos Clave

```
SO_Proyecto_Final/
├── README.md                    ← 📖 ESTE ARCHIVO (guía completa unificada)
├── src/                         ← Código C++ del minero
│   ├── main.cpp                ← Entry point y CLI parsing
│   ├── miner.{h,cpp}           ← Lógica de minería (3 modos)
│   ├── sha256_hash.{h,cpp}     ← Wrapper SHA-256 OpenSSL
│   ├── metrics.{h,cpp}         ← Sistema de métricas
│   └── config.h                ← Estructuras de datos
├── experiments/configs/         ← 7 configuraciones JSON
├── scripts/
│   ├── run_all_modes.ps1       ← 🚀 Ejecutor maestro (PowerShell)
│   ├── Run-Experiment.ps1      ← Ejecución individual
│   ├── Collect-ProcessMetrics.ps1 ← Monitor de proceso
│   ├── setup_env.ps1           ← Setup Python (Windows)
│   └── clean_results.ps1       ← Limpieza
├── notebooks/
│   └── analisis_rendimiento.ipynb ← 📊 ANÁLISIS COMPLETO (procesamiento manual)
├── results/
│   ├── raw/                    ← CSVs de ejecuciones
│   ├── meta/                   ← Metadata JSON
│   ├── processed/              ← Generados por notebook (summary, stats, plots)
│   └── EXPERIMENT_INFO.md      ← Metadata del sistema
├── CMakeLists.txt              ← Configuración de compilación
├── requirements.txt            ← Dependencias Python
└── instrucciones.md            ← Enunciado del proyecto
```

### Flujo de Trabajo Típico

1. **Desarrollo/Modificación:**
   ```powershell
   # Editar código en src/
   $env:Path = "C:\msys64\mingw64\bin;" + $env:Path
   cmake --build build
   
   # Ejecutar prueba rápida
   .\build\miner.exe --mode sequential --difficulty 18 --threads 1 --timeout 10
   ```

2. **Experimentos Completos:**
   ```powershell
   .\scripts\run_all_modes.ps1 -Clean
   # Esperar según configuración (5 reps aprox 5-10 min)
   ```

3. **Análisis e Informe:**
   ```powershell
   # Activar entorno
   .\.venv\Scripts\Activate.ps1
   
   # Abrir notebook
   jupyter notebook notebooks\analisis_rendimiento.ipynb
   
   # En el notebook: Cell > Run All
   # Los resultados procesados se guardan automáticamente en results/processed/
   ```

4. **Limpieza (opcional):**
   ```powershell
   .\scripts\clean_results.ps1 -Force
   ```

---