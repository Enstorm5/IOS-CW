import { readFileSync } from "node:fs";
import { initializeApp, applicationDefault } from "firebase-admin/app";
import { getSecurityRules } from "firebase-admin/security-rules";

const projectId = "uni-ios-a6b5f";
const rulesPath = new URL("../firestore.rules", import.meta.url);

initializeApp({ credential: applicationDefault(), projectId });
const source = readFileSync(rulesPath, "utf8");
const ruleset = await getSecurityRules().releaseFirestoreRulesetFromSource(source);
console.log(`Published Firestore rules ${ruleset.name} to ${projectId} at ${ruleset.createTime}.`);
