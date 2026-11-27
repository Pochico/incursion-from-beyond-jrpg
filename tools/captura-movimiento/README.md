# Captura de movimiento (web)

Herramienta de *Incursion From Beyond* para sacar animaciones de un vídeo y
ponérselas a un modelo 3D, desde el móvil o el PC, sin instalar nada. Se publica
en `https://pochico.github.io/incursion-from-beyond-jrpg/captura-movimiento/`.

Está basada en [MotionBridge](https://github.com/adonisglobal/motionbridge)
(licencia MIT, ver `LICENSE`), con detección de cuerpo de MediaPipe (Apache 2.0)
y three.js (MIT). Avisos de terceros en `THIRD_PARTY_NOTICES.md` y
`public/third-party/`. El README original está en `docs/MOTIONBRIDGE_README.md`.

## Qué hace

1. **Vídeo**: *Grabar* (abre la cámara del móvil) o *Elegir vídeo* (galería o
   archivo; MP4, MOV, WebM; hasta 60 s y 250 MB). Consejos de grabación en la
   propia página.
2. **Análisis**: MediaPipe Holistic saca el esqueleto 3D del cuerpo en cada
   muestra (12, 24 o 30 por segundo), en un worker y en el propio dispositivo.
   La vista 3D se pausa mientras tanto (en el móvil hace falta toda la CPU).
3. **Personaje**: el humanoide de prueba o un modelo propio `.glb`/`.fbx`.
   - Con esqueleto propio: los huesos se asignan solos por nombre (Mixamo,
     Blender, Bip01…) y se pueden corregir a mano en «Orientación y huesos».
   - **Sin esqueleto** (o con «Rig automático»): se le pone un esqueleto
     humanoide aproximado (`src/character3d/autorig.ts`: proporciones humanas,
     piernas por el centro de cada lado, brazos hacia el punto más lejano a la
     altura del tronco) y pesos de piel por distancia a cada hueso. Se abre el
     modo **Esqueleto**: tocar y arrastrar cada articulación (con simetría
     izquierda/derecha, vistas de frente y de lado); al soltar se rehacen el
     esqueleto y la piel.
4. **Calibración**: momento de referencia, intensidad y «en el sitio».
5. **Exportar**: **GLB animado** (modelo + esqueleto + animación; Godot lo
   importa con su `AnimationPlayer`), BVH (solo esqueleto, para Blender) y JSON
   del movimiento.

El modelo exportado queda escalado a 1,85 de alto, con los huesos del rig
automático llamados como los canónicos (`hips`, `spine`, `chest`, `neck`,
`head`, `upperArmL`…, con puntas `head_end`, `handL_end`…).

## Desarrollo

Requiere Node 24 (funciona con 23). Las dependencias están fijadas en
`package-lock.json` y se instalan **sin scripts** de instalación:

```sh
npm ci --ignore-scripts
npm run setup:assets   # copia el runtime de MediaPipe y baja el modelo (SHA-256 comprobado)
npm run dev            # http://127.0.0.1:5173/
npm test               # pruebas (incluidas las del rig automático)
npm run build
```

`node_modules/`, `dist/`, `public/mediapipe/` y el modelo `.task` no se suben
(ver `.gitignore`). La publicación (`.github/workflows/publicar.yml` de `main`)
los regenera y compila con la ruta de GitHub Pages.

- Para tenerla en local: `tools/herramientas/traer.sh` (en `main`). Para subir
  cambios: `tools/herramientas/llevar.sh captura-movimiento "mensaje"`.
- Al subir a esta rama, `avisar.yml` relanza la publicación.
- Solo se usa el espacio 3D de MotionBridge (`src/app/Workspace.tsx`); el 2D
  sigue en `src/` sin usar.
