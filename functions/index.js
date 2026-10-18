const { initializeApp } = require("firebase-admin/app");
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

initializeApp();

const database = getFirestore();

exports.checkConnection = onCall((request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  return { message: "SpotShield backend is ready." };
});

exports.topUpWallet = onCall(async (request) => {
  const userId = request.auth?.uid;
  const amountLKR = request.data?.amountLKR;
  const operationId = request.data?.operationId;

  if (!userId) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  if (
    !Number.isSafeInteger(amountLKR) ||
    amountLKR <= 0 ||
    amountLKR > 10000
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Enter a demo amount from LKR 1 to LKR 10,000."
    );
  }

  if (
    typeof operationId !== "string" ||
    operationId.trim() === "" ||
    operationId.includes("/") ||
    operationId.length > 128
  ) {
    throw new HttpsError("invalid-argument", "The operation ID is not valid.");
  }

  const userRef = database.collection("users").doc(userId);
  const walletRef = database.collection("wallets").doc(userId);
  const transactionRef = walletRef
    .collection("transactions")
    .doc(operationId);

  return database.runTransaction(async (transaction) => {
    const user = await transaction.get(userRef);

    if (!user.exists || user.get("role") !== "Motorist") {
      throw new HttpsError(
        "permission-denied",
        "Only Motorists can add demo funds."
      );
    }

    const previousTransaction = await transaction.get(transactionRef);

    if (previousTransaction.exists) {
      const previousBalance = previousTransaction.get("balanceAfterLKR");

      if (
        previousTransaction.get("userId") !== userId ||
        previousTransaction.get("type") !== "Top Up" ||
        previousTransaction.get("amountLKR") !== amountLKR ||
        previousTransaction.get("operationId") !== operationId ||
        !Number.isSafeInteger(previousBalance)
      ) {
        throw new HttpsError(
          "already-exists",
          "This operation ID was already used."
        );
      }

      return {
        balanceLKR: previousBalance,
        operationId: operationId
      };
    }

    const wallet = await transaction.get(walletRef);

    if (!wallet.exists || wallet.get("userId") !== userId) {
      throw new HttpsError(
        "failed-precondition",
        "Create your wallet before adding demo funds."
      );
    }

    const currentBalance = wallet.get("balanceLKR");

    if (!Number.isSafeInteger(currentBalance) || currentBalance < 0) {
      throw new HttpsError(
        "failed-precondition",
        "The wallet balance is not valid."
      );
    }

    const newBalance = currentBalance + amountLKR;

    if (!Number.isSafeInteger(newBalance)) {
      throw new HttpsError(
        "failed-precondition",
        "The new wallet balance is too large."
      );
    }

    transaction.update(walletRef, {
      balanceLKR: newBalance
    });

    transaction.create(transactionRef, {
      userId: userId,
      type: "Top Up",
      amountLKR: amountLKR,
      balanceAfterLKR: newBalance,
      createdAt: FieldValue.serverTimestamp(),
      operationId: operationId
    });

    return {
      balanceLKR: newBalance,
      operationId: operationId
    };
  });
});
