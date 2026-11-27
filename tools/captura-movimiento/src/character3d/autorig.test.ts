import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import { HUMANOID_BONES } from '../motion3d/types.ts';
import { captureAutoRigSource, computeSkinWeights, estimateJoints, mirrorJoint } from './autorig.ts';
import { applyPose3D, createAutoRig3D, cloneCharacter3D } from './rig.ts';
import { retargetFrame3D } from '../motion3d/retarget.ts';

/** Muñeco en T sin esqueleto: tronco, cabeza, brazos y piernas en cajas, 1,85 de alto. */
function dummy(): THREE.Group {
  const root = new THREE.Group();
  const material = new THREE.MeshBasicMaterial();
  const box = (w: number, h: number, d: number, x: number, y: number) => {
    const mesh = new THREE.Mesh(new THREE.BoxGeometry(w, h, d, 2, 6, 2), material);
    mesh.position.set(x, y, 0); root.add(mesh);
  };
  box(.36, .62, .2, 0, 1.24);          // tronco
  box(.2, .24, .2, 0, 1.73);           // cabeza
  box(.5, .08, .08, .43, 1.42);        // brazo izq. (+X)
  box(.5, .08, .08, -.43, 1.42);       // brazo der.
  box(.12, .96, .12, .1, .48);         // pierna izq.
  box(.12, .96, .12, -.1, .48);        // pierna der.
  return root;
}

test('el rig automático coloca un esqueleto con sentido sobre un muñeco en T', () => {
  const source = captureAutoRigSource(dummy(), 'muneco.glb');
  const j = estimateJoints(source);
  assert.ok(j.hips.y > .8 && j.hips.y < 1.15, `cadera a ${j.hips.y}`);
  assert.ok(j.head.y > j.neck.y && j.neck.y > j.chest.y && j.chest.y > j.spine.y && j.spine.y > j.hips.y);
  assert.ok(j.handTipL.x > .6 && j.handTipR.x < -.6, 'las manos llegan a los extremos de los brazos');
  assert.ok(j.forearmL.x > j.upperArmL.x && j.handL.x > j.forearmL.x);
  assert.ok(Math.abs(j.thighL.x - .1) < .04 && Math.abs(j.thighR.x + .1) < .04, 'piernas en el centro de cada lado');
  assert.ok(j.footL.y < j.shinL.y && j.shinL.y < j.thighL.y);
  assert.equal(mirrorJoint('handL'), 'handR');
  assert.equal(mirrorJoint('hips'), undefined);
});

test('los pesos suman 1 y un brazo no mueve el otro', () => {
  const source = captureAutoRigSource(dummy(), 'muneco.glb');
  const joints = estimateJoints(source);
  for (const part of source.parts) {
    const { indices, weights } = computeSkinWeights(part.geometry, joints);
    const position = part.geometry.getAttribute('position');
    for (let i = 0; i < position.count; i++) {
      const sum = weights[i * 4] + weights[i * 4 + 1] + weights[i * 4 + 2] + weights[i * 4 + 3];
      assert.ok(Math.abs(sum - 1) < 1e-5);
      if (position.getX(i) > .45) {
        const bone = HUMANOID_BONES[indices[i * 4]];
        assert.ok(bone.endsWith('L'), `vértice del brazo izq. pesado a ${bone}`);
      }
    }
  }
});

test('un rig automático se anima y se clona para exportar', () => {
  const rig = createAutoRig3D(captureAutoRigSource(dummy(), 'muneco.glb'));
  assert.equal(Object.keys(rig.mapping).length, HUMANOID_BONES.length);
  assert.ok(rig.auto);
  let skinned = 0; rig.root.traverse(object => { if ((object as THREE.SkinnedMesh).isSkinnedMesh) skinned++; });
  assert.equal(skinned, 6);
  const identity = { x: 0, y: 0, z: 0, w: 1 };
  const frame = {
    timestampMs: 0, rotations: Object.fromEntries(HUMANOID_BONES.map(n => [n, identity])),
    positions: Object.fromEntries(HUMANOID_BONES.map(n => [n, { x: 0, y: 0, z: 0, confidence: 1 }])),
    confidence: Object.fromEntries(HUMANOID_BONES.map(n => [n, 1])), held: Object.fromEntries(HUMANOID_BONES.map(n => [n, false])),
    root: { x: 0, y: 0, z: 0 }, rootTracked: true, scale: 1, valid: true, needsReview: false,
  } as never;
  applyPose3D(rig, retargetFrame3D(frame, frame, rig.skeleton, { strength: 1, inPlace: true }));
  const clone = cloneCharacter3D(rig);
  assert.equal(Object.keys(clone.mapping).length, HUMANOID_BONES.length);
});
