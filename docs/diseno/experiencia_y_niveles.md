# Experiencia y niveles

Sistema de progresión de Ren, los compañeros y las criaturas. Complementa
`habilidades_1.md` y `habilidades_tiers.md`, que ya definen que **todo el combate
se calcula por fórmula para el nivel exacto (1–60)**: PV, PM, daño, curación,
costes y valores escalables. Este documento añade **cómo se sube de nivel** y
**a qué nivel aparecen las criaturas**.

Leyenda: **[DEFINIDO]** decidido · **[PROPUESTA]** implementado con valores
provisionales, pendiente de validar · **[PENDIENTE]** sin implementar.

Código: fórmulas y constantes en `src/data/progression_db.gd` (`ProgressionDB`);
nivel y EXP guardados en `GameState.levels`; reparto en `GameState.grant_xp`.

---

## 1. Principios

1. **[DEFINIDO]** Niveles 1–60. Todos empiezan en el nivel 1.
2. **[DEFINIDO]** El nivel lo es todo: no hay puntos que repartir. Al subir de
   nivel, las fórmulas existentes dan más PV, PM, daño, curación y efectos, y
   las habilidades cuestan más PM (coste `C0 + ceil(k·(L−1))`).
3. **[PROPUESTA]** La experiencia es personal: cada personaje lleva la suya.
4. **[PROPUESTA]** Nadie se queda atrás: quien no participa recibe una parte.
5. **[PROPUESTA]** Las criaturas no copian el nivel del grupo: su nivel depende
   de **dónde** aparecen. Así, volver a zonas fáciles da menos y adentrarse
   compensa.

## 2. Quién sube de nivel

| Quién | Cómo | Estado |
|---|---|---|
| Ren | EXP propia | [PROPUESTA] |
| Kenji, Shiori, Akane, Rika (`CharacterDB.COMPANIONS`) | EXP propia; si no participan, el 50 % (`BENCH_SHARE`) | [PROPUESTA] |
| Yuna, madres, profesora… | No combaten: sin nivel | [DEFINIDO] (hoy) |
| Criaturas | Sin EXP: su nivel lo pone la zona (sección 6) | [PROPUESTA] |

Los compañeros que no luchan con Ren se llevan la mitad. Así, el que te toque al
azar en la mazmorra no estará muy por debajo del resto.

## 3. Curva de experiencia — [PROPUESTA]

EXP para pasar del nivel `L` al `L+1`:

```
EXP(L) = 3·L² + 30·L + 27
```

| Nivel | EXP para el siguiente | Combates aprox.* |
|---|---|---|
| 1 → 2 | 60 | 2 |
| 2 → 3 | 99 | 3 |
| 5 → 6 | 252 | 4 |
| 10 → 11 | 627 | 5 |
| 20 → 21 | 1.827 | 8 |
| 30 → 31 | 3.627 | 11 |
| 59 → 60 | 12.240 | 20 |
| **Total 1 → 60** | **265.323** | |

\* Contra criaturas de tu mismo nivel (sección 4). Al principio se sube rápido
y, más adelante, cada nivel cuesta más, pero sin muros. En el nivel 60 la EXP
deja de contar.

## 4. Cómo se gana experiencia

### 4.1 Combate — [PROPUESTA]

Solo al **ganar**. Huir, rendirse o perder no da nada.

```
EXP = (20 + 10 × nivel de la criatura) × factor de nivel × extras
factor de nivel = clamp(1 + 0,15 × (nivel criatura − nivel medio del grupo), 0,2, 2,0)
```

| Extra | Multiplicador | Para qué |
|---|---|---|
| Jefe (`combat.boss` en la ficha, hoy el Tiranosaurio, o `boss` en la cosa del mapa) | ×1,5 | Premiar los combates difíciles |
| Duelo con una persona (Kenji, Rika…) | ×0,5 | Entrenar enseña, pero menos que una amenaza real |

Ejemplos:

| Situación | EXP |
|---|---|
| Criatura N1, grupo N1 | 30 |
| Criatura N3, grupo N1 (planta 1 de La Torre) | 65 |
| Criatura N1, grupo N5 (volver a lo fácil) | 12 |
| Jefe N7, grupo N5 | 176 |
| Duelo N1 | 15 |

Todos los que luchan reciben la EXP completa, también si han caído; los
compañeros ausentes, el 50 %. En la pantalla de victoria sale «+ ¥ … · + N
EXP» y, debajo, en lima: «¡Ren sube al nivel 3!».

### 4.2 Exploración — [PROPUESTA]

Va para el grupo de la incursión (y el 50 % para el resto). Depende del
**nivel de la zona** (`A` = nivel de las criaturas de la planta):

| Hecho | EXP | Cuándo |
|---|---|---|
| Descubrir un pasadizo (pared falsa o pared que resuena) | `15 + 5·A` | Al abrirlo |
| Llegar por primera vez a una planta | `10 + 5·A` | Una vez por planta y partida (no la de entrada) |

Sale en el registro de la mazmorra: «Pasadizo descubierto: + 20 EXP».

### 4.3 [PENDIENTE] Otras fuentes posibles

- Hitos de la historia (fin de capítulo, primera incursión): cantidad fija por
  hito, definida en `chapter_db.gd`.
- Primera victoria contra cada tipo de criatura (bonificación de «bestiario»).
- Misiones del móvil, cuando existan.
- Momentos sociales importantes: **no se propone** darles EXP, porque las
  relaciones tienen su propio sistema. Mezclar ambos empujaría a hablar con la
  gente por interés.

## 5. Qué cambia al subir de nivel

| Qué | Cómo | Estado |
|---|---|---|
| PV y PM máximos | Por fórmula: `PV = 100 + 10L + 5·RES`, `PM = 35 + 3L + 2·max(INT, VOL)` | [DEFINIDO] |
| Atributos | Los de la ficha son los de nivel 1. Cada personaje crece distinto: la referencia (+1 cada 2 niveles, `10 + floor((L−1)/2)` de habilidades_1.md) se multiplica por atributo con `combat.growth` de su ficha (Yuna: FUE y AGI ×1,6, el resto por debajo; Shiori: INT ×1,8; Akane: FUE y RES ×1,4…). **Ren**: equilibrado (11 en todo), sube **2 atributos al azar por nivel** y los que entrene con actividades (`GameState.stat_bonus`) | [DEFINIDO] el criterio (usuario); [PROPUESTA] los números |
| Daño, curación, efectos y costes | Por fórmula con el nivel actual (`SkillDB`) | [DEFINIDO] |
| PV y PM actuales a mitad de incursión | Suben lo mismo que el máximo (no se cura del todo) | [PROPUESTA] |

Con todo a nivel 1, una criatura del mismo nivel mantiene la proporción con el
grupo:

| Nivel | Ren PV / PM / FUE | Oni (×1,5 PV, valores de antes de los tiers) PV / FUE |
|---|---|---|
| 1 | 165 / 58 / 12 | 248 / 11 |
| 10 | 275 / 93 / 16 | 413 / 15 |
| 30 | 525 / 173 / 26 | 788 / 25 |

### 5.1 [PENDIENTE] Crecimiento propio de cada personaje

Ahora todos los atributos suben igual. Propuesta para más adelante: cada ficha
tiene dos atributos «fuertes», que suben +1 cada nivel par e impar
alternativamente (≈ +3 cada 4 niveles en vez de +2), y uno «débil», que sube
cada 3 niveles. Así Kenji crecería en FUE/AGI, Shiori en INT/VOL, etc.

### 5.2 [PENDIENTE] Habilidades por nivel

Hoy cada personaje tiene sus habilidades desde el nivel 1, de cualquier tier.
Propuesta: desbloquear tiers por nivel y aprender las de la ficha al llegar al
nivel indicado.

| Tier | Nivel mínimo |
|---|---|
| 1 | 1 |
| 2 | 8 |
| 3 | 18 |
| 4 | 30 |
| 5 | 45 |

Esto quitaría habilidades que los personajes ya tienen. Hace falta decidir el
plan de aprendizaje de cada uno antes de implementarlo.

## 6. Nivel de las criaturas — [PROPUESTA]

La ficha de cada criatura define sus atributos **a nivel 1**. Su nivel en un
combate depende del sitio:

| Dónde | Nivel | Código |
|---|---|---|
| Mazmorra | `1 + 2 × planta` (planta 0 → 1, 1 → 3, 2 → 5, 3 → 7, 4 → 9; bajo la 0 → 1) | `ProgressionDB.floor_creature_level`, `DungeonMap.creature_level` |
| Calle (incursiones) | El nivel de Ren | `ProgressionDB.street_creature_level` |
| Duelos con personas | El suyo (su EXP propia) | `GameState.level_of` |

Las criaturas escalan con las mismas fórmulas que el grupo: atributos
(`stats_at`), PV con su tier (`CharacterDB.ENEMY_TIERS`: tier 2 ×1,7 PV y +1 a los atributos; jefe ×1,25 más; en grupo, menos PV y daño por criatura con `GROUP_SCALE`), PM, daño y costes. En combates de varias criaturas, la EXP y el dinero son la suma de las de cada una. El dinero de la victoria
(`Battle.reward`) ya dependía de su nivel, así que también crece.

**[PENDIENTE]**
- Nivel por planta editable en el editor de mazmorras, en lugar de la fórmula.
- Variación de ±1 entre criaturas de una misma planta.
- Criaturas «élite» con +2 niveles y más EXP.

## 7. Incursión y extracción — [PROPUESTA]

Salir de la mazmorra fuera de una zona de extracción hace perder **objetos y
dinero**, pero **no la experiencia**: lo aprendido se queda. Si se prefiere un
riesgo mayor, la EXP de la incursión también podría perderse. Es una decisión
abierta.

## 8. Interfaz

- **Victoria**: «+ ¥ … · + N EXP» y las subidas de nivel en lima. Las fichas
  del grupo se actualizan al momento.
- **Mazmorra**: EXP de exploración en el registro.
- **Estado** (Tab): «Nivel» y «Experiencia: X / Y para el nivel N+1».
- **[PENDIENTE]** Barra de EXP en las fichas del grupo y una animación propia
  de subida de nivel (destello y sonido).

## 9. Valores que habrá que revisar en pruebas

Todos son provisionales y están en `ProgressionDB`:
- la curva (`3·L² + 30·L + 27`);
- la EXP de combate (`XP_BASE` 20, `XP_PER_LEVEL` 10, `XP_LEVEL_STEP` 0,15, límites 0,2–2,0);
- los extras de jefe ×1,5 y duelo ×0,5;
- `BENCH_SHARE` 0,5;
- la EXP de exploración;
- el paso de nivel por planta (`FLOOR_LEVEL_STEP` 2).

No se han ajustado por simulación.
