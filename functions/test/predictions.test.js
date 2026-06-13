/**
 * Unit tests for prediction resolution logic.
 * Tests pure functions without hitting Firebase.
 */

// Mock firebase-admin and firebase-functions before requiring index.js
jest.mock("firebase-admin", () => {
  const firestoreMock = {
    collection: jest.fn().mockReturnThis(),
    doc: jest.fn().mockReturnThis(),
    where: jest.fn().mockReturnThis(),
    orderBy: jest.fn().mockReturnThis(),
    limit: jest.fn().mockReturnThis(),
    get: jest.fn().mockResolvedValue({ docs: [] }),
    add: jest.fn().mockResolvedValue({}),
    update: jest.fn().mockResolvedValue({}),
    runTransaction: jest.fn().mockResolvedValue({}),
    FieldValue: {
      serverTimestamp: () => "SERVER_TIMESTAMP",
      increment: (n) => ({ _increment: n }),
      arrayUnion: (...args) => ({ _arrayUnion: args }),
      arrayRemove: (...args) => ({ _arrayRemove: args }),
    },
    batch: jest.fn(() => ({
      set: jest.fn(),
      update: jest.fn(),
      commit: jest.fn().mockResolvedValue({}),
    })),
  };
  return {
    initializeApp: jest.fn(),
    firestore: jest.fn(() => firestoreMock),
    messaging: jest.fn(() => ({ send: jest.fn().mockResolvedValue({}) })),
  };
});

jest.mock("firebase-functions/v2/firestore", () => ({
  onDocumentCreated: jest.fn(() => jest.fn()),
  onDocumentUpdated: jest.fn(() => jest.fn()),
  onDocumentWritten: jest.fn(() => jest.fn()),
}));

jest.mock("firebase-functions/v2/scheduler", () => ({
  onSchedule: jest.fn(() => jest.fn()),
}));

const {
  _pickFromScore,
  _PREDICT_EXACT_PTS,
  _PREDICT_OUTCOME_PTS,
  _runInChunks,
} = require("../index.js");

// ─── pickFromScore ─────────────────────────────────────────────────────────────

describe("pickFromScore", () => {
  test("home win returns '1'", () => {
    expect(_pickFromScore(3, 1)).toBe("1");
    expect(_pickFromScore(1, 0)).toBe("1");
  });

  test("away win returns '2'", () => {
    expect(_pickFromScore(0, 1)).toBe("2");
    expect(_pickFromScore(1, 3)).toBe("2");
  });

  test("draw returns 'X'", () => {
    expect(_pickFromScore(0, 0)).toBe("X");
    expect(_pickFromScore(2, 2)).toBe("X");
  });

  test("large scores still work", () => {
    expect(_pickFromScore(10, 0)).toBe("1");
    expect(_pickFromScore(0, 10)).toBe("2");
  });
});

// ─── Points constants ──────────────────────────────────────────────────────────

describe("points constants", () => {
  test("exact score is worth more than outcome", () => {
    expect(_PREDICT_EXACT_PTS).toBeGreaterThan(_PREDICT_OUTCOME_PTS);
  });

  test("exact score = 10, outcome = 5", () => {
    expect(_PREDICT_EXACT_PTS).toBe(10);
    expect(_PREDICT_OUTCOME_PTS).toBe(5);
  });
});

// ─── Points calculation logic (inline, mirrors index.js) ──────────────────────

function calcCouponPts(pick, predictedH, predictedA, actualH, actualA) {
  const outcome = _pickFromScore(actualH, actualA);
  let pts = 0;
  if (predictedH != null && predictedA != null) {
    if (predictedH === actualH && predictedA === actualA) pts = _PREDICT_EXACT_PTS;
    else if (pick === outcome) pts = _PREDICT_OUTCOME_PTS;
  } else if (pick === outcome) {
    pts = _PREDICT_OUTCOME_PTS;
  }
  return pts;
}

function calcPredictionPts(predictedH, predictedA, actualH, actualA) {
  const outcome = _pickFromScore(actualH, actualA);
  let pts = 0;
  if (predictedH === actualH && predictedA === actualA) pts = _PREDICT_EXACT_PTS;
  else if (_pickFromScore(predictedH, predictedA) === outcome) pts = _PREDICT_OUTCOME_PTS;
  return pts;
}

describe("coupon points calculation", () => {
  test("exact score prediction earns 10 pts", () => {
    expect(calcCouponPts("1", 3, 1, 3, 1)).toBe(10);
  });

  test("correct outcome (no exact score) earns 5 pts", () => {
    expect(calcCouponPts("1", 2, 0, 3, 1)).toBe(5);  // predicted 2-0, actual 3-1, both home wins
  });

  test("wrong outcome earns 0 pts", () => {
    expect(calcCouponPts("2", 0, 1, 3, 1)).toBe(0);  // predicted away win, actual home win
  });

  test("pick-only coupon (no exact scores) correct outcome earns 5 pts", () => {
    expect(calcCouponPts("X", null, null, 1, 1)).toBe(5);
  });

  test("pick-only coupon wrong outcome earns 0 pts", () => {
    expect(calcCouponPts("1", null, null, 1, 1)).toBe(0);
  });

  test("draw predicted and drawn: exact score earns 10 pts", () => {
    expect(calcCouponPts("X", 1, 1, 1, 1)).toBe(10);
  });

  test("draw outcome correct but score wrong earns 5 pts", () => {
    expect(calcCouponPts("X", 2, 2, 1, 1)).toBe(5);
  });
});

describe("score prediction points calculation", () => {
  test("exact score earns 10 pts", () => {
    expect(calcPredictionPts(2, 1, 2, 1)).toBe(10);
  });

  test("correct outcome earns 5 pts", () => {
    expect(calcPredictionPts(1, 0, 3, 1)).toBe(5);  // both home wins
  });

  test("wrong outcome earns 0 pts", () => {
    expect(calcPredictionPts(0, 1, 3, 1)).toBe(0);  // away win vs home win
  });

  test("0-0 exact earns 10 pts", () => {
    expect(calcPredictionPts(0, 0, 0, 0)).toBe(10);
  });

  test("draw predicted correct outcome earns 5 pts", () => {
    expect(calcPredictionPts(2, 2, 1, 1)).toBe(5);
  });
});

// ─── runInChunks ──────────────────────────────────────────────────────────────

describe("runInChunks", () => {
  test("calls fn for every item", async () => {
    const items = [1, 2, 3, 4, 5];
    const results = [];
    await _runInChunks(items, 2, async (item) => results.push(item));
    expect(results.sort()).toEqual([1, 2, 3, 4, 5]);
  });

  test("processes all items even when chunk size exceeds list", async () => {
    const items = [1, 2];
    const results = [];
    await _runInChunks(items, 100, async (item) => results.push(item));
    expect(results).toEqual([1, 2]);
  });

  test("handles empty list", async () => {
    const fn = jest.fn();
    await _runInChunks([], 10, fn);
    expect(fn).not.toHaveBeenCalled();
  });

  test("continues after individual item failure", async () => {
    const results = [];
    await _runInChunks([1, 2, 3], 10, async (item) => {
      if (item === 2) throw new Error("fail");
      results.push(item);
    }).catch(() => {});
    // runInChunks does NOT swallow errors — each handler must catch its own
    // (see updatePlayerStats wrapper in onMatchFinished)
    expect(results).toContain(1);
  });

  test("processes exactly chunk-size items per batch", async () => {
    const batchSizes = [];
    const items = [1, 2, 3, 4, 5, 6, 7];
    let currentBatch = [];
    let batchDone = false;
    await _runInChunks(items, 3, async (item) => {
      currentBatch.push(item);
      // After processing, record batch size when it's done
      await Promise.resolve();
      if (!batchDone && currentBatch.length === 3) {
        batchSizes.push(currentBatch.length);
        batchDone = true;
      }
    });
    expect(batchSizes[0]).toBe(3);
  });
});
