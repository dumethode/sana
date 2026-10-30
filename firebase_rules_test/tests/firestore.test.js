import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  doc, getDoc, getDocs, collection, setDoc, updateDoc, deleteDoc, writeBatch,
  serverTimestamp, arrayUnion, arrayRemove, Timestamp,
} from 'firebase/firestore';
import {
  setup, ctx, seed, seedPeople, seedIncident, createBatch, statusBatch,
  STUDENT, STUDENT2, STAFF, CONTRACTOR, OUTSIDER,
} from './helpers.js';

let env;
before(async () => { env = await setup(); });
after(async () => { await env.cleanup(); });
beforeEach(async () => {
  await env.clearFirestore();
  await seedPeople(env);
});

describe('Access requires a verified ALU (or allowlisted) email', () => {
  it('blocks unauthenticated reads', async () => {
    await seedIncident(env, 'i1');
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'incidents', 'i1')));
  });

  it('blocks an unverified ALU account', async () => {
    await seedIncident(env, 'i1');
    await assertFails(getDoc(doc(ctx(env, STUDENT, { verified: false }).firestore(), 'incidents', 'i1')));
  });

  it('blocks a verified non-ALU account that is not allowlisted', async () => {
    await seedIncident(env, 'i1');
    await assertFails(getDoc(doc(ctx(env, OUTSIDER).firestore(), 'incidents', 'i1')));
  });

  it('allows a verified ALU student and an allowlisted contractor', async () => {
    await seedIncident(env, 'i1');
    await assertSucceeds(getDoc(doc(ctx(env, STUDENT2).firestore(), 'incidents', 'i1')));
    await assertSucceeds(getDoc(doc(ctx(env, CONTRACTOR).firestore(), 'incidents', 'i1')));
  });
});

describe('Profiles and roles', () => {
  const fresh = { uid: 'stu9', email: 'new@alustudent.com', name: 'New Person' };
  const profile = (role) => ({
    uid: fresh.uid, email: fresh.email, displayName: fresh.name, role, createdAt: serverTimestamp(),
  });

  it('a student can create their own student profile', async () => {
    await assertSucceeds(setDoc(doc(ctx(env, fresh).firestore(), 'users', fresh.uid), profile('student')));
  });

  it('a student cannot give themselves the staff role', async () => {
    await assertFails(setDoc(doc(ctx(env, fresh).firestore(), 'users', fresh.uid), profile('staff')));
  });

  it('an allowlisted contractor can create a staff profile', async () => {
    const c = { uid: 'con2', email: 'plumber.contractor@gmail.com', name: 'Plumber Co' };
    await seed(env, (db) => setDoc(doc(db, 'staffAllowlist', c.email), { department: 'Facilities' }));
    await assertSucceeds(setDoc(doc(ctx(env, c).firestore(), 'users', c.uid), {
      uid: c.uid, email: c.email, displayName: c.name, role: 'staff', department: 'Facilities', createdAt: serverTimestamp(),
    }));
  });

  it('a student cannot escalate an existing profile', async () => {
    await assertFails(updateDoc(doc(ctx(env, STUDENT).firestore(), 'users', STUDENT.uid), { role: 'staff' }));
  });

  it('a student cannot read another student profile, staff can', async () => {
    await assertFails(getDoc(doc(ctx(env, STUDENT2).firestore(), 'users', STUDENT.uid)));
    await assertSucceeds(getDoc(doc(ctx(env, STAFF).firestore(), 'users', STUDENT.uid)));
  });

  it('nobody can list the staff allowlist; you can only check your own entry', async () => {
    await assertFails(getDocs(collection(ctx(env, STUDENT).firestore(), 'staffAllowlist')));
    await assertFails(getDoc(doc(ctx(env, STUDENT).firestore(), 'staffAllowlist', STAFF.email)));
    await assertSucceeds(getDoc(doc(ctx(env, STAFF).firestore(), 'staffAllowlist', STAFF.email)));
  });
});

describe('Creating reports', () => {
  it('accepts the batch the app sends', async () => {
    await assertSucceeds(createBatch(ctx(env, STUDENT).firestore(), STUDENT, 'new1').commit());
  });

  it('enforces the 60 second cooldown between reports', async () => {
    const db = ctx(env, STUDENT).firestore();
    await assertSucceeds(createBatch(db, STUDENT, 'new1').commit());
    await assertFails(createBatch(db, STUDENT, 'new2').commit());
  });

  it('allows a new report once the cooldown has passed', async () => {
    await seed(env, (db) => updateDoc(doc(db, 'users', STUDENT.uid), {
      lastReportAt: Timestamp.fromMillis(Date.now() - 120_000),
    }));
    await assertSucceeds(createBatch(ctx(env, STUDENT).firestore(), STUDENT, 'new1').commit());
  });

  it('rejects a report that starts in any status other than submitted', async () => {
    await assertFails(createBatch(ctx(env, STUDENT).firestore(), STUDENT, 'x', { status: 'resolved' }).commit());
  });

  it('rejects a report filed in someone else\'s name', async () => {
    await assertFails(createBatch(ctx(env, STUDENT).firestore(), STUDENT, 'x', { reporterId: STUDENT2.uid }).commit());
  });

  it('rejects invalid content (short description, unknown category)', async () => {
    const db = ctx(env, STUDENT).firestore();
    await assertFails(createBatch(db, STUDENT, 'x', { description: 'too short' }).commit());
    await assertFails(createBatch(db, STUDENT, 'y', { category: 'gossip' }).commit());
  });

  it('rejects a photo path that points at another user\'s folder', async () => {
    await assertFails(createBatch(ctx(env, STUDENT).firestore(), STUDENT, 'x', {
      photoUrl: 'https://example.com/p.jpg', photoPath: `incidents/${STUDENT2.uid}/x.jpg`,
    }).commit());
  });

  it('rejects pre-filled "affects me too" lists', async () => {
    await assertFails(createBatch(ctx(env, STUDENT).firestore(), STUDENT, 'x', { affectedBy: ['a', 'b'] }).commit());
  });
});

describe('Reporter privacy', () => {
  beforeEach(() => seedIncident(env, 'i1'));

  it('other students cannot see who reported', async () => {
    await assertFails(getDoc(doc(ctx(env, STUDENT2).firestore(), 'incidents', 'i1', 'private', 'reporter')));
  });

  it('the reporter and staff can', async () => {
    await assertSucceeds(getDoc(doc(ctx(env, STUDENT).firestore(), 'incidents', 'i1', 'private', 'reporter')));
    await assertSucceeds(getDoc(doc(ctx(env, STAFF).firestore(), 'incidents', 'i1', 'private', 'reporter')));
  });
});

describe('Status changes are staff-only and follow the workflow', () => {
  beforeEach(() => seedIncident(env, 'i1'));

  it('a student cannot change status, even on their own report', async () => {
    await assertFails(statusBatch(ctx(env, STUDENT).firestore(), 'i1', { from: 'submitted', to: 'acknowledged' }).commit());
  });

  it('staff can acknowledge', async () => {
    await assertSucceeds(statusBatch(ctx(env, STAFF).firestore(), 'i1', { from: 'submitted', to: 'acknowledged' }).commit());
  });

  it('staff cannot skip backwards (in_progress to submitted)', async () => {
    await seedIncident(env, 'i2', { status: 'in_progress' });
    await assertFails(statusBatch(ctx(env, STAFF).firestore(), 'i2', { from: 'in_progress', to: 'submitted' }).commit());
  });

  it('resolving needs a note', async () => {
    const db = ctx(env, STAFF).firestore();
    await assertFails(statusBatch(db, 'i1', { from: 'submitted', to: 'resolved', note: null }).commit());
    await assertSucceeds(statusBatch(db, 'i1', { from: 'submitted', to: 'resolved', note: 'Valve replaced, water back.' }).commit());
  });

  it('the timeline entry must match the change actually made', async () => {
    const db = ctx(env, STAFF).firestore();
    const bad = writeBatch(db)
      .update(doc(db, 'incidents', 'i1'), { status: 'acknowledged', severity: 'high', statusNote: 'Seen', updatedAt: serverTimestamp() })
      .set(doc(collection(db, 'incidents', 'i1', 'history')), {
        type: 'status', from: 'submitted', to: 'resolved', note: 'lie', actorRole: 'staff', actorName: 'X', createdAt: serverTimestamp(),
      });
    await assertFails(bad.commit());
  });

  it('removing a staff member from the allowlist revokes access immediately', async () => {
    await seed(env, (db) => deleteDoc(doc(db, 'staffAllowlist', STAFF.email)));
    await assertFails(statusBatch(ctx(env, STAFF).firestore(), 'i1', { from: 'submitted', to: 'acknowledged' }).commit());
  });

  it('history is append-only', async () => {
    await assertFails(updateDoc(doc(ctx(env, STAFF).firestore(), 'incidents', 'i1', 'history', 'h0'), { note: 'rewritten' }));
  });
});

describe('Affects me too', () => {
  beforeEach(() => seedIncident(env, 'i1'));

  it('another student can add and remove themselves', async () => {
    const db = ctx(env, STUDENT2).firestore();
    await assertSucceeds(updateDoc(doc(db, 'incidents', 'i1'), { affectedBy: arrayUnion(STUDENT2.uid) }));
    await assertSucceeds(updateDoc(doc(db, 'incidents', 'i1'), { affectedBy: arrayRemove(STUDENT2.uid) }));
  });

  it('nobody can add someone else', async () => {
    await assertFails(updateDoc(doc(ctx(env, STUDENT2).firestore(), 'incidents', 'i1'), { affectedBy: arrayUnion('ghost') }));
  });

  it('the reporter cannot inflate their own report', async () => {
    await assertFails(updateDoc(doc(ctx(env, STUDENT).firestore(), 'incidents', 'i1'), { affectedBy: arrayUnion(STUDENT.uid) }));
  });

  it('closed reports cannot be joined', async () => {
    await seedIncident(env, 'i2', { status: 'resolved', resolvedAt: Timestamp.now() });
    await assertFails(updateDoc(doc(ctx(env, STUDENT2).firestore(), 'incidents', 'i2'), { affectedBy: arrayUnion(STUDENT2.uid) }));
  });
});

describe('Owner edit, delete and reopen', () => {
  const edit = (db, id) => writeBatch(db)
    .update(doc(db, 'incidents', id), { title: 'No water in Block B, all floors', updatedAt: serverTimestamp() })
    .set(doc(collection(db, 'incidents', id, 'history')), {
      type: 'edited', from: 'submitted', to: 'submitted', note: null, actorRole: 'student', actorName: null, createdAt: serverTimestamp(),
    });

  const remove = async (db, id) => {
    const history = await getDocs(collection(db, 'incidents', id, 'history'));
    const batch = writeBatch(db);
    history.forEach((h) => batch.delete(h.ref));
    batch.delete(doc(db, 'incidents', id, 'private', 'reporter')).delete(doc(db, 'incidents', id));
    return batch.commit();
  };

  it('the owner can edit and delete while submitted', async () => {
    await seedIncident(env, 'i1');
    const db = ctx(env, STUDENT).firestore();
    await assertSucceeds(edit(db, 'i1').commit());
    await assertSucceeds(remove(db, 'i1'));
  });

  it('once staff acknowledge, the owner can no longer edit or delete', async () => {
    await seedIncident(env, 'i1', { status: 'acknowledged' });
    const db = ctx(env, STUDENT).firestore();
    await assertFails(edit(db, 'i1').commit());
    await assertFails(deleteDoc(doc(db, 'incidents', 'i1')));
  });

  it('another student cannot edit or delete', async () => {
    await seedIncident(env, 'i1');
    const db = ctx(env, STUDENT2).firestore();
    await assertFails(edit(db, 'i1').commit());
    await assertFails(deleteDoc(doc(db, 'incidents', 'i1')));
  });

  it('staff cannot delete (they close as Not actioned instead)', async () => {
    await seedIncident(env, 'i1');
    await assertFails(deleteDoc(doc(ctx(env, STAFF).firestore(), 'incidents', 'i1')));
  });

  const reopen = (db, id, count) => writeBatch(db)
    .update(doc(db, 'incidents', id), {
      status: 'in_progress', reopenCount: count, resolvedAt: null, statusNote: 'Leaking again tonight.', updatedAt: serverTimestamp(),
    })
    .set(doc(collection(db, 'incidents', id, 'history')), {
      type: 'reopened', from: 'resolved', to: 'in_progress', note: 'Leaking again tonight.', actorRole: 'student', actorName: null, createdAt: serverTimestamp(),
    });

  it('the owner can reopen a resolved report, at most twice', async () => {
    await seedIncident(env, 'i1', { status: 'resolved', resolvedAt: Timestamp.now(), statusNote: 'Fixed valve.' });
    await assertSucceeds(reopen(ctx(env, STUDENT).firestore(), 'i1', 1).commit());
    await seedIncident(env, 'i2', { status: 'resolved', resolvedAt: Timestamp.now(), statusNote: 'Fixed valve.', reopenCount: 2 });
    await assertFails(reopen(ctx(env, STUDENT).firestore(), 'i2', 3).commit());
  });
});
