import { useEffect, useRef, useState } from 'react';
import type { ChangeEvent } from 'react';
import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { HUMANOID_BONES } from '../motion3d/types.ts';
import type { Motion3DFrame, Skeleton3D } from '../motion3d/types.ts';
import { retargetFrame3D } from '../motion3d/retarget.ts';
import {
  BONE_LABELS_3D, applyPose3D, autoMapBones3D, autoRigCharacter3D, captureRest3D, createAutoRig3D, createBuiltinCharacter3D,
  disposeObject3D, loadCharacter3D, resetCharacter3D, validateMapping3D,
} from '../character3d/rig.ts';
import type { BoneMapping3D, CharacterRig3D } from '../character3d/rig.ts';
import { JOINT_LABELS, JOINT_LINKS, JOINT_NAMES, estimateJoints, jointSide, mirrorJoint, setSourceFacing } from '../character3d/autorig.ts';
import type { JointName, Joints3D } from '../character3d/autorig.ts';
import { exportAnimatedGLB3D } from '../character3d/export.ts';
import './character3d.css';

export interface CharacterPreview3DProps {
  frame?: Motion3DFrame | null;
  reference?: Motion3DFrame | null;
  strength: number;
  inPlace: boolean;
  active?: boolean;
  captureBusy?: boolean;
  onSkeletonChange?: (skeleton: Skeleton3D, name: string) => void;
  frames?: readonly Motion3DFrame[];
  analysisFps?: number;
  exportName?: string;
  allowUncertain?: boolean;
  calibration?: 'anatomical' | 'reference';
}

interface JointGizmo {
  group: THREE.Group;
  spheres: Map<JointName, THREE.Mesh>;
  lines: THREE.LineSegments;
}

interface Stage3D {
  renderer: THREE.WebGLRenderer;
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  controls: OrbitControls;
  helper?: THREE.SkeletonHelper;
  rig: CharacterRig3D;
  gizmo?: JointGizmo;
  home: () => void;
  render: () => void;
}

const SIDE_COLORS = { L: '#c6f432', R: '#9b5cf0', C: '#f2f2f2' };

/** Libera solo lo que crea el rig automático: la malla de la piel y el esqueleto. Materiales y texturas son de la fuente. */
function disposeRigShell(root: THREE.Object3D): void {
  root.traverse(object => {
    const mesh = object as THREE.SkinnedMesh;
    if (mesh.isMesh) mesh.geometry.dispose();
    if (mesh.isSkinnedMesh) mesh.skeleton.dispose();
  });
  root.removeFromParent();
}

function cloneJoints(joints: Joints3D): Joints3D {
  return Object.fromEntries(JOINT_NAMES.map(name => [name, joints[name].clone()])) as Joints3D;
}

export function CharacterPreview3D(props: CharacterPreview3DProps) {
  const { frame, reference, active = true, onSkeletonChange } = props;
  const host = useRef<HTMLDivElement>(null);
  const input = useRef<HTMLInputElement>(null);
  const stage = useRef<Stage3D | undefined>(undefined);
  const current = useRef(props);
  const operation = useRef(0);
  const [rig, setRig] = useState<CharacterRig3D>();
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [restMode, setRestMode] = useState(false);
  const [showBones, setShowBones] = useState(false);
  const [showMesh, setShowMesh] = useState(true);
  const [mappingOpen, setMappingOpen] = useState(false);
  const [revision, setRevision] = useState(0);
  const [facing, setFacing] = useState(0);
  const [exporting, setExporting] = useState(false);
  const [editing, setEditing] = useState(false);
  const [mirror, setMirror] = useState(true);
  const [selected, setSelected] = useState<JointName>();
  current.current = props;
  const display = useRef({ restMode, showBones, showMesh, editing });
  display.current = { restMode, showBones, showMesh, editing };
  // El editor de articulaciones trabaja sobre una copia; al soltar, se rehace el rig.
  const edit = useRef({ joints: undefined as Joints3D | undefined, mirror, dragging: undefined as JointName | undefined, plane: new THREE.Plane(), commit: () => {} });
  edit.current.mirror = mirror;

  useEffect(() => {
    const element = host.current;
    if (!element) return;
    let renderer: THREE.WebGLRenderer;
    try { renderer = new THREE.WebGLRenderer({ antialias: true, alpha: false, powerPreference: 'high-performance' }); }
    catch { setError('No se ha podido iniciar WebGL. Activa la aceleración por hardware o prueba otro navegador.'); return; }
    const scene = new THREE.Scene();
    scene.background = new THREE.Color('#141418');
    scene.fog = new THREE.Fog('#141418', 7, 18);
    const camera = new THREE.PerspectiveCamera(36, 1, .01, 100);
    renderer.setPixelRatio(Math.min(window.devicePixelRatio || 1, 1.5));
    renderer.outputColorSpace = THREE.SRGBColorSpace;
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.2;
    renderer.shadowMap.enabled = true;
    renderer.shadowMap.type = THREE.PCFShadowMap;
    renderer.domElement.setAttribute('aria-label', 'Vista 3D del personaje. Arrastra para girar, pellizca o usa la rueda para acercar.');
    renderer.domElement.setAttribute('role', 'img');
    renderer.domElement.style.touchAction = 'none';
    element.appendChild(renderer.domElement);
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enableDamping = true; controls.dampingFactor = .12;
    controls.minDistance = .4; controls.maxDistance = 20;
    controls.maxPolarAngle = Math.PI * .96;
    scene.add(new THREE.HemisphereLight('#efeaff', '#2c2838', 2.2));
    const key = new THREE.DirectionalLight('#ffffff', 3.1);
    key.position.set(3, 5, 4); key.castShadow = true;
    key.shadow.mapSize.set(1024, 1024); key.shadow.normalBias = .03;
    key.shadow.camera.left = -4; key.shadow.camera.right = 4; key.shadow.camera.top = 4; key.shadow.camera.bottom = -4;
    scene.add(key);
    const rim = new THREE.DirectionalLight('#b79cff', 2.3); rim.position.set(-3, 2, -2); scene.add(rim);
    const ground = new THREE.Mesh(new THREE.PlaneGeometry(80, 80), new THREE.MeshStandardMaterial({ color: '#1a1a20', roughness: 1 }));
    ground.rotation.x = -Math.PI / 2; ground.position.y = -.008; ground.receiveShadow = true; scene.add(ground);
    const grid = new THREE.GridHelper(12, 24, '#5d6b2a', '#2c2b36'); grid.position.y = .001; scene.add(grid);
    const builtin = createBuiltinCharacter3D(); scene.add(builtin.root);
    const helper = new THREE.SkeletonHelper(builtin.root); helper.visible = false; scene.add(helper);
    const home = () => { camera.position.set(2.5, 1.8, 4.3); controls.target.set(0, .98, 0); controls.update(); };
    const value: Stage3D = { renderer, scene, camera, controls, rig: builtin, helper, home, render: () => {} };
    stage.current = value; home(); setRig(builtin);
    const resize = () => {
      const width = element.clientWidth, height = element.clientHeight;
      if (!width || !height) return;
      renderer.setSize(width, height, false); camera.aspect = width / height; camera.updateProjectionMatrix();
    };
    const observer = new ResizeObserver(resize); observer.observe(element); resize();
    const render = () => {
      const source = current.current;
      if (source.active === false) return;
      const settings = display.current;
      if (settings.restMode || settings.editing || !source.frame || !source.reference) resetCharacter3D(value.rig);
      else {
        try { applyPose3D(value.rig, retargetFrame3D(source.frame, source.reference, value.rig.skeleton, { strength: source.strength, inPlace: source.inPlace, calibration: source.calibration })); }
        catch { resetCharacter3D(value.rig); }
      }
      value.rig.root.visible = settings.restMode || settings.editing || (!source.reference && !source.frame) || !!source.frame?.valid;
      value.rig.root.traverse(object => { if ((object as THREE.Mesh).isMesh) object.visible = settings.showMesh; });
      if (value.helper) { value.helper.visible = settings.showBones && !settings.editing && value.rig.root.visible; value.helper.updateMatrixWorld(true); }
      if (value.gizmo) value.gizmo.group.visible = settings.editing;
      controls.update(); renderer.render(scene, camera);
    };
    // El bucle solo corre con la pestaña visible.
    value.render = render;
    if (current.current.active !== false && !current.current.captureBusy) renderer.setAnimationLoop(render);
    const contextLost = (event: Event) => { event.preventDefault(); setError('Se ha perdido el contexto 3D. Recarga la página.'); };
    renderer.domElement.addEventListener('webglcontextlost', contextLost);

    // Arrastrar articulaciones: en captura para adelantarse a OrbitControls.
    const raycaster = new THREE.Raycaster();
    const pointer = new THREE.Vector2();
    const toPointer = (event: PointerEvent) => {
      const rect = renderer.domElement.getBoundingClientRect();
      pointer.set((event.clientX - rect.left) / rect.width * 2 - 1, -(event.clientY - rect.top) / rect.height * 2 + 1);
      raycaster.setFromCamera(pointer, camera);
    };
    const pick = (): JointName | undefined => {
      if (!value.gizmo) return undefined;
      // El más cercano al rayo dentro de un radio en pantalla (dedos incluidos).
      let best: JointName | undefined, bestDistance = Infinity;
      const rect = renderer.domElement.getBoundingClientRect();
      const touchRadius = 28 / Math.min(rect.width, rect.height) * 2;
      for (const [name, sphere] of value.gizmo.spheres) {
        const projected = sphere.position.clone().project(camera);
        const distance = Math.hypot(projected.x - pointer.x, (projected.y - pointer.y) * rect.height / rect.width);
        if (distance < touchRadius && distance < bestDistance) { best = name; bestDistance = distance; }
      }
      return best;
    };
    const onDown = (event: PointerEvent) => {
      if (!display.current.editing || !edit.current.joints) return;
      toPointer(event);
      const name = pick();
      if (!name) return;
      controls.enabled = false;
      event.stopPropagation();
      renderer.domElement.setPointerCapture(event.pointerId);
      edit.current.dragging = name;
      const normal = camera.getWorldDirection(new THREE.Vector3());
      edit.current.plane.setFromNormalAndCoplanarPoint(normal, edit.current.joints[name]);
      setSelected(name);
    };
    const onMove = (event: PointerEvent) => {
      const name = edit.current.dragging, joints = edit.current.joints;
      if (!name || !joints) return;
      toPointer(event);
      const hit = raycaster.ray.intersectPlane(edit.current.plane, new THREE.Vector3());
      if (!hit) return;
      if (jointSide(name) === 'C') hit.x = 0;
      joints[name].copy(hit);
      const twin = mirrorJoint(name);
      if (twin && edit.current.mirror) joints[twin].set(-hit.x, hit.y, hit.z);
      updateGizmo(value, joints);
    };
    const onUp = (event: PointerEvent) => {
      if (!edit.current.dragging) return;
      edit.current.dragging = undefined;
      controls.enabled = true;
      if (renderer.domElement.hasPointerCapture(event.pointerId)) renderer.domElement.releasePointerCapture(event.pointerId);
      edit.current.commit();
    };
    renderer.domElement.addEventListener('pointerdown', onDown, { capture: true });
    renderer.domElement.addEventListener('pointermove', onMove);
    renderer.domElement.addEventListener('pointerup', onUp);
    renderer.domElement.addEventListener('pointercancel', onUp);
    return () => {
      operation.current++;
      observer.disconnect(); renderer.setAnimationLoop(null); controls.dispose();
      renderer.domElement.removeEventListener('webglcontextlost', contextLost);
      renderer.domElement.removeEventListener('pointerdown', onDown, { capture: true });
      renderer.domElement.removeEventListener('pointermove', onMove);
      renderer.domElement.removeEventListener('pointerup', onUp);
      renderer.domElement.removeEventListener('pointercancel', onUp);
      if (value.helper) { value.helper.geometry.dispose(); (value.helper.material as THREE.Material).dispose(); scene.remove(value.helper); }
      disposeObject3D(value.rig.root); disposeObject3D(scene);
      renderer.dispose(); renderer.forceContextLoss(); renderer.domElement.remove();
      if (stage.current === value) stage.current = undefined;
    };
  }, []);

  // Durante el análisis la vista 3D se pausa: en el móvil, el análisis necesita toda la CPU.
  const paused = !active || !!props.captureBusy;
  useEffect(() => {
    const value = stage.current;
    if (value) value.renderer.setAnimationLoop(paused ? null : value.render);
  }, [paused]);

  useEffect(() => {
    if (rig) onSkeletonChange?.(rig.skeleton, rig.name);
  }, [rig, revision, onSkeletonChange]);

  // Gizmo de articulaciones: aparece con el editor, sigue al rig automático actual.
  useEffect(() => {
    const value = stage.current;
    if (!value) return;
    if (!editing || !rig?.auto) {
      if (value.gizmo) { removeGizmo(value); }
      edit.current.joints = undefined;
      return;
    }
    edit.current.joints = cloneJoints(rig.auto.joints);
    if (!value.gizmo) value.gizmo = createGizmo(value.scene);
    updateGizmo(value, edit.current.joints);
  }, [editing, rig]);

  useEffect(() => {
    const value = stage.current;
    if (!value?.gizmo) return;
    for (const [name, sphere] of value.gizmo.spheres) sphere.scale.setScalar(name === selected ? 1.6 : 1);
  }, [selected, editing, rig]);

  // Al soltar una articulación: el rig se rehace con las nuevas posiciones.
  edit.current.commit = () => {
    if (!rig?.auto || !edit.current.joints) return;
    swapAutoRig(createAutoRig3D(rig.auto.source, cloneJoints(edit.current.joints)));
  };

  function replaceRig(next: CharacterRig3D, keepView = false) {
    const value = stage.current;
    if (!value) { disposeObject3D(next.root); return; }
    if (value.helper) { value.helper.geometry.dispose(); (value.helper.material as THREE.Material).dispose(); value.scene.remove(value.helper); }
    // Un rig automático usa los materiales del modelo anterior: solo se libera la malla y el esqueleto.
    if (next.auto) disposeRigShell(value.rig.root);
    else disposeObject3D(value.rig.root);
    value.rig = next; value.scene.add(next.root);
    value.helper = new THREE.SkeletonHelper(next.root); value.scene.add(value.helper);
    if (!keepView) { value.home(); setFacing(next.auto?.source.facing ?? 0); setRestMode(false); }
    setRig(next); setError(''); setRevision(number => number + 1);
  }
  function swapAutoRig(next: CharacterRig3D) { replaceRig(next, true); }

  async function importModel(event: ChangeEvent<HTMLInputElement>) {
    const file = event.target.files?.[0]; event.target.value = '';
    if (!file) return;
    const token = ++operation.current; setLoading(true); setError(''); setEditing(false);
    try {
      const next = await loadCharacter3D(file);
      if (token !== operation.current || !stage.current) { disposeObject3D(next.root); return; }
      replaceRig(next);
      // Sin esqueleto propio: se ha puesto uno automático; se abre el editor para revisarlo.
      if (next.auto) { setEditing(true); setSelected(undefined); } else setMappingOpen(true);
    } catch (cause) {
      if (token === operation.current) setError(cause instanceof Error ? cause.message : 'No se ha podido leer el modelo 3D.');
    } finally { if (token === operation.current) setLoading(false); }
  }

  function makeAutoRig() {
    if (!rig?.imported) return;
    try {
      const next = autoRigCharacter3D(rig);
      // Desde un modelo con esqueleto propio, el original ya no se usa.
      replaceRig(next, true);
      setEditing(true); setSelected(undefined);
    } catch (cause) { setError(cause instanceof Error ? cause.message : 'No se ha podido crear el esqueleto automático.'); }
  }

  function reestimate() {
    if (!rig?.auto) return;
    swapAutoRig(createAutoRig3D(rig.auto.source, estimateJoints(rig.auto.source)));
  }

  function updateMapping(mapping: BoneMapping3D) {
    if (!rig) return;
    const issues = validateMapping3D(rig, mapping);
    if (issues.length) { setError(issues.join(' ')); return; }
    resetCharacter3D(rig); rig.mapping = mapping; captureRest3D(rig); setError(''); setRevision(number => number + 1);
  }

  function changeFacing(degrees: number) {
    if (!rig) return;
    if (rig.auto) {
      // El rig automático gira la malla de partida y vuelve a colocar el esqueleto.
      setSourceFacing(rig.auto.source, degrees);
      setFacing(degrees);
      swapAutoRig(createAutoRig3D(rig.auto.source));
      return;
    }
    resetCharacter3D(rig);
    for (const child of rig.root.children) if (!(child as THREE.Bone).isBone && !(child as THREE.Mesh).isMesh) child.rotation.y += (degrees - facing) * Math.PI / 180;
    // El humanoide de serie ya mira a +Z.
    if (!rig.imported) return;
    captureRest3D(rig); setFacing(degrees); setRevision(number => number + 1);
  }

  async function exportModel() {
    if (!rig || !reference || !props.frames?.length || props.captureBusy) return;
    setExporting(true); setError('');
    const token = operation.current;
    try {
      const data = await exportAnimatedGLB3D(rig, { frames: props.frames, reference, fps: props.analysisFps ?? 24,
        strength: props.strength, inPlace: props.inPlace, calibration: props.calibration, allowUncertain: props.allowUncertain, name: props.exportName || 'Captura' });
      if (token !== operation.current || !stage.current) return;
      const url = URL.createObjectURL(new Blob([data], { type: 'model/gltf-binary' }));
      const link = document.createElement('a'); link.href = url;
      link.download = `${(props.exportName || 'captura').replace(/\.[^.]+$/, '').replace(/[^a-zA-Z0-9._-]/g, '_')}.animado.glb`;
      link.click(); setTimeout(() => URL.revokeObjectURL(url), 10000);
    } catch (cause) { if (token === operation.current) setError(cause instanceof Error ? cause.message : 'No se ha podido exportar el personaje animado.'); }
    finally { if (token === operation.current) setExporting(false); }
  }

  const mappedCount = rig ? Object.values(rig.mapping).filter(Boolean).length : 0;
  const missing = rig ? HUMANOID_BONES.filter(name => !rig.mapping[name]) : [];
  const invalid = frame && !frame.valid;
  return <section className="panel rig3d-panel" aria-labelledby="rig3d-title">
    <div className="preview-header">
      <div className="panel-title"><i>02</i><span id="rig3d-title">Personaje 3D</span><span className="rig3d-label">{rig?.name ?? 'Iniciando WebGL'}</span></div>
      <div className="view-switch" role="group" aria-label="Modo de la vista">
        <button className={!restMode && !editing ? 'selected' : ''} aria-pressed={!restMode && !editing} onClick={() => { setRestMode(false); setEditing(false); }}>Movimiento</button>
        <button className={restMode && !editing ? 'selected' : ''} aria-pressed={restMode && !editing} onClick={() => { setRestMode(true); setEditing(false); }}>Reposo</button>
        {rig?.auto && <button className={editing ? 'selected' : ''} aria-pressed={editing} onClick={() => setEditing(value => !value)}>Esqueleto</button>}
      </div>
    </div>
    <div className="rig3d-stage" ref={host}>
      <div className="rig3d-stage-note">{editing ? 'Toca y arrastra una articulación · Gira la vista con el otro dedo libre' : 'Arrastra para girar · Pellizca o rueda para acercar'}</div>
      {editing && selected && <div className="rig3d-joint-name">{JOINT_LABELS[selected]}</div>}
      {props.captureBusy && <div className="rig3d-waiting">Vista en pausa mientras se analiza el vídeo</div>}
      {!editing && (invalid || (!frame && reference)) && !restMode && <div className="rig3d-status" role="status">Sin movimiento detectado en este momento</div>}
      {!editing && !frame && !reference && !restMode && <div className="rig3d-waiting">Modelo listo. Analiza un vídeo para animarlo.</div>}
      {!editing && frame?.valid && frame.needsReview && !restMode && <div className="rig3d-waiting rig3d-review">Algunas partes del cuerpo son dudosas</div>}
    </div>
    {editing && rig?.auto && <div className="rig3d-edit">
      <p>Coloca cada punto en su articulación (de frente y de lado). Al soltar, el esqueleto y la piel se recalculan.</p>
      <div className="rig3d-edit-tools">
        <label><input type="checkbox" checked={mirror} onChange={event => setMirror(event.target.checked)} /> Simetría izq./der.</label>
        <button onClick={reestimate}>Recolocar automáticamente</button>
        <button onClick={() => { const value = stage.current; if (value) { value.camera.position.set(0, 1, 3.6); value.controls.target.set(0, .95, 0); } }}>De frente</button>
        <button onClick={() => { const value = stage.current; if (value) { value.camera.position.set(3.6, 1, 0); value.controls.target.set(0, .95, 0); } }}>De lado</button>
        <button className="rig3d-primary" onClick={() => setEditing(false)}>Listo</button>
      </div>
    </div>}
    <div className="rig3d-tools">
      <input ref={input} className="sr-only" type="file" accept=".glb,.fbx,model/gltf-binary,application/octet-stream" aria-label="Importar personaje 3D" onChange={importModel} />
      <button className="rig3d-primary" disabled={loading || exporting} onClick={() => input.current?.click()}>{loading ? 'Cargando modelo…' : 'Importar GLB / FBX'}</button>
      <button disabled={loading || exporting || !rig?.imported} onClick={makeAutoRig}>{rig?.auto ? 'Rehacer rig automático' : 'Rig automático'}</button>
      <button disabled={loading || exporting || !rig?.imported} onClick={() => { ++operation.current; setEditing(false); replaceRig(createBuiltinCharacter3D()); }}>Humanoide de prueba</button>
      <button onClick={() => stage.current?.home()}>Centrar vista</button>
      <button disabled={loading || exporting || props.captureBusy || !reference || !props.frames?.length} onClick={exportModel}>{exporting ? 'Generando animación…' : 'Descargar GLB animado'}</button>
      <label><input type="checkbox" checked={showMesh} onChange={event => setShowMesh(event.target.checked)} /> Malla</label>
      <label><input type="checkbox" checked={showBones} onChange={event => setShowBones(event.target.checked)} /> Huesos</label>
    </div>
    <div className="rig3d-info" role="status">
      <span>{rig ? `${mappedCount} / ${HUMANOID_BONES.length} huesos del cuerpo asignados${rig.auto ? ' · rig automático' : ''}` : 'Preparando la escena 3D'}</span>
      <span>{editing ? 'Editando el esqueleto' : restMode ? 'Pose de reposo' : reference ? 'Movimiento calibrado' : 'Esperando una referencia'}</span>
    </div>
    {!!props.frames?.length && <div className="rig3d-export-range">Tramo del GLB: {(props.frames[0].timestampMs / 1000).toFixed(2)}–{(props.frames[props.frames.length - 1].timestampMs / 1000).toFixed(2)} s · {props.analysisFps ?? 24} FPS</div>}
    <div className="rig3d-import-note">El GLB animado lleva el modelo, el esqueleto y la animación: se importa tal cual en Godot o Blender. Los modelos no salen de tu dispositivo.{rig?.imported ? ' Comprueba hacia dónde mira el modelo y los huesos antes de exportar.' : ''}</div>
    {error && <div className="rig3d-error" role="alert">{error}<button aria-label="Cerrar el aviso" onClick={() => setError('')}>×</button></div>}
    {rig?.imported && <div className="rig3d-mapping">
      <button className="rig3d-disclosure" aria-expanded={mappingOpen} onClick={() => setMappingOpen(value => !value)}>Orientación y huesos <span>{mappingOpen ? '−' : '+'}</span></button>
      {mappingOpen && <div className="rig3d-mapping-body">
        <div className="rig3d-calibration"><label>El modelo original mira hacia <select value={facing} onChange={event => changeFacing(Number(event.target.value))}><option value={0}>+Z (de frente)</option><option value={180}>−Z (de espaldas)</option><option value={-90}>+X</option><option value={90}>−X</option></select></label>{!rig.auto && <button onClick={() => updateMapping(autoMapBones3D(rig.bones))}>Asignar huesos solo</button>}</div>
        <p>{rig.auto ? 'Con el rig automático los huesos ya están asignados; ajusta las articulaciones en «Esqueleto».' : 'Se respeta la pose de reposo del modelo. Las partes sin asignar se quedan quietas.'}</p>
        {!rig.auto && missing.length > 0 && <p className="rig3d-warning">Sin asignar: {missing.map(name => BONE_LABELS_3D[name]).join(', ')}. Si faltan muchos, prueba «Rig automático».</p>}
        {!rig.auto && <div className="rig3d-map-grid">{HUMANOID_BONES.map(name => <label key={name}>{BONE_LABELS_3D[name]}<select aria-label={`Hueso para ${BONE_LABELS_3D[name]}`} value={rig.mapping[name] ?? ''} onChange={event => { const next = { ...rig.mapping }; if (event.target.value) next[name] = event.target.value; else delete next[name]; updateMapping(next); }}><option value="">Sin asignar</option>{rig.bones.map((bone, index) => <option key={bone.uuid} value={bone.uuid} disabled={Object.entries(rig.mapping).some(([other, id]) => other !== name && id === bone.uuid)}>{bone.name || `Hueso ${index + 1}`}</option>)}</select></label>)}</div>}
      </div>}
    </div>}
  </section>;
}

function createGizmo(scene: THREE.Scene): JointGizmo {
  const group = new THREE.Group();
  group.renderOrder = 10;
  const spheres = new Map<JointName, THREE.Mesh>();
  const geometry = new THREE.SphereGeometry(.022, 16, 10);
  for (const name of JOINT_NAMES) {
    const sphere = new THREE.Mesh(geometry, new THREE.MeshBasicMaterial({ color: SIDE_COLORS[jointSide(name)], depthTest: false, transparent: true, opacity: .95 }));
    sphere.renderOrder = 11;
    group.add(sphere); spheres.set(name, sphere);
  }
  const lineGeometry = new THREE.BufferGeometry();
  lineGeometry.setAttribute('position', new THREE.BufferAttribute(new Float32Array(JOINT_LINKS.length * 6), 3));
  const lines = new THREE.LineSegments(lineGeometry, new THREE.LineBasicMaterial({ color: '#ffffff', depthTest: false, transparent: true, opacity: .7 }));
  lines.renderOrder = 10;
  group.add(lines);
  scene.add(group);
  return { group, spheres, lines };
}

function updateGizmo(value: Stage3D, joints: Joints3D): void {
  const gizmo = value.gizmo;
  if (!gizmo) return;
  for (const [name, sphere] of gizmo.spheres) sphere.position.copy(joints[name]);
  const positions = gizmo.lines.geometry.getAttribute('position') as THREE.BufferAttribute;
  JOINT_LINKS.forEach(([a, b], index) => {
    positions.setXYZ(index * 2, joints[a].x, joints[a].y, joints[a].z);
    positions.setXYZ(index * 2 + 1, joints[b].x, joints[b].y, joints[b].z);
  });
  positions.needsUpdate = true;
  gizmo.lines.geometry.computeBoundingSphere();
}

function removeGizmo(value: Stage3D): void {
  const gizmo = value.gizmo!;
  gizmo.group.traverse(object => {
    const mesh = object as THREE.Mesh;
    if (mesh.material) (mesh.material as THREE.Material).dispose();
  });
  gizmo.spheres.values().next().value?.geometry.dispose();
  gizmo.lines.geometry.dispose();
  gizmo.group.removeFromParent();
  value.gizmo = undefined;
}
