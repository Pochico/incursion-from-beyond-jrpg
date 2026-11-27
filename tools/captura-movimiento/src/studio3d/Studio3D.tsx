import { useCallback, useEffect, useMemo, useRef, useState } from 'react';
import { useMotionStudio3D } from './useMotionStudio3D';
import { findMotionFrame } from '../video/video';
import { drawSkeleton } from '../ui/skeleton';
import { chooseReference3D } from '../motion3d/solver';
import { CharacterPreview3D } from '../ui3d/CharacterPreview3D';
import { exportMotionBVH, buildMotion3DJSON } from '../export3d';
import type { SmoothingPreset } from '../tracking/types';
import type { Skeleton3D } from '../motion3d/types';

const labels = { idle: 'Listo para analizar', loading: 'Preparando el modelo de movimiento', analyzing: 'Sacando el movimiento 3D', complete: 'Análisis terminado', cancelled: 'Análisis cancelado', error: 'Análisis detenido' };
function clock(value: number) {
  return `${Math.floor(value / 60).toString().padStart(2,'0')}:${(Math.max(0,value) % 60).toFixed(2).padStart(5,'0')}`;
}
function saveFile(text: string, name: string, type: string) {
  const url = URL.createObjectURL(new Blob([text], { type }));
  const link = document.createElement('a'); link.href = url; link.download = name; link.click();
  window.setTimeout(() => URL.revokeObjectURL(url), 10000);
}

export default function Studio3D({ active }: { active: boolean }) {
  const studio = useMotionStudio3D(active);
  const { source, samples, time, busy, fps, phase } = studio;
  const [referenceTime, setReferenceTime] = useState<number>();
  const [strength, setStrength] = useState(1);
  const [inPlace, setInPlace] = useState(true);
  const [calibration, setCalibration] = useState<'anatomical' | 'reference'>('anatomical');
  const [raw, setRaw] = useState(false);
  const [exportFps, setExportFps] = useState(24);
  const [allowUncertain, setAllowUncertain] = useState(false);
  const [exportNote, setExportNote] = useState('');
  const [exportStart, setExportStart] = useState(0);
  const [exportEnd, setExportEnd] = useState<number>();
  const [targetSkeleton, setTargetSkeleton] = useState<Skeleton3D>();
  const onSkeletonChange = useCallback((skeleton: Skeleton3D | undefined) => setTargetSkeleton(skeleton), []);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const mediaHost = useRef<HTMLDivElement>(null);
  const [mediaWidth, setMediaWidth] = useState(280);
  const motionFrames = useMemo(() => samples.map(sample => sample.motion), [samples]);
  const trackingFrames = useMemo(() => samples.map(sample => sample.tracking), [samples]);
  const lastTracking = trackingFrames[trackingFrames.length - 1];
  const currentTracking = phase === 'complete' && source && lastTracking && time >= lastTracking.timestampMs / 1000 && time <= source.duration
    ? lastTracking : findMotionFrame(trackingFrames, time);
  const current = currentTracking ? samples.find(sample => sample.motion.timestampMs === currentTracking.timestampMs)?.motion : undefined;
  const reference = useMemo(() => referenceTime === undefined ? chooseReference3D(motionFrames) : motionFrames.find(frame => frame.timestampMs === referenceTime), [motionFrames, referenceTime]);
  const percent = studio.expectedSamples ? Math.min(100, Math.round(samples.length / studio.expectedSamples * 100)) : 0;
  const valid = motionFrames.filter(frame => frame.valid).length;
  const review = motionFrames.filter(frame => frame.needsReview || !frame.valid).length;
  const analyzedUntil = source && lastTracking ? Math.min(source.duration, lastTracking.timestampMs / 1000 + 1 / fps) : 0;
  const partial = samples.length > 0 && phase !== 'complete';
  const exportFrames = useMemo(() => motionFrames.filter(frame => frame.timestampMs >= exportStart * 1000 - .001 && (exportEnd === undefined || frame.timestampMs <= exportEnd * 1000 + .001)), [motionFrames, exportStart, exportEnd]);

  useEffect(() => { if (!samples.length) { setReferenceTime(undefined); setExportNote(''); setExportStart(0); setExportEnd(undefined); } }, [samples.length]);
  useEffect(() => { setReferenceTime(undefined); setExportNote(''); setExportStart(0); setExportEnd(undefined); }, [source]);
  useEffect(() => {
    const host = mediaHost.current;
    if (!host) return;
    const observer = new ResizeObserver(([entry]) => setMediaWidth(entry.contentRect.width));
    observer.observe(host); return () => observer.disconnect();
  }, []);
  useEffect(() => {
    const canvas = canvasRef.current;
    const ctx = canvas?.getContext('2d');
    if (canvas && ctx) drawSkeleton(ctx, currentTracking, { width: canvas.width, height: canvas.height, raw, showFace: true, showHands: true });
  }, [currentTracking, raw, source]);

  function exportMotion(format: 'bvh' | 'json') {
    if (!reference || !source) return;
    if (!exportFrames.length) { studio.setError('El tramo elegido no tiene muestras analizadas. Elige un tramo dentro de la captura.'); return; }
    try {
      const options = { frames: exportFrames, reference, fps: exportFps, strength, inPlace, allowUncertain, skeleton: targetSkeleton, calibration };
      const name = source.name.replace(/\.[^.]+$/, '');
      if (format === 'bvh') {
        const result = exportMotionBVH(options);
        saveFile(result.text, `${name}.motion3d.bvh`, 'text/plain');
        setExportNote(`${result.frameCount} fotogramas a ${result.fps} FPS. ${partial ? `Captura parcial: ${clock(result.sourceStartMs / 1000)}–${clock(result.sourceEndMs / 1000)} de ${clock(source.duration)}. ` : ''}${result.warnings.join(' ')}`);
      } else {
        const data = buildMotion3DJSON({ ...options, source: { name: source.name, kind: source.kind, width: source.width, height: source.height, durationSeconds: source.duration, analysisFps: fps, analysisComplete: phase === 'complete', analyzedUntilSeconds: analyzedUntil } });
        saveFile(JSON.stringify(data), `${name}.motion3d.json`, 'application/json');
        setExportNote('Guardado el movimiento 3D con la confianza, la calibración y las coordenadas.');
      }
    } catch (cause) { studio.setError(cause instanceof Error ? cause.message : 'No se ha podido exportar el movimiento.'); }
  }

  return <div className="studio3d">
    <header className="motion3d-header">
      <a className="brand" href={import.meta.env.BASE_URL} aria-label="Captura de movimiento"><i className="brand-slash" /><span>Captura de movimiento</span><span className="motion3d-brand-tag">/// INCURSION FROM BEYOND</span></a>
      <span className="motion3d-local"><i /> TODO EN TU DISPOSITIVO</span>
    </header>
    <main className="motion3d-main">
      <div className="motion3d-heading"><div><div className="eyebrow">VÍDEO → ESQUELETO → MODELO 3D</div><h1>Graba un movimiento y pónselo a un personaje.</h1><p>Graba o elige un vídeo, saca el esqueleto del cuerpo, aplícalo a tu modelo (con su esqueleto o con uno automático) y descárgalo como GLB animado para Godot.</p><a className="motion3d-jump" href="#motion3d-character">Ver el personaje ↓</a></div></div>
      <div className="motion3d-layout">
        <aside className="motion3d-sidebar">
          <section className="motion3d-card">
            <h2><span>01 /</span> Vídeo</h2>
            <input ref={studio.inputRef} className="sr-only" type="file" accept="video/*,.mp4,.webm,.mov,.m4v" aria-label="Elegir un vídeo" disabled={busy || studio.loadingFile} onChange={studio.onFileChange} />
            <input ref={studio.cameraRef} className="sr-only" type="file" accept="video/*" capture="environment" aria-label="Grabar un vídeo con la cámara" disabled={busy || studio.loadingFile} onChange={studio.onFileChange} />
            <div className="motion3d-source-buttons">
              <button className="motion3d-drop motion3d-record" disabled={busy || studio.loadingFile} onClick={() => studio.cameraRef.current?.click()}><span className="motion3d-upload">●</span><strong>Grabar</strong><small>con la cámara del móvil</small></button>
              <button className="motion3d-drop" disabled={busy || studio.loadingFile} onClick={() => studio.inputRef.current?.click()} onDragOver={event => event.preventDefault()} onDrop={event => { event.preventDefault(); const file = event.dataTransfer.files[0]; if (file) void studio.importVideo(file); }}>
                <span className="motion3d-upload">↥</span><strong>{studio.loadingFile ? 'Leyendo…' : source ? 'Cambiar vídeo' : 'Elegir vídeo'}</strong><small>galería o archivo · hasta 60 s</small>
              </button>
            </div>
            <details className="motion3d-tips"><summary>Cómo grabar para que salga bien</summary><ul><li>Una sola persona, con <b>todo el cuerpo</b> dentro del encuadre (de la cabeza a los pies).</li><li>Móvil quieto (apoyado o en trípode), buena luz y ropa que no se confunda con el fondo.</li><li>Empieza 1–2 segundos quieto, de frente y con los brazos en cruz: sirve de referencia.</li><li>Mejor vídeos cortos (5–20 s): el móvil tarda en analizarlos.</li></ul></details>
            <button className="motion3d-demo" disabled={busy || studio.loadingFile} onClick={studio.loadDemo}>Probar con un movimiento de ejemplo</button>
            {source && <><p className="motion3d-filename" title={source.name}>{source.name}</p><div className="motion3d-filemeta"><span>{source.width} × {source.height}</span><span>{clock(source.duration)}</span><span>{(source.size / 1024 / 1024).toFixed(1)} MB</span></div></>}
            <div className="motion3d-source" ref={mediaHost}>
              {source ? <div className="motion3d-source-plane" style={{ width: Math.min(mediaWidth, 240 * source.width / source.height), aspectRatio: `${source.width}/${source.height}` }}>
                {source.kind === 'video' && <video ref={studio.videoRef} src={source.url} muted playsInline preload="auto" onTimeUpdate={event => studio.setTime(event.currentTarget.currentTime)} onSeeked={event => studio.setTime(event.currentTarget.currentTime)} onPlay={() => studio.setPlaying(true)} onPause={() => studio.setPlaying(false)} onEnded={() => studio.setPlaying(false)} onError={() => studio.setError('El navegador no puede leer este vídeo. Prueba con un MP4 (H.264).')} />}
                <canvas ref={canvasRef} width={Math.min(source.width,1280)} height={Math.round(Math.min(source.width,1280) * source.height / source.width)} aria-label="Esqueleto detectado sobre el vídeo" />
              </div> : <div className="motion3d-source-empty">Una persona, el cuerpo entero a la vista<br /><span>es lo que mejor se detecta.</span></div>}
            </div>
            {source?.kind === 'demo' && <p className="motion3d-help">Ejemplo generado: sirve para probar el personaje y la exportación sin analizar un vídeo.</p>}
            <div className="motion3d-source-switch" role="group" aria-label="Esqueleto sobre el vídeo"><button className={!raw ? 'selected' : ''} aria-pressed={!raw} onClick={() => setRaw(false)}>Suavizado</button><button className={raw ? 'selected' : ''} aria-pressed={raw} onClick={() => setRaw(true)}>En bruto</button></div>
          </section>
          <section className="motion3d-card motion3d-settings">
            <h2><span>02 /</span> Análisis</h2>
            <label htmlFor="motion3d-sampling">Muestras por segundo</label>
            <select id="motion3d-sampling" disabled={busy || source?.kind === 'demo'} value={fps} onChange={event => { studio.setFps(Number(event.target.value)); studio.clearAnalysis(); }}><option value={12}>12 (más rápido, para el móvil)</option><option value={24}>24</option><option value={30}>30 (más detalle)</option></select>
            <label htmlFor="motion3d-smoothing">Suavizado del movimiento</label>
            <select id="motion3d-smoothing" disabled={busy || source?.kind === 'demo'} value={studio.smoothing} onChange={event => { studio.setSmoothing(event.target.value as SmoothingPreset); studio.clearAnalysis(); }}><option value="raw">Ninguno</option><option value="light">Poco</option><option value="balanced">Normal</option><option value="smooth">Mucho</option></select>
            <p className="motion3d-help">Las muestras siguen el tiempo del vídeo; no cambian sus fotogramas.</p>
            <label className="motion3d-check motion3d-privacy"><input type="checkbox" checked={studio.acknowledged} disabled={busy} onChange={event => studio.setAcknowledged(event.target.checked)} /><span>Acepto que MediaPipe (Google) envíe métricas de rendimiento y uso. El vídeo no sale del dispositivo. <a href="https://github.com/google-ai-edge/mediapipe#privacy-notice" target="_blank" rel="noreferrer">Aviso de privacidad</a></span></label>
            <button className="motion3d-primary" disabled={!busy && (!source || source.kind === 'demo' || studio.loadingFile || !studio.acknowledged)} onClick={() => busy ? studio.cancel() : void studio.analyze()}>{busy ? 'Cancelar el análisis' : samples.length ? 'Volver a analizar' : 'Analizar el movimiento'} <span>{busy ? '×' : '→'}</span></button>
            <p className="motion3d-help">La primera vez descarga el modelo de detección (unos 14 MB).</p>
          </section>
        </aside>
        <div className="motion3d-editor">
          <div id="motion3d-character"><CharacterPreview3D frame={current ?? null} reference={reference ?? null} frames={exportFrames} analysisFps={exportFps} exportName={source?.name.replace(/\.[^.]+$/, '')} allowUncertain={allowUncertain} calibration={calibration} strength={strength} inPlace={inPlace} active={active} captureBusy={busy} onSkeletonChange={onSkeletonChange} /></div>
          <section className="motion3d-card motion3d-transport" aria-label="Reproducción">
            <div className="motion3d-play-buttons"><button aria-label="Muestra anterior" disabled={!source} onClick={() => studio.seek(time - 1 / fps)}>⏮</button><button className="motion3d-play" aria-label={studio.playing ? 'Pausa' : 'Reproducir'} disabled={!source} onClick={() => void studio.togglePlayback()}>{studio.playing ? 'Ⅱ' : '▶'}</button><button aria-label="Muestra siguiente" disabled={!source} onClick={() => studio.seek(time + 1 / fps)}>⏭</button></div>
            <span>{clock(time)} <i>/ {clock(source?.duration ?? 0)}</i></span>
            <input type="range" aria-label="Posición" min="0" max={source?.duration ?? 1} step=".001" value={time} disabled={!source} onChange={event => studio.seek(Number(event.target.value))} /><small>VÍDEO + PERSONAJE</small>
          </section>
          <section className="motion3d-card motion3d-analysis" role="status" aria-live="polite">
            <div><strong>{source?.kind === 'demo' ? 'Movimiento de ejemplo' : labels[phase]}</strong><p>{samples.length ? `${samples.length} / ${studio.expectedSamples} muestras · ${valid} detectadas · ${review} dudosas${partial ? ` · analizado hasta ${clock(analyzedUntil)}` : ''}` : 'Graba o elige un vídeo y analiza el movimiento.'}</p></div><span>{busy ? `${percent}%` : studio.elapsed ? `${studio.elapsed.toFixed(1)} s` : '—'}</span>
            {(busy || samples.length > 0) && <progress value={percent} max="100" aria-label="Progreso del análisis" />}
          </section>
          {motionFrames.length > 0 && <section className="motion3d-quality" aria-label="Calidad de la detección"><span>CALIDAD DE LA DETECCIÓN</span><div>{Array.from({length:Math.min(80,motionFrames.length)},(_,index) => {
            const frame = motionFrames[Math.floor(index * motionFrames.length / Math.min(80,motionFrames.length))];
            return <button key={index} className={!frame.valid ? 'invalid' : frame.needsReview ? 'review' : 'good'} title={`${clock(frame.timestampMs/1000)} · ${frame.valid ? frame.needsReview ? 'Dudosa' : 'Detectada' : 'Sin detección'}`} aria-label={`Ir a ${clock(frame.timestampMs/1000)}`} onClick={() => studio.seek(frame.timestampMs/1000)} />;
          })}</div></section>}
          <section className="motion3d-card motion3d-calibration">
            <div><h2><span>03 /</span> Calibración</h2><p>{reference ? `Referencia en ${clock(reference.timestampMs / 1000)}${reference.needsReview ? ' · hay articulaciones dudosas' : ''}` : 'Se elige sola una muestra clara.'}</p></div>
            <button disabled={!current?.valid || busy} onClick={() => setReferenceTime(current!.timestampMs)}>Usar este momento de referencia</button>
            <label className="motion3d-calibration-mode" htmlFor="motion3d-calibration-mode">Cómo se aplica<select id="motion3d-calibration-mode" value={calibration} onChange={event => setCalibration(event.target.value as 'anatomical' | 'reference')}><option value="anatomical">Seguir la pose capturada</option><option value="reference">La referencia es la pose de reposo del modelo</option></select></label>
            <p className="motion3d-help motion3d-wide">{calibration === 'anatomical' ? 'Copia la dirección de cada parte del cuerpo. La referencia solo fija hacia dónde mira y desde dónde empieza.' : 'El momento de referencia pasa a ser la pose de reposo del modelo: elige uno en el que estés en T o en A, como el modelo.'}</p>
            <label className="motion3d-strength" htmlFor="motion3d-strength">Intensidad <output>{strength.toFixed(2)}×</output><input id="motion3d-strength" aria-label="Intensidad del movimiento" type="range" min="0" max="2" step=".05" value={strength} onChange={event => setStrength(Number(event.target.value))} /></label>
            <label className="motion3d-check"><input type="checkbox" checked={inPlace} onChange={event => setInPlace(event.target.checked)} /> Sin desplazarse (en el sitio)</label>
            <p className="motion3d-help motion3d-wide">«En el sitio» quita el avance hacia los lados pero conserva subir y bajar (sentadillas, saltos). La profundidad se estima con una sola cámara.</p>
          </section>
          <section className="motion3d-card motion3d-export">
            <div><h2><span>04 /</span> Exportar</h2><p>El <b>GLB animado</b> (en «Personaje 3D») va directo a Godot. El BVH es solo el esqueleto, para Blender.</p></div>
            <label htmlFor="motion3d-export-fps">FPS de salida<select id="motion3d-export-fps" value={exportFps} onChange={event => setExportFps(Number(event.target.value))}><option value={24}>24</option><option value={30}>30</option><option value={60}>60</option></select></label>
            <label className="motion3d-check"><input type="checkbox" checked={allowUncertain} onChange={event => setAllowUncertain(event.target.checked)} /> Incluir muestras dudosas</label>
            <div className="motion3d-export-range"><label htmlFor="motion3d-export-start">Desde (s)<input id="motion3d-export-start" type="number" inputMode="decimal" min="0" max={source?.duration ?? 0} step=".01" value={exportStart} onChange={event => setExportStart(Math.max(0, Number(event.target.value)))} /></label><label htmlFor="motion3d-export-end">Hasta (s)<input id="motion3d-export-end" type="number" inputMode="decimal" min={exportStart} max={source?.duration ?? 0} step=".01" value={exportEnd ?? Number(analyzedUntil.toFixed(3))} onChange={event => setExportEnd(event.target.value === '' ? undefined : Number(event.target.value))} /></label><span>{exportFrames.length} muestras en el tramo</span></div>
            {partial && <p className="motion3d-help motion3d-wide">Captura parcial: solo se exporta lo analizado hasta {clock(analyzedUntil)} de {clock(source?.duration ?? 0)}.</p>}
            <div className="motion3d-export-actions"><button className="motion3d-primary" disabled={!reference || busy} onClick={() => exportMotion('bvh')}>Descargar BVH</button><button disabled={!reference || busy} onClick={() => exportMotion('json')}>Guardar JSON del movimiento</button></div>
            {exportNote && <p className="motion3d-help motion3d-wide" role="status">{exportNote}</p>}
            <p className="motion3d-help motion3d-wide">En Godot: copia el .glb a <code>assets/</code> y se importa con su animación (AnimationPlayer). En Blender: Archivo → Importar → glTF, o Motion Capture (.bvh) con Y arriba y −Z adelante.</p>
          </section>
          {studio.error && <div className="motion3d-error" role="alert"><div><strong>Atención</strong><p>{studio.error}</p></div><button aria-label="Cerrar el aviso" onClick={() => studio.setError('')}>×</button></div>}
        </div>
      </div>
      <div className="motion3d-footer"><span>Basado en <a href="https://github.com/adonisglobal/motionbridge" target="_blank" rel="noreferrer">MotionBridge</a> (MIT) · detección con MediaPipe (Apache 2.0) · <a href="third-party/README.txt" target="_blank" rel="noreferrer">licencias</a></span></div>
    </main>
  </div>;
}
