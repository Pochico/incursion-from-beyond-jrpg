// Rig automático (Incursion From Beyond): coloca un esqueleto humanoide
// aproximado sobre cualquier modelo (con o sin esqueleto propio), calcula los
// pesos de la piel por distancia a los huesos y permite rehacerlo al mover las
// articulaciones a mano. El resultado es un CharacterRig3D normal: se anima y se
// exporta igual que un modelo con esqueleto.
import * as THREE from 'three';
import { HUMANOID_BONES, HUMANOID_PARENTS } from '../motion3d/types.ts';
import type { Bone3D } from '../motion3d/types.ts';

/** Puntas que no son huesos animados: dan la longitud de cabeza, manos y pies. */
export const TIP_JOINTS = { head: 'headTop', handL: 'handTipL', handR: 'handTipR', footL: 'toeL', footR: 'toeR' } as const;
type Tip = typeof TIP_JOINTS[keyof typeof TIP_JOINTS];
export type JointName = Bone3D | Tip;
export type Joints3D = Record<JointName, THREE.Vector3>;
export const JOINT_NAMES: JointName[] = [...HUMANOID_BONES, ...Object.values(TIP_JOINTS)];

export const JOINT_LABELS: Record<JointName, string> = {
  hips: 'Cadera', spine: 'Columna', chest: 'Pecho', neck: 'Cuello', head: 'Cabeza', headTop: 'Coronilla',
  upperArmL: 'Hombro izq.', forearmL: 'Codo izq.', handL: 'Muñeca izq.', handTipL: 'Punta mano izq.',
  upperArmR: 'Hombro der.', forearmR: 'Codo der.', handR: 'Muñeca der.', handTipR: 'Punta mano der.',
  thighL: 'Ingle izq.', shinL: 'Rodilla izq.', footL: 'Tobillo izq.', toeL: 'Punta pie izq.',
  thighR: 'Ingle der.', shinR: 'Rodilla der.', footR: 'Tobillo der.', toeR: 'Punta pie der.',
};

/** Lado de la articulación (para la simetría y los colores): L, R o centro. */
export function jointSide(name: JointName): 'L' | 'R' | 'C' {
  return name.endsWith('L') ? 'L' : name.endsWith('R') ? 'R' : 'C';
}
export function mirrorJoint(name: JointName): JointName | undefined {
  const side = jointSide(name);
  if (side === 'C') return undefined;
  return (name.slice(0, -1) + (side === 'L' ? 'R' : 'L')) as JointName;
}

/** Hijo que marca el final de cada hueso (para el segmento de la piel). */
const SEGMENT_END: Record<Bone3D, JointName> = {
  hips: 'spine', spine: 'chest', chest: 'neck', neck: 'head', head: 'headTop',
  upperArmL: 'forearmL', forearmL: 'handL', handL: 'handTipL',
  upperArmR: 'forearmR', forearmR: 'handR', handR: 'handTipR',
  thighL: 'shinL', shinL: 'footL', footL: 'toeL',
  thighR: 'shinR', shinR: 'footR', footR: 'toeR',
};
/** Líneas para dibujar el esqueleto en el editor. */
export const JOINT_LINKS: [JointName, JointName][] = [
  ...HUMANOID_BONES.filter(name => HUMANOID_PARENTS[name]).map(name => [HUMANOID_PARENTS[name]!, name] as [JointName, JointName]),
  ...Object.entries(TIP_JOINTS).map(([bone, tip]) => [bone, tip] as [JointName, JointName]),
];

/** Malla estática del modelo, ya en el espacio del personaje (1,85 de alto, pies en y=0, mirando a +Z). */
export interface AutoRigPart { geometry: THREE.BufferGeometry; material: THREE.Material | THREE.Material[]; name: string }
export interface AutoRigSource { name: string; parts: AutoRigPart[]; facing: number }

/**
 * Copia las mallas del modelo tal y como se ven (con su pose de reposo si ya
 * tenían esqueleto) al espacio de `root`, sin huesos ni jerarquía.
 */
export function captureAutoRigSource(root: THREE.Object3D, name: string): AutoRigSource {
  root.updateMatrixWorld(true);
  const toRoot = root.matrixWorld.clone().invert();
  const parts: AutoRigPart[] = [];
  const vertex = new THREE.Vector3();
  root.traverse(object => {
    const mesh = object as THREE.Mesh;
    if (!mesh.isMesh || !mesh.geometry?.getAttribute('position')) return;
    const skinned = (mesh as THREE.SkinnedMesh).isSkinnedMesh ? mesh as THREE.SkinnedMesh : undefined;
    const matrix = toRoot.clone().multiply(mesh.matrixWorld);
    const normalMatrix = new THREE.Matrix3().getNormalMatrix(matrix);
    const source = mesh.geometry;
    const geometry = new THREE.BufferGeometry();
    const position = source.getAttribute('position');
    const positions = new Float32Array(position.count * 3);
    for (let i = 0; i < position.count; i++) {
      vertex.fromBufferAttribute(position, i);
      if (skinned) skinned.applyBoneTransform(i, vertex);
      vertex.applyMatrix4(matrix);
      positions.set([vertex.x, vertex.y, vertex.z], i * 3);
    }
    geometry.setAttribute('position', new THREE.BufferAttribute(positions, 3));
    const normal = source.getAttribute('normal');
    if (normal) {
      const normals = new Float32Array(normal.count * 3);
      for (let i = 0; i < normal.count; i++) {
        vertex.fromBufferAttribute(normal, i).applyMatrix3(normalMatrix).normalize();
        normals.set([vertex.x, vertex.y, vertex.z], i * 3);
      }
      geometry.setAttribute('normal', new THREE.BufferAttribute(normals, 3));
    }
    for (const [key, attribute] of Object.entries(source.attributes)) {
      if (['position', 'normal', 'skinIndex', 'skinWeight'].includes(key)) continue;
      geometry.setAttribute(key, (attribute as THREE.BufferAttribute).clone());
    }
    if (source.index) geometry.setIndex(source.index.clone());
    for (const group of source.groups) geometry.addGroup(group.start, group.count, group.materialIndex);
    if (matrix.determinant() < 0 && geometry.index) {
      // Una escala negativa da la vuelta a las caras: se corrige el orden.
      const index = geometry.index.array;
      for (let i = 0; i < index.length; i += 3) { const t = index[i + 1]; index[i + 1] = index[i + 2]; index[i + 2] = t; }
    }
    parts.push({ geometry, material: mesh.material, name: mesh.name });
  });
  if (!parts.length) throw new Error('El modelo no tiene mallas.');
  return { name, parts, facing: 0 };
}

/** Gira la fuente alrededor de Y para que el modelo mire a +Z. */
export function setSourceFacing(source: AutoRigSource, degrees: number): void {
  const delta = (degrees - source.facing) * Math.PI / 180;
  if (!delta) return;
  const rotation = new THREE.Matrix4().makeRotationY(delta);
  for (const part of source.parts) part.geometry.applyMatrix4(rotation);
  source.facing = degrees;
}

function sampleVertices(source: AutoRigSource, limit = 40000): THREE.Vector3[] {
  const total = source.parts.reduce((sum, part) => sum + part.geometry.getAttribute('position').count, 0);
  const step = Math.max(1, Math.floor(total / limit));
  const out: THREE.Vector3[] = [];
  for (const part of source.parts) {
    const position = part.geometry.getAttribute('position');
    for (let i = 0; i < position.count; i += step) out.push(new THREE.Vector3().fromBufferAttribute(position, i));
  }
  return out;
}

function median(values: number[], fallback = 0): number {
  if (!values.length) return fallback;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

/**
 * Esqueleto aproximado a partir de la forma: alturas por proporciones humanas,
 * piernas por el centro de cada lado bajo la cadera, brazos hacia el vértice
 * más alejado de cada lado (vale para pose en T y en A). Se corrige a mano.
 */
export function estimateJoints(source: AutoRigSource): Joints3D {
  const points = sampleVertices(source);
  const box = new THREE.Box3().setFromPoints(points);
  const H = Math.max(box.max.y, 1e-3);
  const y = (ratio: number) => ratio * H;
  const zAt = (low: number, high: number) => median(points.filter(p => p.y >= y(low) && p.y <= y(high)).map(p => p.z), (box.min.z + box.max.z) / 2);
  const torsoZ = zAt(.5, .78), headZ = zAt(.85, .97);
  const j = {} as Joints3D;
  j.hips = new THREE.Vector3(0, y(.53), torsoZ);
  j.spine = new THREE.Vector3(0, y(.63), torsoZ);
  j.chest = new THREE.Vector3(0, y(.73), torsoZ);
  j.neck = new THREE.Vector3(0, y(.8), torsoZ);
  j.head = new THREE.Vector3(0, y(.87), headZ);
  j.headTop = new THREE.Vector3(0, H, headZ);
  // Ancho del tronco a la altura del pecho, sin contar los brazos: el percentil 25 del |x|.
  const chestBand = points.filter(p => Math.abs(p.y - j.chest.y) < y(.04)).map(p => Math.abs(p.x)).sort((a, b) => a - b);
  const halfTorso = Math.max(y(.07), Math.min(y(.13), chestBand[Math.floor(chestBand.length * .5)] ?? y(.1)));
  for (const side of [1, -1] as const) {
    const n = (base: string) => (base + (side === 1 ? 'L' : 'R')) as JointName;
    // Piernas: centro de los vértices de ese lado entre rodilla y cadera.
    const legX = median(points.filter(p => p.y > y(.2) && p.y < y(.45) && p.x * side > 0).map(p => p.x), side * y(.06));
    const legZ = median(points.filter(p => p.y > y(.2) && p.y < y(.45) && p.x * side > 0).map(p => p.z), torsoZ);
    j[n('thigh')] = new THREE.Vector3(legX, y(.5), legZ);
    j[n('shin')] = new THREE.Vector3(legX, y(.28), legZ);
    j[n('foot')] = new THREE.Vector3(legX, y(.05), legZ);
    const feet = points.filter(p => p.y < y(.06) && p.x * side > 0);
    j[n('toe')] = new THREE.Vector3(legX, y(.01), feet.length ? Math.max(...feet.map(p => p.z)) : legZ + y(.08));
    // Brazos: el hombro, a los lados del pecho; la punta de la mano, el vértice
    // más lejano del eje del cuerpo por encima de las rodillas.
    const shoulder = new THREE.Vector3(side * halfTorso, y(.77), torsoZ);
    // Solo lo que está a la altura del tronco en profundidad: el pelo o una capa suelen quedar detrás.
    const near = points.filter(p => p.x * side > halfTorso && p.y > y(.3) && Math.abs(p.z - torsoZ) < y(.08));
    const candidates = near.length > 20 ? near : points.filter(p => p.x * side > halfTorso && p.y > y(.3));
    let tip = candidates.reduce<THREE.Vector3 | undefined>((best, p) => !best || p.distanceToSquared(shoulder) > best.distanceToSquared(shoulder) ? p : best, undefined);
    if (!tip || tip.distanceTo(shoulder) < y(.15)) tip = new THREE.Vector3(side * y(.45), y(.77), torsoZ);
    const arm = tip.clone().sub(shoulder);
    j[n('upperArm')] = shoulder;
    j[n('forearm')] = shoulder.clone().addScaledVector(arm, .45);
    j[n('hand')] = shoulder.clone().addScaledVector(arm, .82);
    j[n('handTip')] = tip.clone();
  }
  return j;
}

/** Distancia al cuadrado de p al segmento ab. */
function segmentDistanceSq(p: THREE.Vector3, a: THREE.Vector3, b: THREE.Vector3, ab: THREE.Vector3, abLenSq: number): number {
  const t = abLenSq > 1e-12 ? Math.min(1, Math.max(0, (p.x - a.x) * ab.x + (p.y - a.y) * ab.y + (p.z - a.z) * ab.z) / abLenSq) : 0;
  const dx = p.x - (a.x + ab.x * t), dy = p.y - (a.y + ab.y * t), dz = p.z - (a.z + ab.z * t);
  return dx * dx + dy * dy + dz * dz;
}

/**
 * Pesos de la piel por cercanía a cada hueso (hasta 4 por vértice). Los huesos
 * del lado contrario pesan mucho menos, para que un brazo no arrastre la otra
 * mitad del cuerpo.
 */
export function computeSkinWeights(geometry: THREE.BufferGeometry, joints: Joints3D): { indices: Uint16Array; weights: Float32Array } {
  const position = geometry.getAttribute('position');
  const segments = HUMANOID_BONES.map(name => {
    const a = joints[name], b = joints[SEGMENT_END[name]];
    const ab = b.clone().sub(a);
    return { a, b, ab, lenSq: ab.lengthSq(), side: jointSide(name) };
  });
  const indices = new Uint16Array(position.count * 4), weights = new Float32Array(position.count * 4);
  const p = new THREE.Vector3();
  const centerBand = Math.abs(joints.thighL.x - joints.thighR.x) * .35;
  const scores = new Float64Array(segments.length);
  for (let i = 0; i < position.count; i++) {
    p.fromBufferAttribute(position, i);
    const side = p.x > centerBand ? 'L' : p.x < -centerBand ? 'R' : 'C';
    segments.forEach((segment, k) => {
      let d = segmentDistanceSq(p, segment.a, segment.b, segment.ab, segment.lenSq);
      if (side !== 'C' && segment.side !== 'C' && segment.side !== side) d *= 25;
      scores[k] = 1 / Math.pow(d + 1e-6, 2);
    });
    // Los 4 mayores.
    const order = [...scores.keys()].sort((a, b) => scores[b] - scores[a]).slice(0, 4);
    const sum = order.reduce((total, k) => total + scores[k], 0);
    order.forEach((k, slot) => { indices[i * 4 + slot] = k; weights[i * 4 + slot] = scores[k] / sum; });
  }
  return { indices, weights };
}

/**
 * Personaje con esqueleto a partir de la fuente y las articulaciones: huesos
 * con el nombre canónico (hips, spine…), sin rotación de reposo, puntas como
 * huesos hijos (head_end…) y una SkinnedMesh por parte.
 */
export function buildAutoRigObject(source: AutoRigSource, joints: Joints3D): { root: THREE.Group; bones: Map<Bone3D, THREE.Bone> } {
  const root = new THREE.Group();
  root.name = source.name.replace(/\.[^.]+$/, '');
  const bones = new Map<Bone3D, THREE.Bone>();
  const ordered: THREE.Bone[] = [];
  for (const name of HUMANOID_BONES) {
    const bone = new THREE.Bone();
    bone.name = name;
    const parent = HUMANOID_PARENTS[name];
    bone.position.copy(joints[name]).sub(parent ? joints[parent] : new THREE.Vector3());
    (parent ? bones.get(parent)! : root).add(bone);
    bones.set(name, bone); ordered.push(bone);
  }
  for (const [boneName, tip] of Object.entries(TIP_JOINTS) as [Bone3D, Tip][]) {
    const end = new THREE.Bone();
    end.name = `${boneName}_end`;
    end.position.copy(joints[tip]).sub(joints[boneName]);
    bones.get(boneName)!.add(end);
  }
  root.updateMatrixWorld(true);
  const skeleton = new THREE.Skeleton(ordered);
  for (const part of source.parts) {
    const geometry = part.geometry.clone();
    const { indices, weights } = computeSkinWeights(geometry, joints);
    geometry.setAttribute('skinIndex', new THREE.Uint16BufferAttribute(indices, 4));
    geometry.setAttribute('skinWeight', new THREE.Float32BufferAttribute(weights, 4));
    const mesh = new THREE.SkinnedMesh(geometry, part.material);
    mesh.name = part.name;
    root.add(mesh);
    mesh.bind(skeleton, new THREE.Matrix4());
  }
  return { root, bones };
}
