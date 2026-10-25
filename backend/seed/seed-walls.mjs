import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";

const projectId = "uni-ios-a6b5f";
const geohashPrecision = 9;
const geohashAlphabet = "0123456789bcdefghjkmnpqrstuvwxyz";

const demoWalls = [
  { id: "demo-independence-square", title: "Independence Square steps", latitude: 6.9040, longitude: 79.8680, kind: "community" },
  { id: "demo-viharamahadevi-fountain", title: "Viharamahadevi Park fountain", latitude: 6.9130, longitude: 79.8610, kind: "community" },
  { id: "demo-public-library", title: "Public Library wall", latitude: 6.9113, longitude: 79.8597, kind: "community" },
  { id: "demo-nelum-pokuna", title: "Nelum Pokuna walkway", latitude: 6.9105, longitude: 79.8625, kind: "community" },
  { id: "demo-college-house", title: "College House corner", latitude: 6.9010, longitude: 79.8605, kind: "community" },
  { id: "demo-cinnamon-bean", title: "Cinnamon Bean Cafe (demo sponsor)", latitude: 6.9128, longitude: 79.8668, kind: "sponsored" },
];

function geohash(latitude, longitude, precision) {
  let minLatitude = -90, maxLatitude = 90;
  let minLongitude = -180, maxLongitude = 180;
  let hash = "";
  let characterIndex = 0;
  let bitCount = 0;
  let isLongitudeBit = true;

  while (hash.length < precision) {
    if (isLongitudeBit) {
      const middle = (minLongitude + maxLongitude) / 2;
      if (longitude >= middle) { characterIndex = characterIndex * 2 + 1; minLongitude = middle; }
      else { characterIndex = characterIndex * 2; maxLongitude = middle; }
    } else {
      const middle = (minLatitude + maxLatitude) / 2;
      if (latitude >= middle) { characterIndex = characterIndex * 2 + 1; minLatitude = middle; }
      else { characterIndex = characterIndex * 2; maxLatitude = middle; }
    }
    isLongitudeBit = !isLongitudeBit;
    bitCount += 1;

    if (bitCount === 5) {
      hash += geohashAlphabet[characterIndex];
      characterIndex = 0;
      bitCount = 0;
    }
  }
  return hash;
}

initializeApp({ credential: applicationDefault(), projectId });
const db = getFirestore();
const batch = db.batch();

for (const wall of demoWalls) {
  batch.set(db.collection("walls").doc(wall.id), {
    title: wall.title,
    latitude: wall.latitude,
    longitude: wall.longitude,
    geohash: geohash(wall.latitude, wall.longitude, geohashPrecision),
    kind: wall.kind,
    visibility: "public",
    moderationStatus: "active",
    ownerID: "aura-demo",
    isDemo: true,
    createdAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

await batch.commit();
console.log(`Seeded ${demoWalls.length} demo walls into ${projectId}.`);
