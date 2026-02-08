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

function splitUidList(raw) {
  if (typeof raw !== 'string' || !raw.trim()) {
    return new Set();
  }
  return new Set(
    raw
      .split(',')
      .map((item) => item.trim())
      .filter(Boolean),
  );
}

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

function startUtcDay(date) {
  return new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
}

function toIsoDate(value) {
  if (value === null || value === undefined) {
    return null;
  }
  if (typeof value === 'string' && value.trim() === '') {
    return null;
  }
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) {
    return null;
  }
  // Reject implausible legacy/epoch dates from weak model outputs.
  if (date.getUTCFullYear() < 2000) {
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
  const expiryInferenceISO = toIsoDate(item.expiryInferenceISO);

  if (!name) {
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
  const expiryReason = typeof item.expiryReason === 'string' && item.expiryReason.trim()
    ? item.expiryReason.trim()
    : null;

  return {
    name,
    category,
    expiryDateISO,
    expiryInferenceISO,
    expiryReason,
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
      '{ "items": [{ "name": string, "category": string, "expiryDateISO": "YYYY-MM-DD|null", "expiryInferenceISO": "YYYY-MM-DD|null", "expiryReason": string|null, "quantityValue": number|null, "quantityUnit": "pcs|g|kg|ml|l|pack|bottle|can|box|other|null", "quantityNote": string|null, "confidence": number }], "warnings": string[] }',
      'Rules:',
      '- Use date format YYYY-MM-DD.',
      '- expiryDateISO is only for clearly visible explicit dates from package labels.',
      '- if explicit date is missing, keep expiryDateISO null and optionally provide cautious expiryInferenceISO plus expiryReason.',
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
      'Items with isPerishableNoExpiry=true have unknown exact date and should be prioritized soon.',
      'Return STRICT JSON only in this format:',
      '{ "recipes": [{ "title": string, "ingredients": string[], "steps": string[], "rationale": string, "usesExpiring": string[], "pantryIngredientsUsed": string[], "missingIngredients": string[] }] }',
      `Pantry items: ${JSON.stringify(pantryItems)}`,
      'pantryIngredientsUsed must reference concrete names from pantry items when possible.',
      'missingIngredients should list ingredients user needs to acquire.',
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
        pantryIngredientsUsed: Array.isArray(recipe.pantryIngredientsUsed)
          ? recipe.pantryIngredientsUsed.map((i) => String(i))
          : [],
        missingIngredients: Array.isArray(recipe.missingIngredients)
          ? recipe.missingIngredients.map((i) => String(i))
          : [],
      })),
    };
  },
);

async function runReminderSweep({ onlyUid = null } = {}) {
  const usersQuery = db.collection('users');
  const usersSnapshot = onlyUid
    ? await usersQuery.where(admin.firestore.FieldPath.documentId(), '==', onlyUid).get()
    : await usersQuery.get();
  const now = new Date();
  const todayStart = startUtcDay(now);

  let usersEvaluated = 0;
  let notificationsAttempted = 0;
  let successCount = 0;
  let failureCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    usersEvaluated += 1;
    const uid = userDoc.id;
    const thresholdDays = Number(userDoc.get('notificationThresholdDays') ?? 3);
    const perishableReminderDays = Number(userDoc.get('perishableReminderDays') ?? 7);
    const thresholdDate = new Date(todayStart);
    thresholdDate.setUTCDate(thresholdDate.getUTCDate() + thresholdDays);
    const stalePerishableCutoff = new Date(todayStart);
    stalePerishableCutoff.setUTCDate(stalePerishableCutoff.getUTCDate() - perishableReminderDays);

    const pantrySnapshot = await db
      .collection('users')
      .doc(uid)
      .collection('pantry')
      .where('isArchived', '==', false)
      .get();

    const datedExpiringSoon = [];
    const perishableStale = [];

    for (const itemDoc of pantrySnapshot.docs) {
      const item = itemDoc.data();
      const name = typeof item.name === 'string' ? item.name : 'Item';
      const expiryDate = item.expiryDate?.toDate?.();
      const addedAt = item.addedAt?.toDate?.();
      const isPerishableNoExpiry = item.isPerishableNoExpiry === true;

      if (
        expiryDate instanceof Date &&
        expiryDate >= todayStart &&
        expiryDate <= thresholdDate
      ) {
        datedExpiringSoon.push(name);
      }

      if (
        isPerishableNoExpiry &&
        addedAt instanceof Date &&
        addedAt <= stalePerishableCutoff
      ) {
        perishableStale.push(name);
      }
    }

    if (datedExpiringSoon.length === 0 && perishableStale.length === 0) {
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

    const parts = [];
    if (datedExpiringSoon.length > 0) {
      parts.push(
        `${datedExpiringSoon.length} item(s) nearing expiry: ${datedExpiringSoon.slice(0, 3).join(', ')}`,
      );
    }
    if (perishableStale.length > 0) {
      parts.push(
        `${perishableStale.length} perishable item(s) in pantry for a while: ${perishableStale.slice(0, 3).join(', ')}`,
      );
    }

    const message = {
      notification: {
        title: 'Pantry reminder',
        body: parts.join(' | '),
      },
      android: {
        priority: 'high',
        notification: {
          channelId: 'pantry_alerts',
          priority: 'high',
          defaultSound: true,
        },
      },
      tokens,
    };

    const result = await admin.messaging().sendEachForMulticast(message);
    notificationsAttempted += 1;
    successCount += result.successCount;
    failureCount += result.failureCount;
    logger.info('Pantry reminder sent', {
      uid,
      successCount: result.successCount,
      failureCount: result.failureCount,
      datedExpiringSoon: datedExpiringSoon.length,
      perishableStale: perishableStale.length,
    });
  }

  return { usersEvaluated, notificationsAttempted, successCount, failureCount };
}

exports.sendExpiryReminders = onSchedule(
  { schedule: '0 8 * * *', timeZone: 'Etc/UTC' },
  async () => {
    await runReminderSweep();
  },
);

exports.debugSendExpiryRemindersNow = onCall(
  { timeoutSeconds: 120, memory: '512MiB' },
  async (request) => {
    requireAuth(request.auth);
    const allowedUids = splitUidList(process.env.DEBUG_CALLER_UIDS);
    if (!allowedUids.has(request.auth.uid)) {
      throw new HttpsError('permission-denied', 'Not allowed to run debug reminders.');
    }
    return runReminderSweep({ onlyUid: request.auth.uid });
  },
);

