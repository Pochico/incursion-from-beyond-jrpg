# sistema de naturalezas y asimilación, parte 1

> **Documento de diseño funcional y técnico para implementar en un JRPG / dungeon crawler.**  
> **Destinatario:** Claude u otro asistente de desarrollo.  
> **Estado:** especificación de los acuerdos actuales. No convertir las ideas pendientes en reglas definitivas sin validación.

## 0. Instrucciones de lectura para implementar

Este documento distingue tres niveles de certeza:

- **[DEFINIDO]** Decisión tomada para el diseño actual. Debe respetarse.
- **[PROPUESTA TÉCNICA]** Forma sugerida de implementarlo sin imponer decisiones adicionales de diseño.
- **[PENDIENTE]** Aspecto deliberadamente abierto. No inventar valores, fórmulas, resultados garantizados ni restricciones narrativas como si fueran decisiones aprobadas.

**Prioridad:** construir una arquitectura extensible con el menor número posible de sistemas independientes. Esta es la **parte 1**, centrada en naturalezas, subtipos, asimilación y su relación con habilidades, percepción y vínculos. No es la especificación completa del combate, la progresión ni la IA.

---

## 1. Visión y principios

El juego combina JRPG, dungeon crawler y exploración de un mundo cotidiano atravesado por entidades digitales, orgánicas, mecánicas, psíquicas y místicas. Referencias creativas: *Shin Megami Tensei*, *Persona*, *Digimon* y cyberpunk. Las referencias orientan el tono, no obligan a copiar sus tablas de tipos o sistemas.

### Principios obligatorios

1. **[DEFINIDO] Cinco naturalezas**, con subtipos diferenciados.
2. **[DEFINIDO] No hay clases fijas de combate** del tipo guerrero/mago/tirador, ni una correspondencia obligatoria entre naturaleza y alcance (melé/distancia).
3. **[DEFINIDO] Cada naturaleza aporta propiedades, atributos y habilidades generales; cada subtipo aporta especialización y habilidades más concretas.** Algunas habilidades pueden compartirse o parecerse entre subtipos.
4. **[DEFINIDO] Armas y habilidades determinan si una acción es cuerpo a cuerpo, a distancia, de apoyo, etc.** La naturaleza no impone ese estilo.
5. **[DEFINIDO] Un personaje o criatura puede tener una sola naturaleza secundaria por asimilación.** No hay triple naturaleza ni cadenas de asimilaciones simultáneas en esta fase.
6. **[DEFINIDO] La asimilación es acumulativa:** parte de una entidad con naturaleza de origen e incorpora una segunda. Las proporciones pueden variar e incluso invertirse hasta que predomine la naturaleza asimilada.
7. **[DEFINIDO] Asimilar debe abrir posibilidades específicas de la combinación**, no limitarse a copiar y pegar dos árboles de habilidades independientes.
8. **[DEFINIDO] La compatibilidad de una habilidad depende de cómo actúa y de qué está compuesto el objetivo**, no solo de un triángulo simple de debilidades.
9. **[DEFINIDO] La asimilación puede afectar percepción, respuestas, relaciones y decisiones de personajes**, llegando potencialmente al abandono del grupo o la hostilidad.
10. **[DEFINIDO] Una fusión puede salir bien o mal.** Su resultado no está garantizado por la proporción deseada ni debe quedar fijado automáticamente por el jugador.

**No añadir por defecto:** barras nuevas de «identidad» o «estabilidad», seis roles tradicionales, múltiples asimilaciones por criatura, docenas de elementos de daño, porcentajes umbral obligatorios ni un sistema de éxito aleatorio complejo. Si alguno llegara a ser necesario, deberá aprobarse en una fase posterior.

---

## 2. Las cinco naturalezas

| Identificador sugerido | Naturaleza | Núcleo de funcionamiento | Especialidad temática (no una clase de combate) |
|---|---|---|---|
| `biological` | **Biológico** | Vida, tejidos, metabolismo, organismos y adaptación. | Regeneración, alteraciones orgánicas, adaptación. |
| `mechanical` | **Mecánico** | Materia artificial, construcción, piezas, estructuras y funcionamiento físico. | Blindaje, reparación, módulos, mecanismos. |
| `digital` | **Digital** | Información, programación, procesamiento y redes. | Intrusión, manipulación de procesos, duplicación de datos. |
| `psychic` | **Psíquico** | Conciencia, emociones, percepción y fenómenos mentales. | Influencia mental, ilusiones, percepción. |
| `mystic` | **Místico** | Espíritus, creencias, símbolos, mitos y fenómenos sobrenaturales. | Rituales, pactos, manifestaciones y anclajes sobrenaturales. |

**[DEFINIDO]** No son rangos de poder ni estilos visuales cerrados. Puede existir una entidad débil o extraordinariamente poderosa de cualquiera de las cinco naturalezas. Una criatura visualmente biomecánica no requiere una sexta naturaleza propia: puede tener origen Biológico y asimilación Mecánica, o viceversa. Lo biomecánico **no es el método ni la categoría exclusiva de hibridación**; la asimilación puede combinar **cualquier par** de naturalezas diferentes.

### 2.1. Naturaleza de origen frente a predominio actual

Son conceptos distintos:

- **Origen:** naturaleza con la que empezó la entidad. Forma parte de su trayectoria y no se reescribe simplemente al asimilar otra.
- **Secundaria:** naturaleza incorporada, si la hay.
- **Predominio actual:** proporción relativa entre origen y secundaria tras el proceso; puede pasar de minoritaria a mayoritaria.

Ejemplo: un humano de origen Biológico puede llegar a predominar Digitalmente. Su origen sigue siendo Biológico a efectos de historia y procedencia, aunque sus capacidades y percepción hayan cambiado. **[PENDIENTE]** Cómo afecta un predominio extremo a la conservación, bloqueo o sustitución de habilidades antiguas.

---

## 3. Subtipos: conservar profundidad sin crear más naturalezas

**[DEFINIDO]** Se conservan los subtipos explorados en el diseño previo, redistribuyendo los que antes pertenecían a la categoría «Residual» (que deja de ser una sexta naturaleza). Además, **Biológico → Parasitario** es un ejemplo expresamente importante y debe existir.

**[PROPUESTA DE ORGANIZACIÓN]** Catálogo inicial de **19 subtipos**, sin eliminar los anteriores. Las denominaciones y fronteras pueden ajustarse sin cambiar los cinco tipos principales:

| Naturaleza | Subtipos propuestos | Enfoque |
|---|---|---|
| **Biológico** | **Individual**, **Colonia**, **Simbiótico**, **Parasitario** | Organismo autónomo; agrupación orgánica; cooperación entre organismos; explotación/infección de huéspedes. |
| **Mecánico** | **Integrado**, **Modular**, **Enjambre** | Núcleo estructural; piezas intercambiables; muchas unidades coordinadas. |
| **Digital** | **Autónomo**, **Distribuido**, **Parasitario** | Programa independiente; ejecución repartida; software que depende de infiltrarse en otros sistemas. |
| **Psíquico** | **Proyección**, **Colectivo**, **Parasitario** | Manifestación individual; mente colectiva; entidad que se alimenta o depende de otras mentes. |
| **Místico** | **Ancestral**, **Urbano**, **Institucional**, **Territorial**, **Objetual**, **Personal** | Mitos antiguos; leyendas contemporáneas; símbolos de instituciones; entidades ancladas a lugares, objetos o personas. |

> **Aclaración de los antiguos Residuales:** los subtipos **Territorial, Objetual y Personal** se mantienen y se agrupan provisionalmente en Místico, al representar presencias/anclajes sobrenaturales. No eliminarlos. Si se redefine su ontología más adelante, se podrán reubicar. **[PENDIENTE]** Confirmar si su pertenencia definitiva a Místico es satisfactoria.

**Importante para código:** el nombre «Parasitario» se repite en Biológico, Digital y Psíquico, pero son **subtipos distintos**. Usar identificadores compuestos, por ejemplo `biological.parasitic`, `digital.parasitic` y `psychic.parasitic`. No tratarlos como la misma categoría ni asignarles automáticamente idénticas habilidades.

Los subtipos determinan especializaciones mecánicas y temáticas, pero **no bloquean el uso de armas o técnicas comunes**. Un Biológico Parasitario podría disparar un arma; un Digital Autónomo podría luchar físicamente si dispone de un cuerpo apropiado.

---

## 4. Habilidades y atributos: tres fuentes, no clases de combate

### 4.1. Estructura de progresión

**[DEFINIDO]** Una entidad puede obtener habilidades a través de:

1. **Árbol de naturaleza principal:** capacidades intrínsecas y generales disponibles a entidades de esa naturaleza.
2. **Árbol de subtipo:** capacidades más especializadas y características, incluso mayoritariamente exclusivas de ese subtipo.
3. **Árbol de asimilación:** habilidades y cambios específicos de la **combinación entre naturaleza de origen y naturaleza secundaria**, con variaciones contextualizadas por el subtipo.

El árbol de asimilación no tiene por qué ser una lista enteramente única para cada entidad; debe ser posible compartir habilidades base y extenderlas por combinación para evitar cientos de árboles duplicados. **No convertir la reutilización técnica en homogeneidad jugable.**

### 4.2. Atributos

**[DEFINIDO]** Naturaleza y subtipo influyen en los atributos/capacidades. La asimilación también puede modificarlos.

**[PENDIENTE]** Lista definitiva de atributos, estadísticas concretas, cantidades, crecimiento por nivel, orden de aplicación de modificadores y límites. No codificar valores de balance como definitivos.

### 4.3. Ejemplo: Biológico → Parasitario

- **Naturaleza Biológica:** regeneración, adaptación metabólica, crecimiento de tejido (ideas de habilidades genéricas).
- **Subtipo Parasitario:** infección tisular, drenaje de recursos del huésped, manipulación biológica de organismos compatibles (ideas especializadas).
- **Con asimilación Digital:** infección de protocolo, huésped remoto o transferencia entre sistemas compatibles (ideas de habilidades híbridas).

Los nombres anteriores son **ejemplos de diseño, no un repertorio cerrado ni valores finales**.

### 4.4. Ataques y equipamiento

**[DEFINIDO]** Cuerpo a cuerpo, distancia, área, apoyo, ataque físico, etc., son **propiedades de acciones/armas**, no una taxonomía de clases de personajes. Una misma naturaleza puede usar muchos estilos según su organismo, equipo, sistemas y habilidades aprendidas.

**[PENDIENTE]** Inventario, equipamiento definitivo, costes de PM/PV, limitaciones de armas y reglas de aprendizaje.

---

## 5. Compatibilidad de habilidades con objetivos

Este punto es central: **un efecto solo se aplica si existe un mecanismo compatible**.

Ejemplos:

| Efecto | Organismo biológico | Máquina sin tejido vivo | Entidad digital sin soporte físico expuesto |
|---|---|---|---|
| **Infección orgánica** | Posible si tiene tejido susceptible | No por defecto | No por defecto |
| **Corrosión** | Depende de la sustancia y de su fisiología | Posible si sus materiales son vulnerables | No directamente |
| **Intrusión informática** | Posible solo si dispone de sistemas accesibles | Posible si tiene componentes/sistemas vulnerables | Posible si permite acceso/infiltración |
| **Impacto físico** | Posible | Posible | Solo si hay cuerpo, contenedor o soporte vulnerable |

Un cíborg o criatura asimilada puede tener **más de una superficie de vulnerabilidad**, pero no se debe asumir que todos los efectos de sus dos naturalezas funcionan automáticamente sobre todo su cuerpo.

**[PROPUESTA TÉCNICA]** Las habilidades deberían declarar condiciones sobre características del objetivo (`hasLivingTissue`, `hasAccessibleDigitalSystem`, `hasPhysicalBody`, `materialTags`, etc.). Las entidades exponen estas características según su estado, naturaleza, asimilación y equipamiento. Las condiciones pueden evolucionar con el personaje.

**No diseñar un sistema de ventajas/debilidades por colores o triángulos como sustituto de estas condiciones.** Si más adelante hay afinidades de daño, serían otro aspecto compatible con este modelo.

---

## 6. Asimilación: regla central

### 6.1. Límite

**[DEFINIDO]** Cada entidad tiene:

- **Una naturaleza de origen**, siempre identificable.
- **Cero o una naturaleza secundaria** incorporada mediante asimilación.
- **Una proporción de predominio** entre ambas cuando existe asimilación.

No se permiten tres naturalezas simultáneas en esta fase. Si en el futuro se necesitara reemplazar una secundaria por otra, sus condiciones están **[PENDIENTES]**.

Con cinco naturalezas existen **10 parejas no ordenadas** distintas, o **20 combinaciones dirigidas** si diferenciamos quién es origen y quién es asimilado. La dirección importa: Biológico→Digital y Digital→Biológico **no tienen por qué producir la misma identidad ni el mismo árbol**.

### 6.2. Asimilación acumulativa

**[DEFINIDO]** La naturaleza secundaria se incorpora progresivamente. El predominio puede crecer y eventualmente superar al origen, sin borrar retroactivamente la procedencia del personaje.

Los porcentajes de ejemplo (80/20, 50/50, 20/80) son una **forma expresiva de representar la composición**, no umbrales de comportamiento aprobados. Evitar codificar reglas como «al 70% abandona el grupo» o «al 90% se vuelve enemigo».

### 6.3. Asimilación inversa y fusión

**[DEFINIDO]** Deben contemplarse procesos en los que la combinación pueda favorecer más a una naturaleza o a la otra; de ahí la idea de «asimilación inversa». También se contemplan **fusiones** en las que se intenta influir en cuánto queda de cada entidad/naturaleza.

**Corrección esencial:** **la fusión depende de cómo salga. Puede salir bien o mal**. Elegir o perseguir una proporción **no equivale a garantizar el resultado**. No suponer que el jugador puede imponer una mezcla exacta, conservar siempre ambas conciencias, escoger sin riesgo cuál domina o evitar las consecuencias adversas.

Mantener separados:

- **Intención de la fusión** (lo que se pretende conseguir; puede incluir un predominio deseado).
- **Resultado real** (lo que acaba produciéndose, que puede diferir y ser favorable o desfavorable).

**[PENDIENTE]** Factores que determinan el resultado, probabilidad o reglas del fracaso, límites de las proporciones, qué ocurre con las conciencias y si una fusión puede destruir una identidad, crear otra o fallar sin transformación. **No inventar aún un minijuego, tiradas, recursos o fórmulas de éxito.**

### 6.4. Árbol híbrido

**[DEFINIDO]** Una asimilación abre un conjunto nuevo de capacidades nacido de la interacción entre naturalezas; se puede especializar por subtipo. No se limita a desbloquear dos colecciones completas de habilidades sin conexión temática.

Ejemplo:

- **Biológico Parasitario + Digital**: desarrollo de mecanismos de infiltración/infección aplicables a sistemas digitales compatibles.
- **Biológico Individual + Digital**: podría producir procesamiento perceptivo aumentado o interfaces neuronales, pero no por ello heredar automáticamente el mismo árbol parasitario.

**[PENDIENTE]** Catálogo de habilidades híbridas y reglas precisas de desbloqueo.

---

## 7. Percepción, comportamiento y vínculos

**[DEFINIDO]** La asimilación puede cambiar **cómo un personaje percibe e interpreta el mundo**, no solo sus estadísticas. A su vez, puede alterar sus reacciones, decisiones y afinidad con el protagonista.

### 7.1. Tendencias perceptivas por naturaleza incorporada

Estas son **guías creativas**, no respuestas idénticas para todas las criaturas de una naturaleza:

| Naturaleza incorporada | Nuevas percepciones posibles |
|---|---|
| Biológico | Sensaciones corporales, hambre, dolor, instintos, señales orgánicas. |
| Mecánico | Estructuras, esfuerzo, mecanismos, funcionamiento de objetos. |
| Digital | Información, conexiones, datos, patrones, procesos. |
| Psíquico | Estados mentales, emociones, pensamientos y distorsiones de percepción. |
| Místico | Presencias, símbolos, pactos y fenómenos ocultos. |

Se pueden representar en el **overworld**, en exploración, diálogos, opciones narrativas y reacciones ante el entorno. **[PENDIENTE]** Su presentación visual concreta y el alcance de cada capacidad.

### 7.2. Consecuencias sobre relaciones

**[DEFINIDO]** La asimilación puede repercutir en:

- Afinidad con el protagonista y posiblemente con otros miembros del grupo.
- Reacciones y preferencias durante diálogos/misiones.
- Aceptación o rechazo de la propia transformación.
- Voluntad de seguir en el grupo.
- Posible abandono, enfrentamiento o conversión en enemigo.

**No son efectos automáticos de un porcentaje.** El contexto, el personaje, sus preferencias y las decisiones narrativas influyen. Una entidad muy asimilada puede seguir siendo leal; otra puede romper con el protagonista por motivos personales antes de alcanzar un predominio elevado de la segunda naturaleza.

**[PROPUESTA TÉCNICA]** Reutilizar el sistema de afinidad/relaciones del juego si existe; representar los cambios perceptivos y narrativos con rasgos, estados o etiquetas activables. **No crear por defecto un medidor separado de «identidad» o «cordura»**. La transformación debe poder consultar estado narrativo y decisiones sin imponer una batería de barras nuevas.

---

## 8. Casos prácticos de referencia

### Caso A: parásito biológico contra una máquina

- Entidad atacante: `biological.parasitic`.
- Acción: infección que requiere tejido vivo.
- Objetivo: robot puramente mecánico sin tejido susceptible.
- **Resultado esperado:** el efecto de infección orgánica no es aplicable. Podría seguir existiendo daño de otro componente del ataque, si lo tiene; eso deberá describirse por separado.
- Si la criatura aprende un ácido corrosivo, dicho ácido **sí puede** afectar materiales de la máquina si son vulnerables.

### Caso B: parásito biológico que asimila Digital

- Origen: Biológico / Parasitario.
- Secundaria: Digital.
- Resultado: desbloquea nuevas formas de infección o infiltración de sistemas **compatibles**.
- La infección orgánica anterior no se convierte automáticamente en infección informática contra cualquier objetivo; hacen falta habilidades y condiciones específicas.

### Caso C: humano cuyo predominio pasa de Biológico a Digital

- El origen permanece registrado como Biológico.
- Las capacidades y percepciones pueden cambiar conforme aumenta la asimilación.
- Sus relaciones y decisiones pueden evolucionar, pero **no hay hostilidad automática** al cruzar un número.

### Caso D: fusión inversa intentada

- Se intenta una fusión que favorezca la naturaleza secundaria.
- El resultado real puede coincidir, desviarse o fracasar; sus detalles aún no están definidos.
- **No implementar «selector de 80/20 con resultado garantizado»** ni definir por anticipado cuál conciencia sobrevive.

---

## 9. Esquema de implementación sugerido

**[PROPUESTA TÉCNICA]** Separar **datos de catálogo** de **estado mutable de una entidad** y **resolución de interacciones**. Se muestra un esquema orientativo en TypeScript, no una API final ni una definición de reglas de balance.

```ts
type NatureId =
  | 'biological'
  | 'mechanical'
  | 'digital'
  | 'psychic'
  | 'mystic';

// Los subtipos están cualificados por naturaleza: 'biological.parasitic', etc.
type SubtypeId = string;
type SkillId = string;

type SkillSource = 'nature' | 'subtype' | 'assimilation' | 'equipment' | 'other';

interface NatureDefinition {
  id: NatureId;
  name: string;
  subtypeIds: SubtypeId[];
  intrinsicSkillIds: SkillId[];
  // Perfiles/efectos de atributo y rasgos: esquema definitivo pendiente.
}

interface SubtypeDefinition {
  id: SubtypeId;
  natureId: NatureId;
  skillIds: SkillId[];
}

interface AssimilationState {
  secondaryNatureId: NatureId;
  // Representación interna provisional. 0..1; sin umbrales fijados.
  secondaryShare: number;
  // Detalles de la fuente secundaria / subtipo, cuando sean relevantes.
  sourceSubtypeId?: SubtypeId;
  // Referencia opcional al resultado narrativo de la asimilación/fusión.
  outcomeId?: string;
}

interface EntityNatureState {
  originNatureId: NatureId;
  originSubtypeId: SubtypeId;
  assimilation?: AssimilationState; // máximo una secundaria
}

interface SkillDefinition {
  id: SkillId;
  sources: SkillSource[];
  // Requisitos de uso y de aplicación sobre objetivos se evalúan aparte.
  prerequisites?: string[];
  targetRequirements?: string[];
  effects: string[];
}

interface FusionAttempt {
  // Qué se pretende obtener; no es el resultado garantizado.
  intendedSecondaryShare?: number;
  participants: string[];
}

interface FusionResolution {
  // Determinado por reglas todavía por diseñar.
  actualAssimilation?: AssimilationState;
  outcomeId: string;
}
```

Este esquema **no determina** qué estadísticas hay, qué habilidades se conceden, las condiciones del éxito o el desenlace de una conciencia. Solo da puntos de extensión para añadir esas decisiones más adelante.

### 9.1. Separación de responsabilidades

- **Catálogo de naturalezas/subtipos:** datos inmutables, localizables y versionables.
- **Estado de entidad:** origen, subtipo y una posible secundaria con su predominio actual.
- **Progresión:** resuelve qué nodos de habilidad están disponibles por naturaleza, subtipo y combinación dirigida. No equivale automáticamente a aprenderlos/equiparlos.
- **Resolución de habilidades:** comprueba requisitos, medios, soportes y susceptibilidades de cada objetivo.
- **Narrativa/relaciones:** consume cambios de asimilación y resultados de fusión para disparar escenas, diálogos o cambios de afinidad; no crea automáticamente antagonismo.
- **Interfaz:** lee el estado resuelto y presenta la naturaleza, el subtipo, la asimilación y las ramas disponibles sin duplicar lógica.

### 9.2. Validaciones mínimas

1. El subtipo de origen pertenece a la naturaleza de origen.
2. La secundaria, si existe, es **distinta** de la naturaleza de origen.
3. Nunca se almacena más de una naturaleza secundaria activa.
4. La proporción se mantiene dentro del rango permitido por su representación, pero **el rango no define resultados narrativos**.
5. El identificador de subtipo no es ambiguo entre naturalezas.
6. Una habilidad consulta compatibilidad con el objetivo; no confundir naturaleza con inmunidad universal.
7. La fusión distingue *intención* y *resultado efectivo*.
8. Se conserva la procedencia histórica aunque cambie el predominio.

---

## 10. Criterios de aceptación para una primera implementación

Un prototipo cumple esta **parte 1** cuando:

- [ ] Registra las **cinco naturalezas** y permite subtipos asociados sin forzar números iguales.
- [ ] Incluye provisionalmente todos los subtipos enumerados, incluido `biological.parasitic` y los antiguos Residuales reagrupados.
- [ ] Una entidad puede tener naturaleza y subtipo de origen, y **como máximo una** naturaleza secundaria.
- [ ] El predominio secundario puede variar sin sobrescribir el origen histórico.
- [ ] Existe una vía de consulta para habilidades de naturaleza, subtipo y asimilación, extensible por combinación dirigida.
- [ ] Un ataque de infección orgánica no afecta por defecto a un robot sin tejido vivo.
- [ ] Una acción corrosiva puede afectar a material compatible independientemente del origen biológico del atacante.
- [ ] El uso de armas/alcances no depende de «clase de combate» ni está predeterminado por naturaleza.
- [ ] Un evento de asimilación puede informar a exploración/diálogo/afinidad sin que la afinidad cambie automáticamente por un porcentaje.
- [ ] Una tentativa de fusión y su resolución son cosas diferentes: existe la posibilidad de resultado favorable o desfavorable, **sin inventar todavía su algoritmo**.
- [ ] Las decisiones pendientes permanecen configurables o sin implementar, en vez de cerrarse con constantes arbitrarias.

---

## 11. Decisiones pendientes para siguientes partes

**No son bloqueantes para diseñar el modelo inicial de datos:**

1. Listado final y posibles ajustes de nombres/fronteras de los subtipos, especialmente la ubicación de los antiguos Residuales.
2. Atributos numéricos y fórmulas de cálculo de estadísticas.
3. Reglas concretas de adquisición, coste y combinación de habilidades.
4. Diseño exacto de cada árbol híbrido y condiciones de desbloqueo.
5. Método de resolución de fusiones, riesgos, fallos y consecuencias de cada posible resultado.
6. Qué permanece o se transforma de las conciencias participantes y de las habilidades existentes.
7. Cómo se expresa en la interfaz el predominio de naturalezas y los cambios perceptivos.
8. Cómo se vinculan eventos concretos de asimilación con decisiones de personajes, relaciones y posibles abandonos.
9. Si y cómo se puede reemplazar una naturaleza secundaria previamente asimilada.

### Resumen de una frase para Claude

**Implementar un sistema dirigido por datos de 5 naturalezas y sus subtipos, con habilidades/atributos intrínsecos, un máximo de una asimilación secundaria de predominio variable, árboles híbridos por combinación, efectos condicionados por compatibilidad real del objetivo, cambios narrativos posibles pero no automáticos y fusiones con resultado incierto (favorable o desfavorable), evitando añadir clases fijas o subsistemas innecesarios.**
