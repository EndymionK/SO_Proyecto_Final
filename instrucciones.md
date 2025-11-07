Resumen
Se propone implementar y evaluar experimentalmente un minero Proof-of-Work (PoW) simplificado que utilice SHA-256 y un criterio de dificultad basado en bits/ceros iniciales. El objetivo es comparar tres modos de ejecución: secuencial (single-worker), concurrente (múltiples tareas lógicas ejecutándose de forma concurrente en un solo núcleo mediante planificación o corutinas) y paralelo (multi-thread en varios núcleos). Se medirán throughput (hashes/s), tiempo hasta encontrar un nonce (cuando aplique), uso de CPU, consumo de memoria, latencias, temperatura y, si es posible, consumo energético. El experimento estudiará el efecto del número de hilos/tareas, la fijación de afinidad (CPU pinning) y la dificultad sobre el rendimiento, y evaluará estadísticamente si la concurrencia y la paralelización mejoran el rendimiento y en qué condiciones aparece overhead. Esta investigación aporta evidencia empírica sobre escalabilidad y eficiencia en cargas CPU-bound con hashing intensivo.
Introducción
La minería de criptomonedas y, en general, los algoritmos PoW, dependen de cálculos intensivos de hashing. Comprender cómo se comportan en distintas modalidades de ejecución en CPU permite estudiar la eficiencia de estrategias de programación concurrente y paralela, así como los límites que imponen la arquitectura y el sistema operativo. Aunque en la práctica la minería se realiza con ASICs y GPUs, estudiar la ejecución en CPU brinda un laboratorio controlado para analizar el impacto de la planificación, afinidad, concurrencia y paralelismo en el rendimiento.
Este análisis es relevante no solo en el contexto de la minería, sino también en aplicaciones de propósito general que enfrentan cargas de trabajo intensivas, como servidores web, bases de datos o software científico, donde la forma de estructurar la ejecución puede determinar la eficiencia del sistema.
Antecedentes y marco teórico
El mecanismo de Proof-of-Work (PoW) es un esquema de consenso que exige resolver un problema computacionalmente costoso —generalmente basado en hashing— cuya verificación, sin embargo, es sencilla. En este proyecto se utilizará SHA-256, una función criptográfica ampliamente utilizada en sistemas como Bitcoin, cuya eficiencia en CPU depende de implementaciones optimizadas.
En el ámbito de los sistemas operativos, dos conceptos clave son la concurrencia y el paralelismo. La concurrencia permite estructurar programas en múltiples tareas que comparten un mismo CPU mediante planificación, mientras que el paralelismo se apoya en la ejecución simultánea en varios núcleos físicos. Ambas aproximaciones presentan retos como la sincronización, la contención de caches y el costo de los cambios de contexto.
Estos conceptos se relacionan directamente con temas centrales del curso, como planificación de procesos e hilos, afinidad a CPU, sincronización, métricas de rendimiento y administración de recursos en entornos multicore, ofreciendo una oportunidad para verlos aplicados en un escenario práctico.
Objetivos
Objetivo  principal
Evaluar el impacto de la ejecución secuencial, concurrente y paralela en el rendimiento de un minero PoW simplificado en CPU.
Objetivos específicos
•	Implementar un minero PoW en C++ con tres modos de ejecución: secuencial, concurrente y paralelo.
•	Diseñar experimentos controlados variando número de hilos o tareas, dificultad y afinidad.
•	Medir métricas de rendimiento como hashes por segundo, tiempo hasta solución, uso de CPU y memoria.
•	Analizar estadísticamente los resultados para identificar condiciones de escalabilidad y sobrecarga.
•	Relacionar los hallazgos con los conceptos de concurrencia, paralelismo y planificación vistos en clase.
Alcance y limitaciones
Este proyecto se centra en evaluar el rendimiento de diferentes estrategias de ejecución en CPU en el contexto de un minero PoW. No se busca optimizar el minero para competir con implementaciones en GPU o ASIC. Tampoco se abordarán aspectos de seguridad criptográfica, sino únicamente el análisis de rendimiento y eficiencia en un entorno controlado.
Metodología
La implementación se realizará en C++, empleando std::thread y primitivas atómicas para el manejo de hilos. En el modo concurrente se explorará la ejecución de múltiples tareas en un solo núcleo, ya sea mediante afinidad forzada o corutinas. Para la medición se recurrirá a herramientas del sistema como /proc, getrusage y sched_setaffinity. La recolección y análisis de datos se apoyará en Bash para automatizar experimentos y en Python (pandas, scipy, matplotlib) para el procesamiento estadístico y la visualización de resultados.
Actividades principales:
•	Implementación del modo secuencial.
•	Desarrollo de los modos concurrente y paralelo.
•	Integración de rutinas de medición y logging.
•	Diseño y ejecución de experimentos.
•	Análisis estadístico de resultados.
•	Redacción del informe final.
Diseño de Experimentos
La validación de la solución se hará verificando que el minero encuentre nonces válidos para distintos niveles de dificultad y midiendo su rendimiento en las tres modalidades de ejecución. Se controlará el hardware y el entorno de software, documentando CPU, sistema operativo, compilador y banderas de optimización.
Las variables a considerar son: dificultad (baja, media, alta), número de hilos o tareas (1, 2, 4, 8, …), afinidad (ON/OFF) y modo de ejecución (secuencial, concurrente, paralelo). Cada configuración se repetirá al menos 30 veces para garantizar validez estadística.
El análisis incluirá cálculos de medias, intervalos de confianza y comparaciones mediante ANOVA o pruebas no paramétricas según corresponda. También se estimará el speedup y la eficiencia. Los resultados se presentarán con gráficas comparativas y boxplots que ilustren tendencias y dispersiones.
