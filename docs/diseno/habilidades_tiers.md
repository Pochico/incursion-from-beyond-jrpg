# Catálogo de habilidades y balance (borrador para Claude)

> **Control de versiones:** la columna «Efecto original visible» ya está sincronizada con la tabla editada por el usuario (24-11-2026); solo cambiaba la redacción, no las reglas. Si el usuario vuelve a editarla, sus cambios tienen prioridad: actualizar primero nombre y efecto de cada ID y después reevaluar tier y números si cambia su potencia. «Apunte» = nota manuscrita; «Propuesto» = efecto propuesto. No modificar esos efectos sin consentimiento del diseñador.

## 1. Objetivo y convenciones

- Sistema JRPG/dungeon crawler con combate por turnos, **niveles de personaje de 1 a 60**, 5 naturalezas, sin clases fijas. Las habilidades se vinculan a naturaleza, subtipo y, cuando proceda, a asimilación.
- **Tier 1–5 = potencia/impacto**, no rareza, rango del personaje ni requisito automático de desbloqueo. Tier 1 es de bajo impacto y tier 5 es de mayor impacto. El balance considera daño, utilidad, área, invulnerabilidad, control y riesgo.
- Nomenclatura de los apuntes: **PSY=Psíquico**, **ARQ=Místico/Arcano**, **BIO=Biológico**, **CYBER=Digital/Cyber**, **MECH=Mecánico**. Estas son etiquetas de habilidad, no clases.
- PV y PM son enteros; los porcentajes se aplican a los valores indicados (10% de PVmáx significa sobre los máximos, no sobre los actuales). `T` significa turnos completos del **objetivo afectado**, salvo especificación contraria. `CD` es enfriamiento en turnos del portador, sin contar el turno de uso.
- Los números propuestos en esta versión están **pendientes de test de combate**. No son datos extraídos de la fotografía ni una decisión definitiva del usuario.

## 2. Escalado matemático aplicable a TODOS los niveles 1–60

Definir las siguientes funciones (sin depender de librerías externas de balance):

```text
L              = nivel del personaje que ejecuta (entero, 1..60)
A              = atributo ofensivo pertinente al tipo de habilidad
R              = resistencia pertinente del objetivo
PV_MAX         = 100 + 10*L + 5*RES
PM_MAX         = 35 + 3*L + 2*max(INT, VOL)
B(L,A)         = 18 + 2*L + 2.6*A               # potencia bruta común
H(L,A)         = 18 + 1.6*L + 2.2*A             # curación común
COSTO(L,c,k)   = c + ceil(k*(L-1))              # coste PM, salvo fijo
DAÑO(L,A,R,m)  = round_half_up(B(L,A)*m*100/(100+max(0,R)))
CURA(L,A,m)    = round_half_up(H(L,A)*m)
P_ESTADO       = si compatible: clamp(P0 + 0.35*(A-R) - E, 5, 90)
                 si incompatible: 0
```

- `m` es el multiplicador de la tabla. Para daño persistente, calcular **cada tick** con el multiplicador indicado; se aplica la defensa y el redondeo una vez por tick.
- **Atributo por defecto**: PSY `VOL`; ARQ `max(INT,VOL)`; BIO ofensiva `FUE`, BIO regeneración `RES`; CYBER `TEC`; MECH física `FUE` y MECH electrónica `TEC`. Si un subtipo cambia esto, debe quedar declarado en los datos.
- **Resistencia según ataque**: física/biológica contra `RES`, cibernética contra `TEC`, psíquica contra `VOL`, arcana contra `VOL` o `RES` según su naturaleza. Declarar el atributo defensivo en los datos de cada habilidad.
- `E` es la resistencia extra a estados (puntos porcentuales); la compatibilidad se comprueba **antes** de la probabilidad. No hay envenenamiento en máquina pura ni hackeo a organismos sin electrónica. La corrosión sí puede actuar sobre metal y tejido susceptible.
- La regeneración/curación se limita a PV_MAX; recuperar PM se limita a PM_MAX. `round_half_up` redondea mitades hacia arriba, evitando diferencias entre motores.
- **Ejemplos de las tablas**: para hacer comparables los niveles, se usa un personaje de referencia con `A_ref(L) = 10 + floor((L-1)/2)`. Los daños mostrados son **brutos**, antes de defensa, y son ilustrativos; en combate se usan atributos reales, resistencias y efectos activos.
- **Escalado por nivel**: las expresiones son exactas para **cada nivel entero de 1 a 60**; la columna `N1 · N20 · N40 · N60` son cuatro puntos de comprobación, no los únicos niveles posibles. No interpolar entre ellos: **evaluar siempre la fórmula**.
- **Tier y coste**: todas las habilidades consumen una acción, salvo que un efecto indique explícitamente lo contrario; no permitir utilizar habilidades en CD, sin PM, sin objetivo válido o sin compatibilidad. La habilidad de Meditación cuesta 0 PM, pero consume turno y tiene CD.
- Los efectos de control no se acumulan sin límite: reaplicar renueva duración; las reducciones de daño tienen un máximo del 70% combinado, la esquiva efectiva un máximo del 85% y las potencias de daño combinadas un máximo de ×2.5.
- Los efectos continuos se resuelven al final del turno del objetivo. Nunca generar un nuevo evento de reparto de daño por recibir daño compartido de Empatía.

## 3. Tablas de habilidades por tipo

**Lectura**: Cada tabla tiene `Valor escalable` con la **fórmula completa por nivel**, y `Muestras` con resultados de nivel 1/20/40/60. `Coste PM` se recalcula según el nivel. `CD` es fijo. `P0` es probabilidad base, modulada por la fórmula global de estados.

### PSY — Psíquico

| ID | Habilidad | Tier | Efecto original visible | Reglas implementables | Valor escalable (L=1..60) | Muestras N1 / N20 / N40 / N60 | Coste PM | CD | Origen |
|:--|:--|:--:|:--|:--|:--|:--|:--|:--:|:--|
| PSY-01 | Proyección astral | 5 | Se proyecta astralmente y no recibe daño. | Se vuelve intangible hasta el final de su próximo turno: daño recibido = 0; no puede usar ataques físicos ni interaccionar físicamente. Durante la proyección puede ejecutar una habilidad PSY al 60% de potencia. No puede combinarse con Excorporar ni mantener otra invulnerabilidad. | Inmunidad: `100%`; PSY lanzada: `×0,60`; duración: `hasta final del siguiente turno`. | **1:** 0 daño recibido; PSY ×0,60<br>**20:** 0 daño recibido; PSY ×0,60<br>**40:** 0 daño recibido; PSY ×0,60<br>**60:** 0 daño recibido; PSY ×0,60 | `36 + ceil(0.60×(L−1))`<br>**N1 / N20 / N40 / N60:** 36 / 48 / 60 / 72 | 6 | Apunte |
| PSY-02 | Manifestar | 4 | Potencia una habilidad. | La próxima habilidad de daño o curación ejecutada antes de acabar el siguiente turno recibe un multiplicador adicional. No afecta a invulnerabilidad, turnos, probabilidades ni costes, y no se acumula consigo misma. | Bono: `30 + floor((L−1)/5)×2` %. | **1:** +30%<br>**20:** +36%<br>**40:** +44%<br>**60:** +52% | `23 + ceil(0.33×(L−1))`<br>**N1 / N20 / N40 / N60:** 23 / 30 / 36 / 43 | 4 | Apunte |
| PSY-03 | Meditación | 2 | Recupera PM. | Gasta su acción y recupera PM; la recuperación no puede exceder PM máximos. | PM recuperados: `ceil(10 + 0,55L + 0,60VOL)`. | **1:** +17 PM<br>**20:** +33 PM<br>**40:** +50 PM<br>**60:** +67 PM | `0`<br>**N1 / N20 / N40 / N60:** 0 / 0 / 0 / 0 | 3 | Apunte |
| PSY-04 | Adivinación | 1 | Realiza una acción aleatoria durante 1 turno. | Al lanzar, en su siguiente turno ejecuta una acción válida seleccionada aleatoriamente de las disponibles, con objetivo legal aleatorio. No añade acciones ni elude costes adicionales. | `1` acción aleatoria en el turno siguiente; sin crecimiento directo. | **1:** 1 acción aleatoria<br>**20:** 1 acción aleatoria<br>**40:** 1 acción aleatoria<br>**60:** 1 acción aleatoria | `5 + ceil(0.06×(L−1))`<br>**N1 / N20 / N40 / N60:** 5 / 7 / 8 / 9 | 2 | Apunte |
| PSY-05 | Euforia | 1 | +1 a todos los atributos durante 1 turno. | Incrementa en +1 cada atributo numérico básico (FUE, RES, INT, VOL, TEC) durante 1 turno. No altera permanentemente estadísticas. | Bono fijo `+1` a todos los atributos; duración fija `1` turno. | **1:** +1 a atributos; 1T<br>**20:** +1 a atributos; 1T<br>**40:** +1 a atributos; 1T<br>**60:** +1 a atributos; 1T | `6`<br>**N1 / N20 / N40 / N60:** 6 / 6 / 6 / 6 | 2 | Apunte |
| PSY-06 | Empatía | 3 | Reparte el daño recibido por un objetivo entre este y otro. | Vincula dos unidades compatibles durante 2 turnos; el daño final que recibiría una se divide 50%/50% (redondeando y conservando el total) entre ambas. No dobla daño; el daño compartido no se comparte de nuevo, para evitar bucles. | Reparto fijo `50/50`; duración `2` turnos. | **1:** 50/50 durante 2T<br>**20:** 50/50 durante 2T<br>**40:** 50/50 durante 2T<br>**60:** 50/50 durante 2T | `19 + ceil(0.33×(L−1))`<br>**N1 / N20 / N40 / N60:** 19 / 26 / 32 / 39 | 4 | Apunte |
| PSY-07 | Excorporar | 3 | No tiene turno y no recibe daño. | La entidad pierde su siguiente acción completa y queda intangible, sin recibir daño, hasta el final de ese turno perdido. No puede activar otras habilidades mientras está así. | Daño recibido `0` mientras dure; acciones posibles `0`. | **1:** 0 daño; pierde 1 acción<br>**20:** 0 daño; pierde 1 acción<br>**40:** 0 daño; pierde 1 acción<br>**60:** 0 daño; pierde 1 acción | `18 + ceil(0.30×(L−1))`<br>**N1 / N20 / N40 / N60:** 18 / 24 / 30 / 36 | 4 | Apunte |

### ARQ — Arcano / Místico

| ID | Habilidad | Tier | Efecto original visible | Reglas implementables | Valor escalable (L=1..60) | Muestras N1 / N20 / N40 / N60 | Coste PM | CD | Origen |
|:--|:--|:--:|:--|:--|:--|:--|:--|:--:|:--|
| ARQ-01 | Pacto | 3 | Obtiene un beneficio a cambio de aceptar un coste o condición. | Sacrifica 10% de PV máximos al activarse y aumenta su daño infligido y la mitigación de daño recibido durante 3 turnos. No puede causar una muerte automática por coste si queda a 1 PV (regla configurable). | Daño: `+25 + floor((L−1)/10)×2` %; reducción recibida: `15%`; coste de PV: `ceil(0,10×PVmáx)`. | **1:** +25% daño / −15% recibido<br>**20:** +27% daño / −15% recibido<br>**40:** +31% daño / −15% recibido<br>**60:** +35% daño / −15% recibido | `20 + ceil(0.30×(L−1))`<br>**N1 / N20 / N40 / N60:** 20 / 26 / 32 / 38 | 5 | Propuesto |
| ARQ-02 | Dominio | 5 | Crea un área que potencia sus habilidades y debilita a los enemigos. | Zona durante 3 turnos: aliados dentro infligen un 25% más de daño; enemigos dentro infligen un 15% menos. Solo un Dominio activo por bando; el más reciente sustituye al anterior. | Bono aliado `+25%`; penalización enemiga `−15%`; duración `3T`. | **1:** +25% aliados; −15% enemigos; 3T<br>**20:** +25% aliados; −15% enemigos; 3T<br>**40:** +25% aliados; −15% enemigos; 3T<br>**60:** +25% aliados; −15% enemigos; 3T | `43 + ceil(0.60×(L−1))`<br>**N1 / N20 / N40 / N60:** 43 / 55 / 67 / 79 | 7 | Propuesto |
| ARQ-03 | Ascensión | 5 | Aumenta temporalmente su poder a cambio de un consumo elevado de PM. | Aumenta el daño infligido durante 2 turnos. A cambio, recibe un 20% más de daño y las habilidades usadas durante el estado cuestan +20% PM. No acumula con otra Ascensión. | Daño: `+45 + floor((L−1)/10)×2` %; recibido `+20%`; otros costes `×1,20`. | **1:** +45% daño; +20% recibido<br>**20:** +47% daño; +20% recibido<br>**40:** +51% daño; +20% recibido<br>**60:** +55% daño; +20% recibido | `38 + ceil(0.55×(L−1))`<br>**N1 / N20 / N40 / N60:** 38 / 49 / 60 / 71 | 7 | Propuesto |
| ARQ-04 | Sacrificio | 3 | Consume sus propios PV para potenciar una habilidad. | Sacrifica 12% de PV máximos; la próxima habilidad ofensiva recibe un bono de daño si se ejecuta antes de terminar el turno siguiente. Sin acumulación de múltiples sacrificios. | Bono siguiente ataque: `+75 + floor((L−1)/10)×3` %; PV: `ceil(0,12×PVmáx)`. | **1:** +75% próxima habilidad<br>**20:** +78% próxima habilidad<br>**40:** +84% próxima habilidad<br>**60:** +90% próxima habilidad | `13 + ceil(0.22×(L−1))`<br>**N1 / N20 / N40 / N60:** 13 / 18 / 22 / 26 | 4 | Propuesto |
| ARQ-05 | Maldecir | 2 | Aplica una penalización persistente a un enemigo. | Si el estado entra, el enemigo inflige 20% menos de daño durante 3 turnos. Reaplicar refresca duración, no acumula porcentaje. | Penalización `−20%` daño, `3T`; probabilidad base `P0=75%`. | **1:** −20% daño; 3T; P0 75%<br>**20:** −20% daño; 3T; P0 75%<br>**40:** −20% daño; 3T; P0 75%<br>**60:** −20% daño; 3T; P0 75% | `12 + ceil(0.20×(L−1))`<br>**N1 / N20 / N40 / N60:** 12 / 16 / 20 / 24 | 3 | Propuesto |
| ARQ-06 | Bendecir | 2 | Otorga una mejora temporal a un aliado. | El aliado inflige 15% más de daño y recibe 10% menos durante 2 turnos. Reaplicar refresca duración. | Daño `+15%`; daño recibido `−10%`; duración `2T`. | **1:** +15% daño; −10% recibido; 2T<br>**20:** +15% daño; −10% recibido; 2T<br>**40:** +15% daño; −10% recibido; 2T<br>**60:** +15% daño; −10% recibido; 2T | `14 + ceil(0.21×(L−1))`<br>**N1 / N20 / N40 / N60:** 14 / 18 / 23 / 27 | 3 | Propuesto |
| ARQ-07 | Lluvia de sangre | 4 | Inflige daño a varios enemigos y puede aplicar sangrado. | Daño de área a enemigos y posible sangrado de 2 turnos. Sangrado requiere organismo o material compatible; sin tejido vivo ni material sangrable, se aplica solo el impacto. | Impacto por objetivo: `0,70B`; sangrado: `0,20B` al final de cada uno de `2T`; `P0=70%`. | **1:** 32 impacto + 9×2 sangrado<br>**20:** 75 impacto + 21×2 sangrado<br>**40:** 121 impacto + 35×2 sangrado<br>**60:** 168 impacto + 48×2 sangrado | `30 + ceil(0.48×(L−1))`<br>**N1 / N20 / N40 / N60:** 30 / 40 / 49 / 59 | 4 | Propuesto |
| ARQ-08 | Voz celestial | 4 | Cura o elimina estados alterados de los aliados. | Cura a los aliados en combate y elimina un estado negativo compatible de cada uno; no revive a personajes derrotados ni elimina estados no disipables. | Curación por aliado: `0,70H`; elimina `1` estado negativo. | **1:** +29 PV/aliado + limpia 1 estado<br>**20:** +64 PV/aliado + limpia 1 estado<br>**40:** +102 PV/aliado + limpia 1 estado<br>**60:** +140 PV/aliado + limpia 1 estado | `29 + ceil(0.45×(L−1))`<br>**N1 / N20 / N40 / N60:** 29 / 38 / 47 / 56 | 5 | Propuesto |

### BIO — Biológico

| ID | Habilidad | Tier | Efecto original visible | Reglas implementables | Valor escalable (L=1..60) | Muestras N1 / N20 / N40 / N60 | Coste PM | CD | Origen |
|:--|:--|:--:|:--|:--|:--|:--|:--|:--:|:--|
| BIO-01 | Corrosión | 3 | Deteriora la protección del objetivo e inflige daño progresivo. | Ataque corrosivo que daña inmediatamente, reduce 20% la resistencia física del objetivo durante 2 turnos y le aplica un daño residual de 2 turnos. Se aplica a materiales susceptibles, incluidos metales; no a entidades sin materia. | Impacto `0,60B`; daño residual `0,12B`/turno ×2; `RES −20%` por 2T; `P0=80%` para RES−. | **1:** 28 + 6×2; RES −20%<br>**20:** 64 + 13×2; RES −20%<br>**40:** 104 + 21×2; RES −20%<br>**60:** 144 + 29×2; RES −20% | `18 + ceil(0.30×(L−1))`<br>**N1 / N20 / N40 / N60:** 18 / 24 / 30 / 36 | 3 | Propuesto |
| BIO-02 | Aliento tóxico | 3 | Expulsa una nube tóxica que intoxica a los enemigos susceptibles. | Afecta a enemigos de un área: impacto bajo y veneno de 3 turnos. Solo afecta organismos biológicamente susceptibles; máquinas puras o entidades digitales puras no se envenenan. | Impacto `0,30B`; veneno `0,18B`/turno ×3; `P0=70%`. | **1:** 14 + 8×3 veneno<br>**20:** 32 + 19×3 veneno<br>**40:** 52 + 31×3 veneno<br>**60:** 72 + 43×3 veneno | `22 + ceil(0.32×(L−1))`<br>**N1 / N20 / N40 / N60:** 22 / 29 / 35 / 41 | 3 | Propuesto |
| BIO-03 | Puñete | 1 | Realiza un golpe físico contundente que puede aturdir. | Ataque físico a un objetivo, con una probabilidad baja de interrumpir su siguiente acción. Solo contra objetivos físicamente alcanzables. | Daño directo `0,90B`; interrupción `P0=10%` (máximo 1T). | **1:** 41 daño; aturdir P0 10%<br>**20:** 97 daño; aturdir P0 10%<br>**40:** 156 daño; aturdir P0 10%<br>**60:** 215 daño; aturdir P0 10% | `5 + ceil(0.10×(L−1))`<br>**N1 / N20 / N40 / N60:** 5 / 7 / 9 / 11 | 0 | Propuesto |
| BIO-04 | Regeneración celular | 4 | Recupera PV gradualmente durante varios turnos. | Autorregeneración al final de cada uno de los próximos 3 turnos. Requiere tejido vivo; no funciona en unidades puramente mecánicas o digitales. No acumula consigo misma. | Regeneración `0,40H` PV por turno ×3. | **1:** 17 PV/turno ×3<br>**20:** 37 PV/turno ×3<br>**40:** 58 PV/turno ×3<br>**60:** 80 PV/turno ×3 | `23 + ceil(0.38×(L−1))`<br>**N1 / N20 / N40 / N60:** 23 / 31 / 38 / 46 | 5 | Propuesto |
| BIO-05 | Resiliencia | 2 | Reduce el daño recibido y mejora la resistencia a alteraciones. | Durante 2 turnos reduce 20% del daño recibido y concede +15 puntos porcentuales de resistencia ante estados compatibles. | Daño recibido `×0,80`; resistencia a estados `+15 pp` durante `2T`. | **1:** −20% daño; +15 pp resistencia; 2T<br>**20:** −20% daño; +15 pp resistencia; 2T<br>**40:** −20% daño; +15 pp resistencia; 2T<br>**60:** −20% daño; +15 pp resistencia; 2T | `12 + ceil(0.20×(L−1))`<br>**N1 / N20 / N40 / N60:** 12 / 16 / 20 / 24 | 3 | Propuesto |
| BIO-06 | Improvisación ofensiva | 2 | Adapta su cuerpo o utiliza material orgánico cercano para crear un ataque improvisado. | Ataca adaptando su cuerpo o usando material orgánico cercano. **Solo la usan seres de naturaleza BIO (humanos incluidos)**, por el libre albedrío de los seres vivos comunes (decisión del usuario, 24-11-2026); el resto de naturalezas no. | Daño directo `1,15B`; sangrado `P0=20%` por `1T` (`0,12B`). | **1:** 53 impacto; 6 sangrado opcional<br>**20:** 124 impacto; 13 sangrado opcional<br>**40:** 199 impacto; 21 sangrado opcional<br>**60:** 275 impacto; 29 sangrado opcional | `15 + ceil(0.24×(L−1))`<br>**N1 / N20 / N40 / N60:** 15 / 20 / 25 / 30 | 2 | Propuesto |

### CYBER — Cyber / Digital

| ID | Habilidad | Tier | Efecto original visible | Reglas implementables | Valor escalable (L=1..60) | Muestras N1 / N20 / N40 / N60 | Coste PM | CD | Origen |
|:--|:--|:--:|:--|:--|:--|:--|:--|:--:|:--|
| CYBER-01 | Explosión de bolsillo | 3 | Provoca una explosión localizada mediante un dispositivo o carga electrónica. | Explosión física: daño pleno al objetivo principal y daño reducido a los adyacentes. Requiere soporte/dispositivo físico; un ente puramente digital sin hardware no puede usarlo en el mundo real. | Principal `1,15B`; adyacentes `0,45B`. | **1:** 53 principal / 21 adyacentes<br>**20:** 124 principal / 48 adyacentes<br>**40:** 199 principal / 78 adyacentes<br>**60:** 275 principal / 108 adyacentes | `24 + ceil(0.38×(L−1))`<br>**N1 / N20 / N40 / N60:** 24 / 32 / 39 / 47 | 3 | Propuesto |
| CYBER-02 | Deslumbrar | 2 | Emite un destello que reduce la precisión de los enemigos. | Un objetivo con sistema de visión compatible sufre −30% de precisión durante 2 turnos. Los objetivos sin visión quedan inmunes. | Precisión `−30%` durante `2T`; `P0=80%`. | **1:** −30% precisión; 2T; P0 80%<br>**20:** −30% precisión; 2T; P0 80%<br>**40:** −30% precisión; 2T; P0 80%<br>**60:** −30% precisión; 2T; P0 80% | `13 + ceil(0.22×(L−1))`<br>**N1 / N20 / N40 / N60:** 13 / 18 / 22 / 26 | 3 | Propuesto |
| CYBER-03 | Ultrasónico | 3 | Emite un pulso ultrasónico que desorienta a los objetivos susceptibles. | Impacto de área moderado con probabilidad de imponer −20% precisión durante 2 turnos; solo contra receptores acústicos o sensores afectados por ultrasonidos. | Daño en área `0,40B`; precisión `−20%` por `2T`; `P0=70%`. | **1:** 18 área; −20% precisión P0 70%<br>**20:** 43 área; −20% precisión P0 70%<br>**40:** 69 área; −20% precisión P0 70%<br>**60:** 96 área; −20% precisión P0 70% | `19 + ceil(0.29×(L−1))`<br>**N1 / N20 / N40 / N60:** 19 / 25 / 31 / 37 | 3 | Propuesto |
| CYBER-04 | Inutilizar dispositivo | 4 | Desactiva temporalmente un dispositivo o sistema electrónico. | Deshabilita un dispositivo/equipo conectado que sea hackeable y no esté protegido por inmunidad. Un objetivo sin electrónica compatible no puede ser afectado. | Duración: `1T` (L1–39), `2T` (L40–60); `P0=55%`; modificador TEC–TEC rival. | **1:** 1T desactivado; P0 55%<br>**20:** 1T desactivado; P0 55%<br>**40:** 2T desactivado; P0 55%<br>**60:** 2T desactivado; P0 55% | `29 + ceil(0.45×(L−1))`<br>**N1 / N20 / N40 / N60:** 29 / 38 / 47 / 56 | 5 | Propuesto |
| CYBER-05 | Robo de datos | 2 | Extrae información del objetivo y revela sus capacidades o debilidades. | Revela resistencias y una vulnerabilidad; la siguiente habilidad ofensiva contra ese enemigo recibe +10% daño durante 2 turnos. Exige información digital accesible. | Revelación y bono al siguiente ataque `+10%`, vigencia `2T`; `P0=85%`. | **1:** +10% siguiente ataque; 2T; P0 85%<br>**20:** +10% siguiente ataque; 2T; P0 85%<br>**40:** +10% siguiente ataque; 2T; P0 85%<br>**60:** +10% siguiente ataque; 2T; P0 85% | `12 + ceil(0.18×(L−1))`<br>**N1 / N20 / N40 / N60:** 12 / 16 / 20 / 23 | 2 | Propuesto |

### MECH — Mecánico

| ID | Habilidad | Tier | Efecto original visible | Reglas implementables | Valor escalable (L=1..60) | Muestras N1 / N20 / N40 / N60 | Coste PM | CD | Origen |
|:--|:--|:--:|:--|:--|:--|:--|:--|:--:|:--|
| MECH-01 | Sobrecarga | 4 | Aumenta temporalmente la potencia de sus sistemas a riesgo de sobrecalentarse. | Aumenta el daño mecánico 2 turnos; al terminar pierde 6% de PV máximos por calor/recoil (sin generar reacción en cadena). No acumula con otra Sobrecarga. | Daño: `+35 + floor((L−1)/10)×3` % durante `2T`; recarga térmica `−6% PVmáx`. | **1:** +35% daño; −6% PVmáx<br>**20:** +38% daño; −6% PVmáx<br>**40:** +44% daño; −6% PVmáx<br>**60:** +50% daño; −6% PVmáx | `25 + ceil(0.35×(L−1))`<br>**N1 / N20 / N40 / N60:** 25 / 32 / 39 / 46 | 5 | Propuesto |
| MECH-02 | Latigazo de cable | 2 | Golpea a distancia con un cable y puede inmovilizar al objetivo. | Ataque físico a alcance corto/medio; si supera resistencia del objetivo, lo inmoviliza 1 turno sin impedir habilidades no dependientes de desplazamiento. | Daño `0,85B`; inmovilizar `P0=55%` durante `1T`. | **1:** 39 daño; inmovilizar P0 55%<br>**20:** 91 daño; inmovilizar P0 55%<br>**40:** 147 daño; inmovilizar P0 55%<br>**60:** 203 daño; inmovilizar P0 55% | `11 + ceil(0.18×(L−1))`<br>**N1 / N20 / N40 / N60:** 11 / 15 / 19 / 22 | 2 | Propuesto |
| MECH-03 | Servopatada | 2 | Ejecuta una patada mecánica que puede desplazar al enemigo. | Daño físico en melé y posible empuje de una casilla si la celda siguiente está libre. Contra objetivos inmóviles o anclados no hay empuje. | Daño `1,10B`; empujar `1` casilla con `P0=40%`. | **1:** 51 daño; empuje P0 40%<br>**20:** 118 daño; empuje P0 40%<br>**40:** 191 daño; empuje P0 40%<br>**60:** 263 daño; empuje P0 40% | `13 + ceil(0.20×(L−1))`<br>**N1 / N20 / N40 / N60:** 13 / 17 / 21 / 25 | 2 | Propuesto |
| MECH-04 | Chispazo | 1 | Produce una descarga eléctrica de corto alcance que puede interrumpir una acción. | Daño eléctrico a un objetivo alcanzable con sistema susceptible a electricidad; una interrupción, si entra, anula solo la siguiente acción. | Daño `0,65B`; interrupción `P0=15%` durante `1T`. | **1:** 30 daño; interrumpir P0 15%<br>**20:** 70 daño; interrumpir P0 15%<br>**40:** 113 daño; interrumpir P0 15%<br>**60:** 156 daño; interrumpir P0 15% | `7 + ceil(0.11×(L−1))`<br>**N1 / N20 / N40 / N60:** 7 / 10 / 12 / 14 | 1 | Propuesto |
| MECH-05 | Reset | 3 | Reinicia sus sistemas y elimina ciertas penalizaciones o fallos. | Gasta la acción para eliminar estados negativos purgables de origen tecnológico; no repara daños físicos ni cura PV. No elimina efectos orgánicos o arcanos que no dependan de electrónica. | Elimina `1` estado (L1–30), `2` estados (L31–60). | **1:** limpia 1 estado(s)<br>**20:** limpia 1 estado(s)<br>**40:** limpia 2 estado(s)<br>**60:** limpia 2 estado(s) | `22 + ceil(0.33×(L−1))`<br>**N1 / N20 / N40 / N60:** 22 / 29 / 35 / 42 | 4 | Propuesto |
| MECH-06 | Camuflaje óptico | 4 | Reduce temporalmente su visibilidad y dificulta que los enemigos lo seleccionen. | Durante 2 turnos aumenta la probabilidad de esquiva frente a ataques que dependen de visión; realizar un ataque rompe el camuflaje. No protege de ataques de área ni sensores compatibles. | Esquiva adicional `+50 + floor((L−1)/10)×3` pp (esquiva final limitada al `85%`); duración `2T`. | **1:** +50 pp esquiva (máx 85%)<br>**20:** +53 pp esquiva (máx 85%)<br>**40:** +59 pp esquiva (máx 85%)<br>**60:** +65 pp esquiva (máx 85%) | `32 + ceil(0.40×(L−1))`<br>**N1 / N20 / N40 / N60:** 32 / 40 / 48 / 56 | 5 | Propuesto |

## 4. Instrucciones explícitas para Claude (implementación)

### A. No inventar ni sobrescribir decisiones del usuario

1. Tomar este archivo como **propuesta de balance**, no como verdad cerrada. Los cambios que el usuario haya hecho a mano en la tabla interactiva prevalecen sobre cualquier fila de este documento. Solicitar/consumir esa versión sincronizada antes de reemplazar efectos.
2. Conservar los **32 identificadores estables** (`PSY-01` a `MECH-06`), nombres originales y los cinco grupos. Si se corrige un nombre, migrar por ID y no perder datos.
3. No crear clases nuevas por estas etiquetas. Respetar cinco naturalezas y compatibilidades con asimilación secundaria (máximo una naturaleza adicional inicialmente).
4. No forzar un «triángulo elemental» de ventajas: evaluar capacidades por **material, soporte físico, tejido, sensores, conexión y defensas**.

### B. Estructura de datos y cálculo

Representar cada habilidad como un recurso o registro declarativo (por ejemplo `Resource` de Godot 4 con `id`, `name`, `nature`, `subtype_tags`, `tier`, `targeting`, `damage_kind`, `attribute`, `defense_attribute`, `multiplier`, `dot_multiplier`, `duration`, `initial_pm_cost`, `pm_cost_per_level`, `cooldown`, `status_base_chance`, `compatibility_tags`, `effect_operations`, `version`).

En lugar de escribir 60 valores fijos por habilidad, **calcular el valor exacto para L = 1..60**, usando las fórmulas de la sección 2. Si el motor necesita una tabla, precalcularla y almacenarla en caché; usar esos resultados como fuente numérica, **sin interpolación**. El tier no multiplica por sí mismo el daño: su potencia ya está reflejada en los coeficientes, utilidad y costes asignados.

Para efectos diferentes de daño directo, `effect_operations` debe soportar operaciones como `damage`, `damage_over_time`, `heal`, `heal_over_time`, `modify_stat`, `modify_damage`, `modify_accuracy`, `damage_split`, `grant_immunity`, `lose_action`, `disable_device`, `reveal_data`, `cleanse_status`, `knockback`, `recover_pm` y `self_damage`. No deducir todo de una cadena de texto de descripción.

**Orden de resolución recomendado**:

1. Validar actor vivo y capaz, CD, PM, objetivo y compatibilidad.
2. Reservar PM y ejecutar costes propios (PV, riesgos).
3. Calcular atributos ofensivos, multiplicadores de habilidad y bonificaciones activas (con límites de acumulación).
4. Resolver daño y curación directos, defensa y redondeo.
5. Si hay estado alterado, calcular probabilidad condicionada a compatibilidad y aplicar/renovar duración.
6. Procesar efectos de fin de turno y costes secundarios; actualizar CD y registro del combate.
7. Registrar eventos legibles para UI y depuración.

### C. Pruebas obligatorias antes de integrar

- Comprobar **L=1, 20, 40 y 60** de todas las habilidades contra los ejemplos de estas tablas, y también **todos los niveles intermedios** (1..60) para coste y escalado.
- Probar con `A=10` y `R=0`, después con defensas reales para confirmar que el daño **baja al aumentar R**.
- Verificar que PSY-05 **sigue concediendo exactamente +1** durante 1 turno: no aumentar ese +1 al subir de nivel.
- Verificar que un BIO-02 no envenena a una máquina pura, que CYBER-04 no desactiva un organismo sin electrónica y que BIO-01 sí puede corroer metal susceptible.
- Verificar que PSY-06 conserva exactamente el daño total (por ejemplo, 31 puntos pasan a 16 + 15) y no crea bucles de reparto.
- Verificar que PSY-01 y PSY-07 no pueden generar invulnerabilidad permanente por alternancia o acumulación de CD.
- Verificar que un efecto de daño por tiempo no se acumula ilimitadamente, que las curas no superan PV_MAX y que Meditación no supera PM_MAX.
- Verificar que un nivel 1 no utiliza un coste por encima de PM_MAX sin posibilidad prevista de mejora de estadísticas.
- Verificar que los efectos que dependen de una celda (empuje) o un dispositivo son inválidos si no existe un destino/dispositivo válido.

### D. Balance y ajustes iterativos

- Usar combates simulados contra enemigos de igual nivel y defensa de referencia. Comparar daño por acción, daño por PM, número de turnos para derrotar, supervivencia, control, curación, área y frecuencia real de activación de estados.
- Si una habilidad tier 1 supera sistemáticamente a una tier 4 **en el mismo papel y contexto**, revisar CD, coste, restricciones y escalado. La especialización situacional puede justificar excepciones.
- Priorizar cambios en valores de datos, **no en lógica del motor**. Mantener los cambios versionados y registrar motivo y resultados de pruebas.

## 5. Pendiente antes de tomarlo como versión final

**Tabla del usuario sincronizada** (24-11-2026): sin cambios de reglas. Queda pendiente el test de combate de los números.
