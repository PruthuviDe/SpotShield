const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { isValidParkingId } = require("./parkingHelpers");

const database = getFirestore();
const ticketFineLKR = 1000;

function ticketPaymentRefFor(userId, ticketId) {
  return database.collection("wallets").doc(userId)
    .collection("transactions").doc("ticket-payment-" + ticketId);
}

exports.ticketFineLKR = ticketFineLKR;
exports.ticketPaymentRefFor = ticketPaymentRefFor;

exports.setTicketAutoDeduct = onCall(async request => {
  const userId = request.auth?.uid;
  const enabled = request.data?.enabled;
  if (!userId) throw new HttpsError("unauthenticated", "Please sign in first.");
  if (typeof enabled !== "boolean") {
    throw new HttpsError("invalid-argument", "Choose whether auto-deduction is on or off.");
  }

  const userRef = database.collection("users").doc(userId);
  const walletRef = database.collection("wallets").doc(userId);
  return database.runTransaction(async transaction => {
    const user = await transaction.get(userRef);
    if (!user.exists || user.get("role") !== "Motorist") {
      throw new HttpsError("permission-denied", "Only Motorists can change this setting.");
    }
    const wallet = await transaction.get(walletRef);
    if (!wallet.exists || wallet.get("userId") !== userId) {
      throw new HttpsError("failed-precondition", "Open your wallet before changing this setting.");
    }
    transaction.update(walletRef, { autoDeductEnabled: enabled });
    return { enabled: enabled };
  });
});

exports.payTicket = onCall(async request => {
  const userId = request.auth?.uid;
  const ticketId = request.data?.ticketId;
  if (!userId) throw new HttpsError("unauthenticated", "Please sign in first.");
  if (!isValidParkingId(ticketId)) {
    throw new HttpsError("invalid-argument", "Choose a valid ticket.");
  }

  const userRef = database.collection("users").doc(userId);
  const ticketRef = database.collection("simulatedTickets").doc(ticketId);
  const walletRef = database.collection("wallets").doc(userId);
  const paymentRef = ticketPaymentRefFor(userId, ticketId);
  const operationId = paymentRef.id;

  return database.runTransaction(async transaction => {
    const user = await transaction.get(userRef);
    if (!user.exists || user.get("role") !== "Motorist") {
      throw new HttpsError("permission-denied", "Only Motorists can pay demo tickets.");
    }

    const ticket = await transaction.get(ticketRef);
    if (!ticket.exists || ticket.get("userId") !== userId) {
      throw new HttpsError("not-found", "This ticket is not linked to your account.");
    }

    const previousPayment = await transaction.get(paymentRef);
    if (ticket.get("paymentStatus") === "Paid") {
      if (!previousPayment.exists) {
        throw new HttpsError("failed-precondition", "The saved payment record needs Admin review.");
      }
      const previousAmount = previousPayment.get("amountLKR");
      const previousBalance = previousPayment.get("balanceAfterLKR");
      if (previousPayment.get("type") !== "Ticket Payment" ||
          previousPayment.get("userId") !== userId ||
          previousPayment.get("ticketId") !== ticketId ||
          !Number.isSafeInteger(previousAmount) ||
          previousAmount !== ticket.get("fineAmountLKR") ||
          !Number.isSafeInteger(previousBalance) || previousBalance < 0) {
        throw new HttpsError("failed-precondition", "The saved payment record needs Admin review.");
      }
      return {
        ticketId: ticketId,
        paymentStatus: "Paid",
        balanceLKR: previousBalance,
        operationId: operationId
      };
    }

    if (ticket.get("paymentStatus") !== "Due") {
      throw new HttpsError("failed-precondition", "This ticket cannot be paid in its current state.");
    }
    if (previousPayment.exists) {
      throw new HttpsError("failed-precondition", "A payment record already exists. Refresh the ticket.");
    }

    const wallet = await transaction.get(walletRef);
    if (!wallet.exists || wallet.get("userId") !== userId) {
      throw new HttpsError("failed-precondition", "Create your wallet before paying this ticket.");
    }
    const balanceLKR = wallet.get("balanceLKR");
    const amountLKR = ticket.get("fineAmountLKR");
    if (!Number.isSafeInteger(balanceLKR) || balanceLKR < 0 ||
        !Number.isSafeInteger(amountLKR) || amountLKR <= 0) {
      throw new HttpsError("failed-precondition", "The wallet or ticket amount cannot be verified.");
    }
    if (balanceLKR < amountLKR) {
      throw new HttpsError("failed-precondition", "Not enough demo funds. Add funds and try again.");
    }

    const newBalanceLKR = balanceLKR - amountLKR;
    transaction.update(walletRef, { balanceLKR: newBalanceLKR });
    transaction.update(ticketRef, {
      paymentStatus: "Paid",
      paymentMethod: "Manual",
      paymentMessage: "Paid from your demo wallet."
    });
    transaction.create(paymentRef, {
      userId: userId,
      type: "Ticket Payment",
      amountLKR: amountLKR,
      balanceAfterLKR: newBalanceLKR,
      createdAt: FieldValue.serverTimestamp(),
      operationId: operationId,
      ticketId: ticketId
    });
    return {
      ticketId: ticketId,
      paymentStatus: "Paid",
      balanceLKR: newBalanceLKR,
      operationId: operationId
    };
  });
});
