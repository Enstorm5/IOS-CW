import { readFileSync } from "node:fs";
import { applicationDefault } from "firebase-admin/app";

const projectId = "uni-ios-a6b5f";
const base = `https://firestore.googleapis.com/v1/projects/${projectId}/databases/(default)/collectionGroups`;
const config = JSON.parse(readFileSync(new URL("../firestore.indexes.json", import.meta.url), "utf8"));
const { access_token: token } = await applicationDefault().getAccessToken();
const headers = { Authorization: `Bearer ${token}`, "Content-Type": "application/json" };

for (const index of config.indexes) {
  const response = await fetch(`${base}/${index.collectionGroup}/indexes`, {
    method: "POST",
    headers,
    body: JSON.stringify({ queryScope: index.queryScope, fields: index.fields.map(({ fieldPath, order }) => ({ fieldPath, order })) }),
  });
  const body = await response.json();
  const fields = index.fields.map((field) => field.fieldPath).join(" + ");
  if (response.ok) console.log(`Creating index ${index.collectionGroup}: ${fields}`);
  else if (body.error?.status === "ALREADY_EXISTS") console.log(`Already exists ${index.collectionGroup}: ${fields}`);
  else console.log(`Failed ${index.collectionGroup}: ${fields}: ${body.error?.message}`);
}

for (const override of config.fieldOverrides ?? []) {
  const response = await fetch(`${base}/${override.collectionGroup}/fields/${override.fieldPath}?updateMask=indexConfig`, {
    method: "PATCH",
    headers,
    body: JSON.stringify({
      indexConfig: {
        indexes: override.indexes.map((index) => ({
          queryScope: index.queryScope,
          fields: [{ fieldPath: override.fieldPath, order: index.order }],
        })),
      },
    }),
  });
  const body = await response.json();
  console.log(response.ok
    ? `Updating field index ${override.collectionGroup}.${override.fieldPath}`
    : `Failed field index ${override.collectionGroup}.${override.fieldPath}: ${body.error?.message}`);
}
