import { lazy, Suspense } from 'react';
import '../studio3d/studio3d.css';

// Incursion From Beyond: solo el espacio 3D (el 2D de MotionBridge sigue en src/, sin usar).
const Studio3D = lazy(() => import('../studio3d/Studio3D'));

export default function Workspace() {
  return <Suspense fallback={<p className="studio3d-loading">Preparando la captura de movimiento…</p>}><Studio3D active /></Suspense>;
}
