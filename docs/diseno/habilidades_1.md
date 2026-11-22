# Habilidades 1

**Subtítulo:** Habilidades intrínsecas iniciales de las cinco naturalezas y modelo matemático de nivel 1 a 60.  
**Proyecto:** JRPG / dungeon crawler de criaturas, asimilación y exploración de mundo cotidiano.  
**Estado:** propuesta cuantificada para prototipado y pruebas, **no balance final aprobado**.  
**Documento complementario:** `inicio_y_progresion_de_la_historia.md`.  
**Referencia conceptual:** `sistema_de_naturalezas_y_asimilacion_parte_1.md`.

> **Para Claude / desarrollo:** conservar los nombres y condiciones funcionales; implementar fórmulas parametrizadas y pruebas automáticas. No convertir valores tentativos, comportamientos de IA o rangos de exploración en reglas inamovibles. No conceder estas habilidades automáticamente a protagonistas humanos solo por pertenecer a la naturaleza Biológica.

## 1. Condiciones de diseño y reparto exacto

- Hay cinco naturalezas base: **Biológico, Mecánico, Digital, Psíquico y Místico**.
- Cada naturaleza tiene **5 habilidades**: exactamente **2 de ataque**, **1 de apoyo** y **2 de función libre** (defensa/utilidad, en esta primera propuesta).
- Por naturaleza, hay **2 activas + 3 pasivas** o **3 activas + 2 pasivas**. No hay clases fijas de melee/tirador/apoyo.
- Se trata de **habilidades comunes de naturaleza**, no de árboles de subtipo, poderes de asimilación ni de habilidades de armas. Los subtipos especializan después esta base; puede haber coincidencias parciales entre técnicas de distintos subtipos.
- **Disponibilidad ≠ aprendizaje automático.** La anatomía, el soporte material, el equipo, el momento narrativo y la progresión pueden condicionar una habilidad.
- Los tipos de daño y las debilidades se evalúan por **mecanismo y compatibilidad real**, no por triángulos universales de ventajas entre naturalezas.
- Una entidad Digital sin soporte físico, interfaz o proceso expuesto puede ser inalcanzable por determinados ataques convencionales; igualmente puede carecer de canal ofensivo contra una criatura sin tecnología.

| Naturaleza | Ataque | Apoyo | Libres | Activas | Pasivas |
|---|---:|---:|---:|---:|---:|
| Biológico | 2 | 1 | 2 | 3 | 2 |
| Mecánico | 2 | 1 | 2 | 2 | 3 |
| Digital | 2 | 1 | 2 | 3 | 2 |
| Psíquico | 2 | 1 | 2 | 3 | 2 |
| Místico | 2 | 1 | 2 | 2 | 3 |
| **Total** | **10** | **5** | **10** | **13** | **12** |

## 2. Diccionario matemático

### 2.1. Atributos

| Atributo | Código | Uso inicial propuesto |
|---|---|---|
| Fuerza | `FUE` | Golpes, impacto y esfuerzo físico |
| Técnica | `TEC` | Manipulación de sistemas, precisión, mecánica e interfaces |
| Inteligencia | `INT` | Procesamiento, daños digitales, depuración |
| Voluntad | `VOL` | Ataques y defensa psíquica/mística, concentración |
| Resistencia | `RES` | Integridad, defensa física, regeneración, supervivencia |
| Agilidad | `AGI` | Iniciativa y evasión general (no usada directamente en estas 25 fórmulas iniciales) |

Todas las entidades pueden utilizar atributos equivalentes; el significado depende de su soporte. `RES` para un robot expresa integridad estructural y no metabolismo. Esta lista es la base **propuesta para el prototipo**, no sustituye decisiones futuras sobre estadísticas definitivas.

### 2.2. Fórmulas centrales

Se evalúan en este orden: **compatibilidad → objetivo válido → coste/disponibilidad → ejecución → daño/curación → probabilidad de estados → aplicación de estados**. La política exacta de consumir PM si el objetivo resulta inválido está pendiente; conviene bloquear la selección imposible en la UI.

**PV máximos**

```text
PV_max(L, RES) = 100 + 10 × L + 5 × RES
```

**PM máximos (reserva genérica de habilidad, provisional)**

```text
PM_max(L, INT, VOL) = 35 + 3 × L + 2 × max(INT, VOL)
```

**Daño base antes del multiplicador de habilidad**

```text
D(L, A, R) = (18 + 2 × L + 2,6 × A) × 100 / (100 + R)
```

`A` es el atributo ofensivo definido por la habilidad. `R` es la defensa efectiva del objetivo. Referencia inicial:

- Daño físico y corrosión material: `R = RES` del objetivo.
- Intrusión o ataque informático: `R = TEC` del objetivo o de su soporte digital susceptible.
- Daño psíquico: `R = VOL` del objetivo.
- Daño místico: `R = RES` si actúa materialmente o `R = VOL` si actúa sobre entidad espiritual/voluntad. **Debe quedar fijado en la variante concreta del ataque**, no elegir en cada ejecución la defensa que más favorezca al atacante.

**Curación/restauración base**

```text
C(L, A) = 18 + 1,6 × L + 2,2 × A
```

**Coste de PM de una habilidad activa**

```text
CostePM(L) = C0 + ceil(k × (L − 1))
```

`C0` y `k` son constantes **por habilidad** indicadas en las tablas. `L >= 1`; `ceil` significa redondeo al entero superior. El coste se calcula **directamente desde el nivel actual**; NO se suma el coeficiente a un valor ya redondeado cada vez que se sube de nivel. Las pasivas no consumen PM por activación.

**Probabilidad efectiva de aplicar un estado (después de verificar compatibilidad)**

```text
P_estado = clamp(P0 + 0,35 × (A − R_estado) − E, 5, 90)   [en %]
```

- `P0`: probabilidad base propia de la habilidad (p. ej. 60 %).
- `A`: atributo del atacante empleado para infligir ese estado.
- `R_estado`: atributo de resistencia correspondiente del objetivo (no necesariamente idéntico a la defensa de daño).
- `E`: resistencia adicional del objetivo a ese estado en **puntos porcentuales**.
- `clamp(x,5,90)`: limita el porcentaje entre 5 % y 90 % **solo si el objetivo es susceptible**.
- Objetivo incompatible o inmune: `P_estado = 0` directamente; nunca aplicar el mínimo de 5 % a inmunidades.
- El éxito de un estado se comprueba por separado del daño inicial, salvo que luego se pacte otra regla.

**Redondeos para el prototipo:** los puntos finales de daño y curación se redondean una vez, al entero más cercano con mitades hacia arriba; el coste PM con `ceil`; las probabilidades y bonificaciones mantienen decimales internamente. Los daños periódicos se redondean por aplicación. Se puede cambiar esta convención solo con tests actualizados.

### 2.3. Restricciones de compatibilidad y soporte

Una habilidad necesita `requirements` verificables. Ejemplos de condiciones de entidad/objetivo:

```text
hasLivingTissue
hasRegenerableTissue
hasPhysicalBody
hasCorrodibleMaterial
hasAccessibleDigitalProcess
hasConsciousMind
hasInterpretableMind
hasMysticAnchor
hasValidMysticLink
hasCompatibleProjectionMechanism
```

Estas son etiquetas técnicas propuestas, no una taxonomía definitiva. La asimilación, los componentes implantados y el equipo pueden modificar las etiquetas. Una infección de tejidos no afecta por defecto a una máquina sin tejidos; un ácido sí puede afectar a materiales susceptibles. Una IA consciente puede ser susceptible a ataques psíquicos aunque no sea orgánica. La descripción **Digital** no autoriza daños contra toda entidad arbitrariamente.

## 3. Catálogo de habilidades (25)

En las fórmulas, `D(A)` abrevia `D(L, atributo A, defensa correspondiente)` y `C(A)` abrevia `C(L, atributo A)`. Para activas, el coste es `C0 + ceil(k × (L−1))`; `CD` indica turnos de reutilización, con `CD 0` = sin tiempo adicional tras el turno de uso.

### 3.1. Biológico

**Identidad:** metabolismo, capacidad de adaptación, química orgánica, recuperación y rastros. La corrosión química puede afectar a materiales, no solo a organismos.

| ID estable | Habilidad | Activación / función | Efecto escalable | Coste PM | CD | Condición / precisión importante |
|---|---|---|---|---|---:|---|
| `bio_impulso_organico` | **Impulso orgánico** | Activa · Ataque | D físico × 1,10; atributo `FUE` | `7 + ceil(0,22 × (L−1))` | 0 | Cuerpo a cuerpo. Fuerza muscular o presión interna. Requiere anatomía capaz de ejecutar el movimiento. |
| `bio_secrecion_caustica` | **Secreción cáustica** | Activa · Ataque | D corrosivo × 0,82; 60 % base de corrosión: RES −8 % durante 2 turnos; atributo `RES` | `10 + ceil(0,27 × (L−1))` | 0 | Proyectil/sustancia. El material del objetivo debe ser susceptible. Requiere secreción u órgano apropiado. Corrosión ≠ infección. |
| `bio_regeneracion_celular` | **Regeneración celular** | Activa · Apoyo | C × 0,85 PV restaurados; atributo `RES` | `11 + ceil(0,32 × (L−1))` | 2 | Sobre sí o aliado con tejidos regenerables. No restaura maquinaria ni datos por defecto. |
| `bio_homeostasis` | **Homeostasis** | Pasiva · Defensa | Reducción relativa de probabilidad de alteraciones metabólicas: min(30 %, 8 + 0,20 × RES)%; atributo `RES` | 0 (pasiva) | — | Solo alteraciones metabólicas compatibles; no protege de todas las condiciones. |
| `bio_quimiorrecepcion` | **Quimiorrecepción** | Pasiva · Utilidad | Radio: min(5, 2 + ⌊(RES + L)/45⌋) casillas; atributo `RES` | 0 (pasiva) | — | Rastros químicos u orgánicos presentes; no garantiza descubrir todas las criaturas. |

### 3.2. Mecánico

**Identidad:** impacto, estructura, precisión, blindaje, autodiagnóstico. No toda máquina tiene forma humanoide o proyector de fragmentos.

| ID estable | Habilidad | Activación / función | Efecto escalable | Coste PM | CD | Condición / precisión importante |
|---|---|---|---|---|---:|---|
| `mec_impacto_cinetico` | **Impacto cinético** | Activa · Ataque | D físico × 1,18; atributo `FUE` | `8 + ceil(0,25 × (L−1))` | 0 | Golpe cuerpo a cuerpo con acumulación/liberación de energía; requiere mecanismo físico. |
| `mec_proyeccion_fragmentos` | **Proyección de fragmentos** | Activa · Ataque | D físico × 0,90; atributo `TEC` | `9 + ceil(0,24 × (L−1))` | 0 | Ataque a distancia; requiere mecanismo de proyección y material o munición apropiados. |
| `mec_calibracion` | **Calibración** | Pasiva · Apoyo | Precisión compatible +min(9, 3 + 0,06 × TEC) puntos porcentuales; atributo `TEC` | 0 (pasiva) | — | Mejora la precisión de equipo/acciones compatibles; no concede armas ni puntería infinita. |
| `mec_blindaje_adaptativo` | **Blindaje adaptativo** | Pasiva · Defensa | Reducción de daño repetido del mismo tipo: min(22, 7 + 0,17 × RES)%; atributo `RES` | 0 (pasiva) | — | Solo tras impactos consecutivos del mismo tipo; reinicia tras 2 turnos sin recibirlo. |
| `mec_autodiagnostico` | **Autodiagnóstico** | Pasiva · Utilidad | Radio: min(4, 1 + ⌊(TEC + L)/45⌋) casillas; atributo `TEC` | 0 (pasiva) | — | Identifica componentes, defectos y sobrecargas mecánicas accesibles. |

### 3.3. Digital

**Identidad:** datos, procesos, redes, interfaces. Los ataques digitales permanecen en el catálogo aunque la historia inicial no habilite enfrentamientos directos contra entidades puramente digitales.

| ID estable | Habilidad | Activación / función | Efecto escalable | Coste PM | CD | Condición / precisión importante |
|---|---|---|---|---|---:|---|
| `dig_corrupcion_datos` | **Corrupción de datos** | Activa · Ataque | D informático × 1,03; atributo `INT` | `8 + ceil(0,24 × (L−1))` | 0 | Necesita proceso digital accesible y vulnerable; no hiere directamente tejido sin soporte digital. |
| `dig_sobrecarga_logica` | **Sobrecarga lógica** | Activa · Ataque | D informático × 0,83; 55 % base de interrumpir proceso/acción; atributo `INT` | `12 + ceil(0,32 × (L−1))` | 2 | Solo objetivo con proceso susceptible; la interrupción requiere comprobar compatibilidad y resistencia. |
| `dig_depuracion` | **Depuración** | Activa · Apoyo | C × 0,90 de integridad digital restaurada **o** elimina 1 alteración informática; atributo `INT` | `11 + ceil(0,30 × (L−1))` | 2 | Aliado/sistema compatible; restauración digital no equivale a curación orgánica. |
| `dig_redundancia` | **Redundancia** | Pasiva · Defensa | Reducción del primer daño informático del combate: min(25, 14 + 0,10 × INT)%; atributo `INT` | 0 (pasiva) | — | Solo primer impacto informático; copia temporal de información crítica. |
| `dig_analisis_protocolos` | **Análisis de protocolos** | Pasiva · Utilidad | Radio: min(4, 1 + ⌊(INT + L)/45⌋) casillas; atributo `INT` | 0 (pasiva) | — | Detecta conexiones e interfaces accesibles, no cualquier red oculta o inaccesible. |

### 3.4. Psíquico

**Identidad:** conciencia, intenciones, percepción, voluntad. No equiparar automáticamente programación con mente susceptible.

| ID estable | Habilidad | Activación / función | Efecto escalable | Coste PM | CD | Condición / precisión importante |
|---|---|---|---|---|---:|---|
| `psi_choque_mental` | **Choque mental** | Activa · Ataque | D psíquico × 1,02; atributo `VOL` | `9 + ceil(0,25 × (L−1))` | 0 | Requiere una conciencia susceptible, incluso si es artificial y verdaderamente consciente. |
| `psi_disonancia` | **Disonancia** | Activa · Ataque | D psíquico × 0,78; 65 % base: precisión −12 puntos porcentuales durante 2 turnos; atributo `VOL` | `12 + ceil(0,28 × (L−1))` | 2 | Solo sobre cognición susceptible; no afecta por defecto a mecanismos sin mente. |
| `psi_sincronia` | **Sincronía** | Activa · Apoyo | Resistencia de aliado al daño psíquico +min(18, 7 + 0,13 × VOL)% durante 2 turnos; atributo `VOL` | `10 + ceil(0,28 × (L−1))` | 2 | Requiere enlace mental interpretable; aplica bonificación defensiva, no curación. |
| `psi_barrera_subconsciente` | **Barrera subconsciente** | Pasiva · Defensa | Reducción del daño psíquico: min(20, 8 + 0,13 × VOL)%; atributo `VOL` | 0 (pasiva) | — | Protege de daño psíquico; otras interferencias mentales pueden exigir defensas específicas. |
| `psi_lectura_intenciones` | **Lectura de intenciones** | Pasiva · Utilidad | Evasión +min(8, 2 + 0,06 × VOL) puntos porcentuales; atributo `VOL` | 0 (pasiva) | — | Solo ataques anticipables de objetivos con mente interpretable. |

### 3.5. Místico

**Identidad:** vínculos sobrenaturales, maldiciones, símbolos, presencia espiritual; no exige conciencia orgánica en su objetivo.

| ID estable | Habilidad | Activación / función | Efecto escalable | Coste PM | CD | Condición / precisión importante |
|---|---|---|---|---|---:|---|
| `mis_manifestacion_arcana` | **Manifestación arcana** | Activa · Ataque | D sobrenatural × 1,00; atributo `VOL` | `11 + ceil(0,27 × (L−1))` | 0 | Objetivo físico o espiritual manifestado y alcanzable; la defensa puede ser RES o VOL según el modo. |
| `mis_marca_funesta` | **Marca funesta** | Activa · Ataque | D × 0,55 inicial; 65 % base de maldición: D × 0,30 por turno durante 3 turnos; atributo `VOL` | `14 + ceil(0,35 × (L−1))` | 2 | Necesita vínculo válido; la maldición no se acumula consigo misma, solo renueva duración. |
| `mis_amparo_espiritual` | **Amparo espiritual** | Pasiva · Apoyo | Probabilidad de recibir maldiciones de aliados cercanos: −min(14, 6 + 0,10 × VOL) puntos porcentuales; atributo `VOL` | 0 (pasiva) | — | Protege a aliados próximos; requiere alcance definido por escena/reglas posteriores. |
| `mis_resonancia_oculta` | **Resonancia oculta** | Pasiva · Utilidad | Radio: min(5, 2 + ⌊(VOL + L)/45⌋) casillas; atributo `VOL` | 0 (pasiva) | — | Detecta fenómenos y vínculos sobrenaturales; no revela automáticamente su interpretación. |
| `mis_anclaje_espiritual` | **Anclaje espiritual** | Pasiva · Defensa | Reducción de riesgo de posesión/desplazamiento: min(23, 10 + 0,15 × VOL) puntos porcentuales; atributo `VOL` | 0 (pasiva) | — | Solo efectos de posesión o desplazamiento sobrenatural de conciencia. |

### 3.6. Detalles de efectos que deben conservarse

- **Secreción cáustica:** probabilidad base `P0=60 %`; si aplica, corrosión `−8 % de RES durante 2 turnos`. Si no hay material susceptible, no se aplica el estado. El impacto y la corrosión pueden ser resultados separados.
- **Sobrecarga lógica:** `P0=55 %` de interrupción de un proceso/acción compatible; `CD=2`.
- **Disonancia:** `P0=65 %` de bajar precisión en **12 puntos porcentuales** durante 2 turnos; `CD=2`.
- **Marca funesta:** `P0=65 %` para aplicar una maldición compatible. Daño inicial `0,55 × D(VOL)`; daño periódico `0,30 × D(VOL)` por turno durante 3 turnos. Para resultados reproducibles, se propone calcular el daño periódico al aplicar el estado y conservar esa instantánea durante sus 3 turnos. **No se acumula consigo misma:** reaplicar renueva duración; reglas de reemplazo entre atacantes, pendiente.
- **Regeneración celular** y **Depuración** comparten forma matemática pero NO curan los mismos soportes: primera repara tejidos, segunda restaura integridad digital o elimina una alteración informática.
- **Blindaje adaptativo:** solo frente a daños consecutivos del mismo tipo; reinicio tras 2 turnos sin ese tipo de daño. La interpretación exacta de «tipo» de daño exige normalizar etiquetas.
- **Redundancia:** solo reduce el primer daño informático del combate, no todos.
- **Sincronía:** reducción de daño psíquico del aliado por 2 turnos; el porcentaje escala con `VOL` del usuario, no con la del receptor.
- **Amparo espiritual:** afecta a aliados cercanos. Distancia exacta/radio de equipo, **pendiente** de la mecánica de posicionamiento.
- **Quimiorrecepción, Autodiagnóstico, Análisis de protocolos y Resonancia oculta:** los radios se miden en casillas en entornos de exploración por cuadrícula; NO implican detección garantizada si no existe un rastro, interfaz o fenómeno susceptible.

## 4. Tabla de pruebas de referencia: niveles 1, 30 y 60

Se emplea **el mismo personaje ficticio de referencia** para todas las naturalezas. Los tres ejemplos son una herramienta matemática, no una clase ni progresión impuesta a todo el bestiario.

| Dato de prueba | Nivel 1 | Nivel 30 | Nivel 60 |
|---|---:|---:|---:|
| Nivel `L` | 1 | 30 | 60 |
| Atributo ofensivo relevante `A` | 15 | 44 | 74 |
| Defensa relevante del objetivo `R` | 13 | 42 | 72 |
| PV del objetivo (`100+10L+5R`) | 175 | 610 | 1.060 |
| PM del atacante (`35+3L+2A`) | 68 | 213 | 363 |
| `D` sin multiplicador (exacto, aprox.) | 52,21 | 135,49 | 192,09 |
| Ataque básico gratuito `0,75 × D`, redondeado | 39 | 102 | 144 |
| `C` sin multiplicador (exacto) | 52,60 | 162,80 | 276,80 |

**Advertencia:** en la fila de PV usamos la defensa de referencia como `RES`. Para un ataque digital, psíquico o místico, el mismo número `R` representa la defensa apropiada del escenario de prueba, aunque en un combate real los atributos defensivos puedan ser diferentes.

### 4.1. Trece habilidades activas: resultado / coste PM

Valores de daño, curación o bonificación **sin críticos, resistencias especiales, vulnerabilidades, estados adicionales ni incompatibilidades**. En los ataques de estado se muestra daño inicial, no daño futuro esperado.

| Naturaleza · habilidad | Nivel 1 | Nivel 30 | Nivel 60 |
|---|---:|---:|---:|
| Biológico · Impulso orgánico | 57 / 7 | 149 / 14 | 211 / 20 |
| Biológico · Secreción cáustica | 43 / 10 | 111 / 18 | 158 / 26 |
| Biológico · Regeneración celular | 45 / 11 | 138 / 21 | 235 / 30 |
| Mecánico · Impacto cinético | 62 / 8 | 160 / 16 | 227 / 23 |
| Mecánico · Proyección de fragmentos | 47 / 9 | 122 / 16 | 173 / 24 |
| Digital · Corrupción de datos | 54 / 8 | 140 / 15 | 198 / 23 |
| Digital · Sobrecarga lógica | 43 / 12 | 112 / 22 | 159 / 31 |
| Digital · Depuración | 47 / 11 | 147 / 20 | 249 / 29 |
| Psíquico · Choque mental | 53 / 9 | 138 / 17 | 196 / 24 |
| Psíquico · Disonancia | 41 / 12 | 106 / 21 | 150 / 29 |
| Psíquico · Sincronía | +8,9 % / 10 | +12,7 % / 19 | +16,6 % / 27 |
| Místico · Manifestación arcana | 52 / 11 | 135 / 19 | 192 / 27 |
| Místico · Marca funesta | 29 / 14 | 75 / 25 | 106 / 35 |

**Comprobación de Marca funesta:**

- Nivel 1: daño inicial 29 + tres aplicaciones de 16 = **77** PV máximos si la maldición entra y dura completamente.
- Nivel 30: 75 + 3 × 41 = **198**.
- Nivel 60: 106 + 3 × 58 = **280**.
- **No equivalen a daño garantizado:** existe tirada de estado, resistencia, compatibilidad y posibilidad de terminar el combate antes de 3 turnos.

### 4.2. Doce habilidades pasivas: magnitud calculada

En las tablas, `pp` = **puntos porcentuales**, `%` = porcentaje relativo de reducción/bonificación. Para **Homeostasis** y **Blindaje adaptativo**, se utiliza la `RES` de referencia 13/42/72, mientras que las demás pasivas usan su atributo correspondiente 15/44/74. Esto corrige la inconsistencia aritmética de la tabla preliminar.

| Naturaleza · habilidad | Nivel 1 | Nivel 30 | Nivel 60 |
|---|---:|---:|---:|
| Biológico · Homeostasis | 10,6 % | 16,4 % | 22,4 % |
| Biológico · Quimiorrecepción | 2 cas. | 3 cas. | 4 cas. |
| Mecánico · Calibración | +3,9 pp | +5,6 pp | +7,4 pp |
| Mecánico · Blindaje adaptativo | 9,2 % | 14,1 % | 19,2 % |
| Mecánico · Autodiagnóstico | 1 cas. | 2 cas. | 3 cas. |
| Digital · Redundancia | 15,5 % | 18,4 % | 21,4 % |
| Digital · Análisis de protocolos | 1 cas. | 2 cas. | 3 cas. |
| Psíquico · Barrera subconsciente | 9,9 % | 13,7 % | 17,6 % |
| Psíquico · Lectura de intenciones | +2,9 pp | +4,6 pp | +6,4 pp |
| Místico · Amparo espiritual | −7,5 pp | −10,4 pp | −13,4 pp |
| Místico · Resonancia oculta | 2 cas. | 3 cas. | 4 cas. |
| Místico · Anclaje espiritual | −12,2 pp | −16,6 pp | −21,1 pp |

### 4.3. Ejemplo resuelto de daño

Para `L=30`, `FUE=44` y `RES` objetivo `=42`:

```text
D = (18 + 2×30 + 2,6×44) × 100/(100+42)
  = (18 + 60 + 114,4) × 100/142
  ≈ 135,4929577
Impulso orgánico = round_half_up(1,10 × D) = 149
Coste = 7 + ceil(0,22 × (30−1)) = 7 + 7 = 14 PM
```

Para un objetivo con `RES=80`, misma fuerza y nivel, el daño baja por defensa: usar `R=80` en la misma fórmula. No crear un multiplicador de daño diferente para cada nivel.

### 4.4. Comprobación del número de ataques necesarios

| Escenario | PV / daño de Impulso orgánico | Impactos enteros para derrotarlo |
|---|---:|---:|
| Nivel 1 | 175 / 57 ≈ 3,07 | **4** |
| Nivel 30 | 610 / 149 ≈ 4,09 | **5** |
| Nivel 60 | 1.060 / 211 ≈ 5,02 | **6** |

La proporción es orientativa: el personaje puede gastar PM, fallar, hacer críticos, curarse o usar otros ataques. **No confundir la proporción continua con el número entero de turnos o golpes.**

## 5. Limitaciones y equilibrio: qué está aprobado y qué no

1. **Efectos de estado:** definen compatibilidad, probabilidades, duración, condiciones de renovación y resistencias; deben evitar cadenas infinitas de interrupción.
2. **Pasivas del mismo grupo:** no sumarlas sin techo. Propuesta: reducción multiplicativa (`1 − producto(1−r_i)`) o usar solo la más fuerte si se solapan; **política definitiva pendiente**.
3. **Asimilación:** una única naturaleza secundaria por personaje o criatura en esta fase. Las habilidades híbridas se definirán por combinación y subtipo; no sustituyen automáticamente a las 25 habilidades base ni deben ser universalmente superiores.
4. **Equipo y afinidad:** podrían añadir modificadores, pero ajustar después de validar los ataques base.
5. **Ataque básico:** referencia gratuita `0,75 × D(FUE)`; es una propuesta técnica. La animación, rango y atributo podrán variar por anatomía y arma. El ataque básico no convierte a todos los personajes en luchadores de melé.
6. **Protagonistas humanos:** naturaleza de origen Biológica, sin poderes intrínsecos exagerados al inicio; las capacidades extraordinarias dependen inicialmente de criaturas y de la tecnología de vinculación.
7. **Digital durante el arranque:** los efectos ambientales e informáticos pueden existir antes que los combates digitales ordinarios; las habilidades digitales ofensivas siguen definidas para etapas posteriores.
8. **Atributos por naturaleza/subtipo, progresión de experiencia, armaduras, precisión/evasión base, resistencias especiales, IA, economía de turnos, crítico, equipo, radios finales, reposición de PM y duración de estados:** quedan pendientes. Este documento no afirma que todo el sistema esté equilibrado de manera definitiva.

## 6. Esquema de implementación sugerido

Separar los datos de habilidades de la lógica de combate. Los identificadores de la tabla son estables para guardar partidas y localización. Estructura orientativa, no contrato irrevocable:

```ts
type Nature = 'biological' | 'mechanical' | 'digital' | 'psychic' | 'mystic';
type Attribute = 'FUE' | 'TEC' | 'INT' | 'VOL' | 'RES' | 'AGI';
type SkillKind = 'attack' | 'support' | 'defense' | 'utility';
type SkillMode = 'active' | 'passive';

type Formula =
  | { kind: 'damage'; multiplier: number; scaling: Attribute; defense: Attribute }
  | { kind: 'restore'; multiplier: number; scaling: Attribute; medium: 'tissue' | 'digital' }
  | { kind: 'status'; baseChance: number; scaling: Attribute; turns: number; statusId: string }
  | { kind: 'passive'; effectId: string; expressionId: string };

interface NatureSkill {
  id: string;
  nature: Nature;
  displayName: string;
  mode: SkillMode;
  role: SkillKind;
  cost?: { base: number; perLevel: number };
  cooldownTurns?: number;
  formulas: Formula[];
  requirementTags: string[];
  notes?: string;
}

// Los ataques con estado llevan dos o más componentes:
// p. ej. damage + status; cada uno se evalúa por compatibilidad.
// En místico, el objetivo/efecto concreto fija si la defensa es RES o VOL.
```

**Servicios a implementar (sugeridos):**

- `getSkillAvailability(entity, skillId, context)`: aprendizaje, requisitos anatómicos, equipamiento, momento de la historia, coste y CD.
- `isCompatible(skillComponent, target, context)`: evaluador por propiedades del objetivo, soporte y estado; devuelve motivo de invalidez.
- `resolveSkill(skillId, caster, target, state, rng)`: cálculo de daño/curación/efectos sin mutar tablas de definición.
- `calculateSkillCost(skill, level)`: fórmula de coste con `ceil`.
- `getExplorationReveals(entity, mapState)`: pasivas de percepción aplicadas a la cuadrícula.

## 7. Pruebas unitarias mínimas / criterios de aceptación

- [ ] Hay **25 IDs** únicos: 5 por naturaleza, 10 ataques, 5 apoyos y 10 libres; 13 activos y 12 pasivos.
- [ ] `CostePM(L)` da los costes de la tabla para niveles 1, 30 y 60, incluidos valores no enteros de `k`.
- [ ] `D(30,44,42)` ≈ `135,4929577`; `Impulso orgánico` = `149` y `14 PM`.
- [ ] Secreción cáustica no aplica corrosión sobre materiales inmunes; sí permite daño sobre materiales susceptibles aunque sean mecánicos.
- [ ] Infecciones orgánicas de subtipos futuros no afectan automáticamente a máquinas sin tejido vivo.
- [ ] Ataques digitales requieren proceso digital vulnerable; sin él no se fuerza un combate arbitrario.
- [ ] Regeneración celular no restaura una máquina pura; Depuración no cura por defecto heridas biológicas.
- [ ] Choque mental y Disonancia requieren conciencia susceptible; la conciencia artificial compatible puede ser objetivo.
- [ ] Marca funesta no acumula varias copias del mismo estado; los ticks se redondean por aplicación.
- [ ] Los pasivos con alcance no revelan objetivos si sus requisitos de detección no están presentes.
- [ ] Las cifras de la tabla de pasivas se calculan con los atributos declarados, no con una variable genérica errónea.
- [ ] No aparecen habilidades sobrenaturales gratuitas en protagonistas humanos al comenzar el juego.
- [ ] Los efectos por soporte (biológico/mecánico/digital/psíquico/místico) no se implementan como un triángulo arbitrario de ventajas universales.

## 8. Pendientes específicos para la siguiente iteración

- [PENDIENTE] Atributos, curvas y límites máximos definitivos; número de turnos y economía real de recursos.
- [PENDIENTE] Cómo se equipan habilidades, qué partes del catálogo son aprendibles por especie y cuál es el coste de desbloquearlas.
- [PENDIENTE] Reglas de alcance y posicionamiento en el sistema de combates de primera persona por casillas.
- [PENDIENTE] Rango base de precisión, estados de inmunidad/semirresistencia y parámetros de bosses.
- [PENDIENTE] Habilidades de cada subtipo y árboles nuevos de asimilación.
- [PENDIENTE] Desbloqueo concreto de ataques digitales a medida que el grupo aprende a interactuar con entidades digitales.
- [PENDIENTE] Simulación de enfrentamientos completos; los valores propuestos aún requieren test de balance.

**Resumen para desarrollo:** definir las habilidades como datos, comprobar compatibilidad antes del daño/estado, aplicar una misma matemática común y usar estas tablas como fixtures de prueba. Los protagonistas comienzan limitados; los subtipos y la asimilación aportarán más complejidad posteriormente.
