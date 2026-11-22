# Visual novel y dungeon crawler 3D en Godot 4

## 1. Qué quiero hacer

Mi juego combina una visual novel con un dungeon crawler que constituye la otra mitad de la experiencia. La referencia para la exploración es Dragon Ruins. Busco pasillos en primera persona con movimiento por casillas y giros de 90°, dentro de escenarios 3D propios. Un pasillo básico tiene pared izquierda, pared derecha, suelo y techo. También quiero poder dibujar cruces, habitaciones y accesos cerrados.

Quiero crear una herramienta interna para dibujar estos mapas a mano y convertirlos automáticamente en escenarios 3D. Más adelante podría añadir generación procedural sobre el mismo formato de mapa.

## 2. Movimiento y cámara

- **W** avanza una casilla y **S** retrocede una casilla en relación con la orientación actual.
- **A y D** giran 90° a izquierda y derecha.
- El jugador tiene una posición lógica `Vector2i` y una orientación cardinal. En 3D la cuadrícula ocupa el plano XZ.
- Antes de dar un paso, el juego comprueba que la casilla de destino existe, que su borde permite cruzar y que el destino carece de obstáculos que bloqueen el paso.
- Un `Tween` interpola el desplazamiento o giro de la cámara. Durante la animación se bloquea la siguiente acción y al terminar la cámara queda alineada con la casilla y orientación de destino.
- Para prototipar, empezaría con casillas de 2 × 2 m y ajustaría medidas, altura de cámara y duración de los pasos al probar el pasillo.

## 3. Cómo se construye un mapa

El editor muestra una cuadrícula cenital. Pintar una casilla crea su suelo y su techo. El generador examina los cuatro bordes de cada casilla y coloca la geometría correspondiente.

| Situación | Resultado |
| --- | --- |
| La casilla vecina está vacía o fuera del mapa | Pared hacia la casilla pintada |
| Ambas casillas son transitables | Paso libre por defecto |
| Marco el borde compartido como muro | Pared que bloquea el paso en ambos sentidos |
| Marco el borde compartido como puerta | Marco y puerta orientados en ese borde |

Un pasillo de una casilla de ancho se cierra automáticamente por los laterales. En una sala de 4 × 4, el generador crea las paredes del perímetro. Los muros interiores y las puertas se añaden a mano. Izquierda y derecha describen lo que ve el jugador. El mapa almacena bordes cardinales y reutiliza las piezas rotándolas.

## 4. Interfaz del editor

- **Plano 2D.** Pincel y borrador para casillas, herramienta de bordes para puertas y muros, y colocación del punto inicial con orientación.
- **Vista 3D.** Previsualiza el escenario, materiales y objetos después de cada edición. Un botón «Probar mapa» inicia la exploración desde el punto indicado.
- **Paleta.** Permite elegir temas, materiales, modelos de puertas y objetos decorativos o interactivos.
- **Inspector.** Permite editar la selección, por ejemplo, la orientación de una papelera o el requisito de apertura de una puerta.
- Para el primer prototipo, se puede reconstruir toda la previsualización tras una edición. Si el mapa crece y eso provoca tirones, se puede actualizar solo la casilla editada y los bordes afectados. El guardado conserva los datos editables del mapa.

## 5. Materiales, texturas y temas

Cada tema define los materiales por defecto de pared, suelo y techo. Por ejemplo, «Estación» podría usar azulejo para paredes, baldosa para suelo y gris mate para techo. Al crear una casilla quedan aplicados los valores del tema. Pintar un material específico sobre una superficie guarda una excepción. Si cambias el tema, se actualizan las superficies que siguen usando el valor por defecto.

- El pincel de suelo o techo actúa sobre casillas. El de pared actúa sobre la **cara** del borde que estás editando.
- Un muro compartido tiene una sola definición lógica y puede tener dos materiales. El lado del andén puede llevar azulejo y el del cuarto técnico, hormigón.
- Las mallas base llevan UV preparadas para mantener una escala uniforme de la textura. Conviene revisar que juntas y patrones casen entre módulos contiguos.
- Varias superficies pueden compartir el mismo recurso de material. El editor cambia qué material tiene asignado cada tramo sin editar globalmente el recurso compartido.
- Tuberías, pilares, rejillas salientes y marcos se pueden añadir como mallas aparte cuando necesiten volumen.

## 6. Puertas

Una puerta se coloca haciendo clic en el borde entre dos casillas transitables. La herramienta sustituye el tramo de pared por una instancia de la escena de puerta (`PackedScene`), con el marco, la hoja y la orientación adecuada.

El editor almacena el modelo, el estado inicial y, si corresponde, la llave o condición de apertura. Durante la partida, el estado actual se guarda por identificador de puerta. Los intentos de cruzar desde cualquiera de los dos lados consultan ese mismo estado. Un control de interacción frente a la puerta puede abrirla si se cumplen sus requisitos. La animación de la hoja representa el cambio y el paso se habilita cuando la puerta deja espacio suficiente.

## 7. Objetos y eventos

Cada entrada de la paleta referencia una escena reutilizable. El editor guarda su identificador, anclaje, orientación y desplazamiento local.

| Anclaje | Ejemplos | Colocación |
| --- | --- | --- |
| Suelo | Cajas, bancos, papeleras | Dentro de una casilla, con giro y desplazamiento local |
| Pared | Carteles, terminales, tuberías | En la cara seleccionada, con altura y posición ajustables |
| Techo | Fluorescentes, rejillas | Sobre la casilla, con un desplazamiento local opcional |

Un objeto puede ser decorativo, ocupar una casilla o reaccionar al interactuar. Una caja grande puede bloquear el paso, una papelera pegada al muro puede dejarlo libre y un terminal puede abrir un diálogo. También puede haber eventos en casillas independientes de los objetos, como iniciar una conversación al entrar por primera vez en una sala.

## 8. Datos del mapa y montaje en Godot

| Datos | Qué guardan |
| --- | --- |
| Mapa | Tema base, tamaño de casilla, punto de inicio y orientación |
| Casillas | Posición, materiales específicos de suelo y techo, posibles eventos |
| Bordes | Tipo especial de borde, materiales por cara y configuración de puerta si procede |
| Objetos | Identificador de instancia, escena, anclaje, transformación y configuración |
| Estado de partida | Puertas modificadas, eventos consumidos, inventario y decisiones |

Cada borde se identifica de forma única, por ejemplo, ordenando las coordenadas de sus dos casillas vecinas. Así una puerta al este de A es la misma puerta que está al oeste de B. Los bordes por defecto se deducen a partir de las casillas existentes. El generador visual y el controlador de movimiento consultan las mismas reglas de paso.

Para la geometría estática planteo dos opciones. **Mallas instanciadas** para simplificar los materiales por cara y el prototipo, o **`GridMap` con `MeshLibrary`** si encaja con las variantes y facilita el montaje. Las puertas y objetos interactivos se instancian como escenas propias en ambos casos. La previsualización y el juego deberían reutilizar el mismo generador.

## 9. Integración con la visual novel

La interfaz de diálogo se reutiliza en ambos modos. En una escena narrativa se muestra sobre una ilustración. Dentro del dungeon crawler, se muestra sobre el escenario 3D con un `CanvasLayer`. Los retratos siguen siendo 2D.

Al iniciar un diálogo se suspende la entrada de exploración. Al terminar, se recupera el control en la misma posición y orientación. Un estado compartido, por ejemplo un `GameState`, conecta inventario, decisiones y progreso con la exploración. Si un personaje me da una tarjeta durante un diálogo, la puerta puede comprobar ese mismo inventario para abrirse después.

## 10. Assets y estilo visual

- Para el prototipo puedo usar un kit gratuito CC0. El [Modular Dungeon Kit de Kenney](https://kenney.nl/assets/modular-dungeon-kit) sirve para probar piezas de mazmorra. La [edición estándar del Modular Sci-Fi MegaKit de Quaternius](https://store.godotengine.org/asset/quaternius/modular-sci-fi-megakit/) sirve para probar pasillos tecnológicos.
- Para el estilo definitivo, puedo adaptar módulos en Blender y exportarlos como `.glb`. Empezaría por pared, suelo, techo, puerta y columna, con medidas y puntos de origen coherentes.
- Busco colores planos y una paleta que encaje con las ilustraciones de la visual novel. La IA puede ayudar con referencias, carteles y texturas. Las piezas que tienen que encajar se preparan con dimensiones controladas.

## 11. Primer prototipo y cómo comprobarlo

1. Dibujar un pasillo en L que desemboque en una sala. Comprobar que el perímetro queda cerrado y que el interior de la sala queda libre.
2. Recorrerlo con W/A/S/D. Comprobar que cada pulsación mueve una casilla o gira 90°, y que los muros bloquean el paso.
3. Pintar un suelo distinto en la sala y cambiar una cara de un muro. Guardar, volver a abrir el mapa y comprobar que se conservan.
4. Colocar una puerta bloqueada, un cartel de pared y una luz de techo. Comprobar su orientación y que la puerta funciona igual por ambos lados.
5. Añadir un personaje o terminal que entregue una tarjeta mediante un diálogo. Comprobar que se bloquean los controles durante la conversación, que se recuperan al cerrarla y que la tarjeta permite cruzar la puerta.

## 12. Preguntas para Claude

1. ¿Qué partes de esta arquitectura simplificarías para hacer el primer prototipo?
2. Con materiales independientes por cara y puertas en bordes, ¿usarías `GridMap`, mallas instanciadas o alguna combinación? ¿En qué momento cambiarías de enfoque?
3. ¿Harías el editor como herramienta dentro del editor de Godot o como escena independiente de edición? ¿Qué opción facilita más la previsualización, el guardado y deshacer cambios?
4. ¿Cómo representarías las casillas y bordes en recursos de Godot para poder editar y guardar mapas sin duplicar datos entre la lógica y el 3D?
5. ¿Qué casos límite probarías en puertas, objetos que bloquean, cambios de mapa y vuelta desde un diálogo?
6. ¿En qué orden lo implementarías? Propón escenas y scripts concretos para el primer prototipo y señala qué decisiones conviene revisar solo cuando haya mapas más grandes.
