const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp
} = require("firebase-admin/firestore");
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

exports.startParking = onCall(async (request) => {
  const userId = request.auth?.uid;
  const parkingZoneId = request.data?.parkingZoneId;
  const vehicleId = request.data?.vehicleId;
  const durationMinutes = request.data?.durationMinutes;
  const policyVersion = request.data?.policyVersion;
  const isParkedHere = request.data?.isParkedHere;
  const operationId = request.data?.operationId;

  if (!userId) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  if (
    !isValidParkingId(parkingZoneId) ||
    !isValidParkingId(vehicleId) ||
    !isValidParkingId(operationId)
  ) {
    throw new HttpsError("invalid-argument", "The parking details are not valid.");
  }

  if (
    ![30, 60, 120].includes(durationMinutes) ||
    !Number.isSafeInteger(policyVersion) ||
    policyVersion < 1 ||
    isParkedHere !== true
  ) {
    throw new HttpsError(
      "invalid-argument",
      "Choose your parking time and confirm that you are parked here."
    );
  }

  const userRef = database.collection("users").doc(userId);
  const vehicleRef = database.collection("vehicles").doc(vehicleId);
  const zoneRef = database.collection("parkingZones").doc(parkingZoneId);
  const walletRef = database.collection("wallets").doc(userId);
  const paymentRef = walletRef
    .collection("transactions")
    .doc(operationId);
  const sessionRef = database.collection("parkingSessions").doc();
  const activeSessionRef = database
    .collection("activeParkingSessions")
    .doc(userId);

  return database.runTransaction(async (transaction) => {
    const userDocument = await transaction.get(userRef);

    if (!userDocument.exists || userDocument.get("role") !== "Motorist") {
      throw new HttpsError(
        "permission-denied",
        "Only Motorists can start parking."
      );
    }

    const paymentDocument = await transaction.get(paymentRef);

    if (paymentDocument.exists) {
      const savedSessionId = paymentDocument.get("parkingSessionId");
      const savedSessionRef = isValidParkingId(savedSessionId)
        ? database.collection("parkingSessions").doc(savedSessionId)
        : null;

      if (
        paymentDocument.get("userId") !== userId ||
        paymentDocument.get("type") !== "Parking Payment" ||
        paymentDocument.get("operationId") !== operationId ||
        savedSessionRef === null
      ) {
        throw new HttpsError(
          "already-exists",
          "This operation ID was already used."
        );
      }

      const savedSessionDocument = await transaction.get(savedSessionRef);
      const savedSession = savedSessionDocument.data();

      if (
        !savedSessionDocument.exists ||
        savedSession.userId !== userId ||
        savedSession.parkingZoneId !== parkingZoneId ||
        savedSession.vehicleId !== vehicleId ||
        savedSession.durationMinutes !== durationMinutes ||
        savedSession.policyVersion !== policyVersion ||
        savedSession.operationId !== operationId ||
        paymentDocument.get("amountLKR") !== savedSession.totalPaidLKR
      ) {
        throw new HttpsError(
          "already-exists",
          "This operation ID belongs to a different parking payment."
        );
      }

      return { sessionId: savedSessionDocument.id };
    }

    const activeSessionDocument = await transaction.get(activeSessionRef);

    if (activeSessionDocument.exists) {
      throw new HttpsError(
        "failed-precondition",
        "End your current parking session before starting another one."
      );
    }

    const vehicleDocument = await transaction.get(vehicleRef);
    const zoneDocument = await transaction.get(zoneRef);
    const walletDocument = await transaction.get(walletRef);

    const vehicle = vehicleDocument.data();
    const zone = zoneDocument.data();
    const wallet = walletDocument.data();

    if (
      !vehicleDocument.exists ||
      vehicle.ownerUserId !== userId ||
      userDocument.get("primaryVehicleId") !== vehicleId ||
      typeof vehicle.licensePlate !== "string" ||
      vehicle.licensePlate.trim() === ""
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Your vehicle details are not valid."
      );
    }

    if (
      !zoneDocument.exists ||
      zone.isPublished !== true ||
      zone.isActive !== true ||
      !isValidParkingId(zone.wardenAssignmentId)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This parking zone is unavailable."
      );
    }

    if (zone.policyVersion !== policyVersion) {
      throw new HttpsError(
        "failed-precondition",
        "The parking details changed. Refresh the zone and check the price again."
      );
    }

    if (
      typeof zone.name !== "string" ||
      zone.name.trim() === "" ||
      zone.timeZoneId !== "Asia/Colombo" ||
      !Number.isSafeInteger(zone.hourlyRateLKR) ||
      zone.hourlyRateLKR <= 0 ||
      !Number.isSafeInteger(zone.maximumStayMinutes) ||
      durationMinutes > zone.maximumStayMinutes ||
      !Number.isInteger(zone.openingHour) ||
      zone.openingHour < 0 ||
      zone.openingHour > 23 ||
      !Number.isInteger(zone.closingHour) ||
      zone.closingHour <= zone.openingHour ||
      zone.closingHour > 24
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The selected parking time or zone details are not valid."
      );
    }

    const assignmentRef = database
      .collection("wardenAssignments")
      .doc(zone.wardenAssignmentId);
    const assignmentDocument = await transaction.get(assignmentRef);
    const assignment = assignmentDocument.data();

    if (
      !assignmentDocument.exists ||
      assignment.parkingZoneId !== parkingZoneId ||
      assignment.isActive !== true ||
      "endedAt" in assignment ||
      !isValidParkingId(assignment.wardenUserId)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This zone needs an active Warden."
      );
    }

    const wardenRef = database.collection("users").doc(assignment.wardenUserId);
    const wardenDocument = await transaction.get(wardenRef);

    if (!wardenDocument.exists || wardenDocument.get("role") !== "Warden") {
      throw new HttpsError(
        "failed-precondition",
        "This zone needs an approved Warden."
      );
    }

    const startDate = new Date();
    const localTime = new Intl.DateTimeFormat("en-GB", {
      timeZone: "Asia/Colombo",
      hour: "2-digit",
      minute: "2-digit",
      second: "2-digit",
      hourCycle: "h23"
    }).format(startDate);
    const [hour, minute, second] = localTime.split(":").map(Number);
    const currentSeconds =
      hour * 3600 +
      minute * 60 +
      second +
      startDate.getMilliseconds() / 1000;

    if (
      currentSeconds < zone.openingHour * 3600 ||
      currentSeconds + durationMinutes * 60 > zone.closingHour * 3600
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This parking time is outside the zone's opening hours."
      );
    }

    const priceLKR =
      durationMinutes === 30
        ? Math.ceil(zone.hourlyRateLKR / 2)
        : zone.hourlyRateLKR * (durationMinutes / 60);

    if (!Number.isSafeInteger(priceLKR) || priceLKR <= 0) {
      throw new HttpsError(
        "failed-precondition",
        "The parking price is not valid."
      );
    }

    if (
      !walletDocument.exists ||
      wallet.userId !== userId ||
      !Number.isSafeInteger(wallet.balanceLKR) ||
      wallet.balanceLKR < 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Please open your wallet first."
      );
    }

    if (wallet.balanceLKR < priceLKR) {
      throw new HttpsError(
        "failed-precondition",
        "Your demo wallet does not have enough funds."
      );
    }

    const newBalance = wallet.balanceLKR - priceLKR;
    const startTime = Timestamp.fromDate(startDate);
    const paidUntil = Timestamp.fromMillis(
      startDate.getTime() + durationMinutes * 60 * 1000
    );

    transaction.update(walletRef, {
      balanceLKR: newBalance
    });

    transaction.create(sessionRef, {
      userId: userId,
      vehicleId: vehicleId,
      parkingZoneId: parkingZoneId,
      zoneName: zone.name,
      licensePlate: vehicle.licensePlate.trim(),
      startTime: startTime,
      paidUntil: paidUntil,
      durationMinutes: durationMinutes,
      hourlyRateLKR: zone.hourlyRateLKR,
      policyVersion: zone.policyVersion,
      totalPaidLKR: priceLKR,
      isActive: true,
      operationId: operationId
    });

    transaction.create(paymentRef, {
      userId: userId,
      type: "Parking Payment",
      amountLKR: priceLKR,
      balanceAfterLKR: newBalance,
      createdAt: FieldValue.serverTimestamp(),
      operationId: operationId,
      parkingSessionId: sessionRef.id
    });

    transaction.create(activeSessionRef, {
      userId: userId,
      vehicleId: vehicleId,
      parkingSessionId: sessionRef.id
    });

    return { sessionId: sessionRef.id };
  });
});

function isValidParkingId(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}
