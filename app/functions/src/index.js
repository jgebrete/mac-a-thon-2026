const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onSchedule } = require('firebase-functions/v2/scheduler');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

const DEFAULT_MODEL = 'gemini-3-flash-preview';
const QUANTITY_UNITS = new Set([
  'pcs',
  'g',
  'kg',
  'ml',
  'l',
  'pack',
  'bottle',
  'can',
  'box',
  'other',
]);

function requireAuth(auth) {
  if (!auth) {
    throw new HttpsError('unauthenticated', 'Authentication required.');
  }
}

function geminiModel() {
  return process.env.GEMINI_MODEL || DEFAULT_MODEL;
}

function geminiApiKey() {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    throw new HttpsError('failed-precondition', 'Missing GEMINI_API_KEY.');
  }
  return apiKey;
}

function stripCodeFence(input) {
  return input
    .replace(/^```json\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
}

function parseGeminiJson(text) {
  try {
    return JSON.parse(stripCodeFence(text));
  } catch (error) {
    throw new HttpsError('internal', `Gemini JSON parse failed: ${error.message}`);
  }
}

function toIsoDate(value) {
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  return date.toISOString().slice(0, 10);
}

function sanitizeDetectedItem(item) {
  const name = typeof item.name === 'string' ? item.name.trim() : '';
  const category = typeof item.category === 'string' && item.category.trim()
    ? item.category.trim()
    : 'Other';
  const expiryDateISO = toIsoDate(item.expiryDateISO);

  if (!name || !expiryDateISO) {
    return null;
  }

  const quantityValue = Number.isFinite(Number(item.quantityValue))
    ? Number(item.quantityValue)
    : null;
  const rawUnit = typeof item.quantityUnit === 'string' ? item.quantityUnit.trim().toLowerCase() : null;
  const quantityUnit = rawUnit && QUANTITY_UNITS.has(rawUnit) ? rawUnit : (rawUnit ? 'other' : null);
  const quantityNote = typeof item.quantityNote === 'string' && item.quantityNote.trim()
    ? item.quantityNote.trim()
    : null;
  const confidence = Number.isFinite(Number(item.confidence))
    ? Math.max(0, Math.min(1, Number(item.confidence)))
    : 0;

  return {
    name,
    category,
    expiryDateISO,
    quantityValue,
    quantityUnit,
    quantityNote,
    confidence,
  };
}

async function callGemini({ prompt, imageBase64, mimeType }) {
  const model = geminiModel();
  const apiKey = geminiApiKey();
  const endpoint = `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${apiKey}`;

  const payload = {
    contents: [
      {
        role: 'user',
        parts: [
          { text: prompt },
          ...(imageBase64
            ? [{ inline_data: { mime_type: mimeType || 'image/jpeg', data: imageBase64 } }]
            : []),
        ],
      },
    ],
    generationConfig: {
      responseMimeType: 'application/json',
      temperature: 0.2,
    },
  };

  const response = await fetch(endpoint, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!response.ok) {
    const body = await response.text();
    throw new HttpsError('internal', `Gemini API error ${response.status}: ${body}`);
  }

  const body = await response.json();
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text;
  if (!text) {
    throw new HttpsError('internal', 'Gemini returned empty response.');
  }

  return parseGeminiJson(text);
}

exports.extractPantryItemsFromImage = onCall(
  { timeoutSeconds: 60, memory: '512MiB' },
  async (request) => {
    requireAuth(request.auth);

    const imageBase64 = request.data?.imageBase64;
    const mimeType = request.data?.mimeType;

    if (typeof imageBase64 !== 'string' || !imageBase64.trim()) {
      throw new HttpsError('invalid-argument', 'imageBase64 is required.');
    }

    const prompt = [
      'You are extracting pantry item data from one food image.',
      'Return STRICT JSON only with this shape:',
      '{ "items": [{ "name": string, "category": string, "expiryDateISO": "YYYY-MM-DD", "quantityValue": number|null, "quantityUnit": "pcs|g|kg|ml|l|pack|bottle|can|box|other|null", "quantityNote": string|null, "confidence": number }], "warnings": string[] }',
      'Rules:',
      '- Use date format YYYY-MM-DD.',
      '- If unsure, add warning.',
      '- Do not include markdown.',
    ].join('\n');

    const data = await callGemini({ prompt, imageBase64, mimeType });

    const rawItems = Array.isArray(data.items) ? data.items : [];
    const items = rawItems.map(sanitizeDetectedItem).filter(Boolean);
    const warnings = Array.isArray(data.warnings)
      ? data.warnings.map((item) => String(item))
      : [];

    return { items, warnings };
  },
);

exports.generateRecipeFromPantry = onCall(
  { timeoutSeconds: 60, memory: '512MiB' },
  async (request) => {
    requireAuth(request.auth);

    const pantryItems = Array.isArray(request.data?.pantryItems)
      ? request.data.pantryItems
      : [];
    if (pantryItems.length === 0) {
      throw new HttpsError('invalid-argument', 'pantryItems is required.');
    }

    const prompt = [
      'You are a cooking assistant.',
      'Given pantry items JSON, suggest up to 3 recipes prioritizing near-expiry ingredients.',
      'Return STRICT JSON only in this format:',
      '{ "recipes": [{ "title": string, "ingredients": string[], "steps": string[], "rationale": string, "usesExpiring": string[] }] }',
      `Pantry items: ${JSON.stringify(pantryItems)}`,
      'Do not include markdown.',
    ].join('\n');

    const data = await callGemini({ prompt });
    const recipes = Array.isArray(data.recipes) ? data.recipes : [];

    return {
      recipes: recipes.map((recipe) => ({
        title: typeof recipe.title === 'string' ? recipe.title : 'Untitled Recipe',
        ingredients: Array.isArray(recipe.ingredients)
          ? recipe.ingredients.map((i) => String(i))
          : [],
        steps: Array.isArray(recipe.steps) ? recipe.steps.map((s) => String(s)) : [],
        rationale: typeof recipe.rationale === 'string' ? recipe.rationale : '',
        usesExpiring: Array.isArray(recipe.usesExpiring)
          ? recipe.usesExpiring.map((i) => String(i))
          : [],
      })),
    };
  },
);

exports.sendExpiryReminders = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'Etc/UTC' },
  async () => {
    const usersSnapshot = await db.collection('users').get();
    const now = new Date();
    const todayStart = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));

    for (const userDoc of usersSnapshot.docs) {
      const uid = userDoc.id;
      const thresholdDays = Number(userDoc.get('notificationThresholdDays') ?? 3);
      const thresholdDate = new Date(todayStart);
      thresholdDate.setUTCDate(thresholdDate.getUTCDate() + thresholdDays);

      const pantrySnapshot = await db
        .collection('users')
        .doc(uid)
        .collection('pantry')
        .where('isArchived', '==', false)
        .where('expiryDate', '>=', admin.firestore.Timestamp.fromDate(todayStart))
        .where('expiryDate', '<=', admin.firestore.Timestamp.fromDate(thresholdDate))
        .get();

      if (pantrySnapshot.empty) {
        continue;
      }

      const tokenSnapshot = await db
        .collection('users')
        .doc(uid)
        .collection('tokens')
        .get();

      const tokens = tokenSnapshot.docs
        .map((doc) => doc.get('token'))
        .filter((token) => typeof token === 'string' && token.length > 0);

      if (tokens.length === 0) {
        continue;
      }

      const items = pantrySnapshot.docs
        .map((doc) => doc.get('name'))
        .filter((name) => typeof name === 'string')
        .slice(0, 5);

      const message = {
        notification: {
          title: 'Food nearing expiry',
          body: `${pantrySnapshot.size} item(s) nearing expiry: ${items.join(', ')}`,
        },
        tokens,
      };

      const result = await admin.messaging().sendEachForMulticast(message);
      logger.info('Expiry reminder sent', {
        uid,
        successCount: result.successCount,
        failureCount: result.failureCount,
      });
    }
  },
);

