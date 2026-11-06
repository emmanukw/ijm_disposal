// Attacks the Firestore rules on the emulator. Run after tool/seed_emulator.py.
import { initializeApp } from 'firebase/app';
import { getAuth, connectAuthEmulator, signInWithEmailAndPassword, createUserWithEmailAndPassword } from 'firebase/auth';
import {
  getFirestore, connectFirestoreEmulator, doc, getDoc, getDocs, collection, setDoc,
  runTransaction, serverTimestamp, updateDoc,
} from 'firebase/firestore';

const PROJECT = 'demo-ijm-disposal';
const AUTH = 'http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1';
let n = 0;
async function client(email, password, { create = false, verify = false } = {}) {
  const app = initializeApp({ projectId: PROJECT, apiKey: 'demo' }, `c${n++}`);
  const auth = getAuth(app);
  connectAuthEmulator(auth, 'http://127.0.0.1:9099', { disableWarnings: true });
  const db = getFirestore(app);
  connectFirestoreEmulator(db, '127.0.0.1', 8080);
  const cred = create
    ? await createUserWithEmailAndPassword(auth, email, password)
    : await signInWithEmailAndPassword(auth, email, password);
  if (verify) {
    await fetch(`${AUTH}/projects/${PROJECT}/accounts:update`, {
      method: 'POST', headers: { 'content-type': 'application/json', Authorization: 'Bearer owner' },
      body: JSON.stringify({ localId: cred.user.uid, emailVerified: true }),
    });
    await cred.user.getIdToken(true);
  }
  return { db, uid: cred.user.uid, email };
}

let pass = 0, fail = 0;
async function expect(name, shouldSucceed, fn) {
  let ok;
  let err = '';
  try { await fn(); ok = true; } catch (e) { ok = false; err = e.code || e.message; }
  const good = ok === shouldSucceed;
  good ? pass++ : fail++;
  console.log(`${good ? 'PASS' : 'FAIL'}  ${name}  (${ok ? 'allowed' : 'denied: ' + err})`);
}

// Book like the app does (optionally lying about the tally).
async function book(c, itemId, qty, { lieTotal } = {}) {
  await runTransaction(c.db, async (tx) => {
    const itemRef = doc(c.db, 'items', itemId);
    const tallyRef = doc(c.db, 'bidders', c.uid);
    const item = (await tx.get(itemRef)).data();
    const t = (await tx.get(tallyRef)).data() ?? { total: 0, items: {} };
    const bidRef = doc(collection(c.db, 'bids'));
    tx.set(bidRef, {
      itemId, itemName: item.name, bidderName: 'Rule Tester', email: c.email,
      quantity: qty, unitPrice: item.price, uid: c.uid, createdAt: serverTimestamp(),
    });
    tx.update(itemRef, { remaining: item.remaining - qty, lastBidId: bidRef.id });
    tx.set(tallyRef, {
      name: 'Rule Tester', email: c.email,
      total: lieTotal ?? t.total + qty,
      items: { ...t.items, [itemId]: lieTotal ?? (t.items[itemId] ?? 0) + qty },
      lastBidId: bidRef.id,
    });
  });
}

const outsider = await client('bob@gmail.com', 'password1', { create: true, verify: true });
const unverified = await client('eve@ijm.org', 'password1', { create: true });
const staff = await client('staff@ijm.org', 'staff123');
const staff2 = await client('second.person@ijm.org', 'password1', { create: true, verify: true });
const admin = await client('admin@ijm.org', 'admin123');

console.log('--- access control (settings: max 2 per item, 3 total) ---');
await expect('outsider (gmail) cannot read items', false, () => getDocs(collection(outsider.db, 'items')));
await expect('outsider cannot read bids', false, () => getDocs(collection(outsider.db, 'bids')));
await expect('unverified @ijm.org cannot read items', false, () => getDocs(collection(unverified.db, 'items')));
await expect('verified staff can read items', true, () => getDocs(collection(staff.db, 'items')));
await expect('verified staff can read bids', true, () => getDocs(collection(staff.db, 'bids')));
await expect('staff cannot read payment status', false, () => getDocs(collection(staff.db, 'bidStatus')));
await expect('staff cannot mark own bid paid', false, () => setDoc(doc(staff.db, 'bidStatus', 'bid0'), { paid: true }));
await expect('staff cannot change settings/limits', false, () => updateDoc(doc(staff.db, 'settings', 'auction'), { maxTotalPerPerson: 99 }));
await expect('staff cannot read someone else\'s tally', false, () => getDoc(doc(staff.db, 'bidders', 'seed-grace.wanjiru')));
await expect('outsider cannot book', false, () => book(outsider, 'item4', 1));

console.log('--- booking limits ---');
await expect('staff books 2 monitors (within per-item limit)', true, () => book(staff, 'item4', 2));
await expect('staff books a 3rd monitor (over per-item limit 2)', false, () => book(staff, 'item4', 1));
await expect('staff lies about tally to book 3rd monitor', false, () => book(staff, 'item4', 1, { lieTotal: 1 }));
await expect('staff books 1 water dispenser (total 3 = limit)', true, () => book(staff, 'item5', 1));
await expect('staff books another item (over total limit 3)', false, () => book(staff, 'item1', 1));
await expect('staff resets own tally to 0 directly', false, () => setDoc(doc(staff.db, 'bidders', staff.uid), { name: 'x', email: staff.email, total: 0, items: {}, lastBidId: 'bid0' }));
await expect('second staff member has own allowance', true, () => book(staff2, 'item4', 2));
await expect('staff cannot delete a bid', false, async () => {
  const { deleteDoc } = await import('firebase/firestore');
  await deleteDoc(doc(staff.db, 'bids', 'bid0'));
});

console.log('--- admin ---');
await expect('admin can read payment status', true, () => getDocs(collection(admin.db, 'bidStatus')));
await expect('admin can mark a bid paid', true, () => setDoc(doc(admin.db, 'bidStatus', 'bid1'), { paid: true }, { merge: true }));
await expect('admin can change limits', true, () => updateDoc(doc(admin.db, 'settings', 'auction'), { maxTotalPerPerson: 5 }));
await expect('after raising limit, staff can book again', true, () => book(staff, 'item1', 1));
await updateDoc(doc(admin.db, 'settings', 'auction'), { maxTotalPerPerson: 3 });

console.log(`\n${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
