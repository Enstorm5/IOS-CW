import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";

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

const demoMessages = [
  { wallID: "demo-viharamahadevi-fountain", id: "demo-message-1", authorName: "Mira", text: "best flat white in town", color: "yellow", sparkCount: 12, minutesAgo: 5, x: 0.18, y: 0.22 },
  { wallID: "demo-viharamahadevi-fountain", id: "demo-message-2", authorName: "Dev", text: "exam week survivors", color: "mint", sparkCount: 8, minutesAgo: 40, x: 0.55, y: 0.48 },
  { wallID: "demo-viharamahadevi-fountain", id: "demo-message-3", authorName: "Sam", text: "meet here at 6?", color: "magenta", sparkCount: 3, minutesAgo: 90, x: 0.3, y: 0.75 },
  { wallID: "demo-public-library", id: "demo-message-4", authorName: "Ishara", text: "quiet corner on the 2nd floor", color: "mint", sparkCount: 5, minutesAgo: 15, x: 0.2, y: 0.3 },
  { wallID: "demo-public-library", id: "demo-message-5", authorName: "Kavin", text: "returned my books late again", color: "ink", sparkCount: 2, minutesAgo: 120, x: 0.6, y: 0.6 },
  { wallID: "demo-cinnamon-bean", id: "demo-message-6", authorName: "Nadia", text: "the cinnamon bun is worth it", color: "yellow", sparkCount: 9, minutesAgo: 25, x: 0.4, y: 0.35 },
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

for (const message of demoMessages) {
  batch.set(db.collection("walls").doc(message.wallID).collection("messages").doc(message.id), {
    authorID: "aura-demo",
    authorName: message.authorName,
    text: message.text,
    contentType: "text",
    color: message.color,
    sparkCount: message.sparkCount,
    normalizedX: message.x,
    normalizedY: message.y,
    moderationStatus: "active",
    isDemo: true,
    createdAt: Timestamp.fromMillis(Date.now() - message.minutesAgo * 60 * 1000),
    updatedAt: FieldValue.serverTimestamp(),
  });
}

await batch.commit();
console.log(`Seeded ${demoWalls.length} demo walls and ${demoMessages.length} demo messages into ${projectId}.`);
