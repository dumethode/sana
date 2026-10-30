import { after, before, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { ref, uploadBytes, getBytes } from 'firebase/storage';
import { setup, ctx, STUDENT, STUDENT2 } from './helpers.js';

let env;
before(async () => { env = await setup(); });
after(async () => { await env.cleanup(); });

const jpeg = new Uint8Array([0xff, 0xd8, 0xff, 0xe0, 0, 0, 0, 0]);

describe('Incident photos', () => {
  it('the owner can upload an image into their own folder', async () => {
    const s = ctx(env, STUDENT).storage();
    await assertSucceeds(uploadBytes(ref(s, `incidents/${STUDENT.uid}/i1_1.jpg`), jpeg, { contentType: 'image/jpeg' }));
  });

  it('nobody can upload into someone else\'s folder', async () => {
    const s = ctx(env, STUDENT2).storage();
    await assertFails(uploadBytes(ref(s, `incidents/${STUDENT.uid}/i1_2.jpg`), jpeg, { contentType: 'image/jpeg' }));
  });

  it('only images are accepted', async () => {
    const s = ctx(env, STUDENT).storage();
    await assertFails(uploadBytes(ref(s, `incidents/${STUDENT.uid}/x.pdf`), jpeg, { contentType: 'application/pdf' }));
  });

  it('files of 5 MB or more are refused', async () => {
    const s = ctx(env, STUDENT).storage();
    const big = new Uint8Array(5 * 1024 * 1024 + 1);
    await assertFails(uploadBytes(ref(s, `incidents/${STUDENT.uid}/big.jpg`), big, { contentType: 'image/jpeg' }));
  });

  it('unverified accounts cannot read photos; verified members can', async () => {
    const owner = ctx(env, STUDENT).storage();
    await uploadBytes(ref(owner, `incidents/${STUDENT.uid}/i1_3.jpg`), jpeg, { contentType: 'image/jpeg' });
    await assertFails(getBytes(ref(ctx(env, STUDENT2, { verified: false }).storage(), `incidents/${STUDENT.uid}/i1_3.jpg`)));
    await assertSucceeds(getBytes(ref(ctx(env, STUDENT2).storage(), `incidents/${STUDENT.uid}/i1_3.jpg`)));
  });
});
