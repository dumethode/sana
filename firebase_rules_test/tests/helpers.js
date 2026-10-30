import { readFileSync } from 'node:fs';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc, setDoc, writeBatch, serverTimestamp, Timestamp, collection,
} from 'firebase/firestore';

export const STUDENT = { uid: 'stu1', email: 'amina@alustudent.com', name: 'Amina K' };
export const STUDENT2 = { uid: 'stu2', email: 'eric@alustudent.com', name: 'Eric N' };
export const STAFF = { uid: 'staff1', email: 'facilities@alueducation.com', name: 'Jean P' };
export const CONTRACTOR = { uid: 'con1', email: 'fixit.contractor@gmail.com', name: 'Grace U' };
export const OUTSIDER = { uid: 'out1', email: 'random@gmail.com', name: 'Out Sider' };

export async function setup() {
  return initializeTestEnvironment({
    projectId: 'demo-sana',
    firestore: { rules: readFileSync(new URL('../../firestore.rules', import.meta.url), 'utf8') },
    storage: { rules: readFileSync(new URL('../../storage.rules', import.meta.url), 'utf8') },
  });
}

export function ctx(env, person, { verified = true } = {}) {
  return env.authenticatedContext(person.uid, { email: person.email, email_verified: verified });
}

/** Seeds users, the allowlist and (optionally) incidents with rules off. */
export async function seed(env, fn) {
  await env.withSecurityRulesDisabled(async (c) => fn(c.firestore()));
}

export async function seedPeople(env) {
  await seed(env, async (db) => {
    for (const p of [STUDENT, STUDENT2]) {
      await setDoc(doc(db, 'users', p.uid), {
        uid: p.uid, email: p.email, displayName: p.name, role: 'student', createdAt: Timestamp.now(),
      });
    }
    for (const p of [STAFF, CONTRACTOR]) {
      await setDoc(doc(db, 'staffAllowlist', p.email), { department: 'Facilities' });
      await setDoc(doc(db, 'users', p.uid), {
        uid: p.uid, email: p.email, displayName: p.name, role: 'staff', department: 'Facilities',
        createdAt: Timestamp.now(),
      });
    }
  });
}

export const content = {
  title: 'No water in Block B showers',
  description: 'Since this morning the third floor showers have had no water at all.',
  category: 'water',
  severity: 'high',
  locationArea: 'residence',
  locationDetail: 'Block B, 3rd floor',
  photoUrl: null,
  photoPath: null,
};

/** Seeds an incident owned by STUDENT in a given status. */
export async function seedIncident(env, id, overrides = {}) {
  await seed(env, async (db) => {
    await setDoc(doc(db, 'incidents', id), {
      ...content,
      status: 'submitted',
      statusNote: null,
      reporterId: STUDENT.uid,
      affectedBy: [],
      reopenCount: 0,
      resolvedAt: null,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
      ...overrides,
    });
    await setDoc(doc(db, 'incidents', id, 'private', 'reporter'), {
      uid: STUDENT.uid, name: STUDENT.name, email: STUDENT.email,
    });
    await setDoc(doc(db, 'incidents', id, 'history', 'h0'), {
      type: 'created', from: null, to: 'submitted', note: null, actorRole: 'student', actorName: null,
      createdAt: Timestamp.now(),
    });
  });
}

/** The exact batch IncidentRepository.create() sends. */
export function createBatch(db, person, id, overrides = {}) {
  const ref = doc(db, 'incidents', id);
  const now = serverTimestamp();
  return writeBatch(db)
    .set(ref, {
      ...content,
      status: 'submitted',
      statusNote: null,
      reporterId: person.uid,
      affectedBy: [],
      reopenCount: 0,
      resolvedAt: null,
      createdAt: now,
      updatedAt: now,
      ...overrides,
    })
    .set(doc(db, 'incidents', id, 'private', 'reporter'), {
      uid: person.uid, name: person.name, email: person.email,
    })
    .set(doc(collection(db, 'incidents', id, 'history')), {
      type: 'created', from: null, to: 'submitted', note: null, actorRole: 'student', actorName: null,
      createdAt: now,
    })
    .update(doc(db, 'users', person.uid), { lastReportAt: now });
}

/** The exact batch IncidentRepository.changeStatus() sends. */
export function statusBatch(db, id, { from, to, note = 'Plumber dispatched to fix the valve.', severity = 'high', resolvedAt }) {
  const now = serverTimestamp();
  const update = { status: to, severity, statusNote: note, updatedAt: now };
  if (from !== to) update.resolvedAt = to === 'resolved' ? now : null;
  if (resolvedAt !== undefined) update.resolvedAt = resolvedAt;
  return writeBatch(db)
    .update(doc(db, 'incidents', id), update)
    .set(doc(collection(db, 'incidents', id, 'history')), {
      type: 'status', from, to, note, actorRole: 'staff', actorName: 'Jean P (Facilities)', createdAt: now,
    });
}
