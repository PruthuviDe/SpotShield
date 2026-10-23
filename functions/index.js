const { initializeApp } = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  Timestamp
} = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");

initializeApp();

const database = getFirestore();
const { isValidParkingId, normalizePlate, plateKey, readPlateVehicle, readPlateSessions, parkingPrice, parkingHours, checkWardenCoverage } = require("./parkingHelpers");


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

      if (
        paymentDocument.get("userId") !== userId ||
        paymentDocument.get("type") !== "Parking Payment" ||
        paymentDocument.get("operationId") !== operationId ||
        !isValidParkingId(savedSessionId)
      ) {
        throw new HttpsError(
          "already-exists",
          "This operation ID was already used."
        );
      }

      const savedSessionRef = database
        .collection("parkingSessions")
        .doc(savedSessionId);
      const savedSessionDocument = await transaction.get(savedSessionRef);

      if (!savedSessionDocument.exists) {
        throw new HttpsError(
          "failed-precondition",
          "The original parking session could not be found."
        );
      }

      const savedSession = savedSessionDocument.data();
      const originalMinutes =
        paymentDocument.get("durationMinutes") ?? savedSession.durationMinutes;
      const originalPriceLKR = parkingPrice(
        savedSession.hourlyRateLKR,
        durationMinutes
      );

      if (
        savedSession.userId !== userId ||
        savedSession.parkingZoneId !== parkingZoneId ||
        savedSession.vehicleId !== vehicleId ||
        savedSession.policyVersion !== policyVersion ||
        savedSession.operationId !== operationId ||
        originalMinutes !== durationMinutes ||
        !Number.isSafeInteger(savedSession.hourlyRateLKR) ||
        savedSession.hourlyRateLKR <= 0 ||
        !Number.isSafeInteger(originalPriceLKR) ||
        originalPriceLKR <= 0 ||
        paymentDocument.get("amountLKR") !== originalPriceLKR
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

    const plate = normalizePlate(vehicle.licensePlate);
    if (!plate) throw new HttpsError("failed-precondition", "Your saved license plate is not valid.");
    const plateRef = database.collection("vehiclePlates").doc(plateKey(plate));
    const plateRecord = await transaction.get(plateRef);
    const registeredVehicle = await readPlateVehicle(transaction, plate);
    if (!registeredVehicle || registeredVehicle.id !== vehicleId ||
        (plateRecord.exists && plateRecord.get("ownerUserId") &&
         (plateRecord.get("ownerUserId") !== userId || plateRecord.get("vehicleId") !== vehicleId))) {
      throw new HttpsError("failed-precondition", "This plate's account link needs Admin review.");
    }
    const plateSessions = await readPlateSessions(transaction, plate);
    if (plateRecord.get("activeSessionId") || plateSessions.length > 0) {
      throw new HttpsError("failed-precondition", "This plate already has an open session. End it before starting another one.");
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

    await checkWardenCoverage(transaction, parkingZoneId, zone.wardenAssignmentId);

    const startDate = new Date();
    const hours = parkingHours(startDate, zone.openingHour, zone.closingHour, zone.timeZoneId);

    if (
      startDate.getTime() < hours.openingTimeMillis ||
      startDate.getTime() + durationMinutes * 60000 > hours.closingTimeMillis
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This parking time is outside the zone's opening hours."
      );
    }

    const priceLKR = parkingPrice(zone.hourlyRateLKR, durationMinutes);

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
      licensePlate: plate,
      startTime: startTime,
      paidUntil: paidUntil,
      durationMinutes: durationMinutes,
      hourlyRateLKR: zone.hourlyRateLKR,
      policyVersion: zone.policyVersion,
      totalPaidLKR: priceLKR,
      isActive: true,
      operationId: operationId,
      maximumStayMinutes: zone.maximumStayMinutes,
      openingHour: zone.openingHour,
      closingHour: zone.closingHour,
      timeZoneId: zone.timeZoneId
    });

    transaction.create(paymentRef, {
      userId: userId,
      type: "Parking Payment",
      amountLKR: priceLKR,
      durationMinutes: durationMinutes,
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

    transaction.set(plateRef, {
      ownerUserId: userId,
      vehicleId: vehicleId,
      licensePlate: plate,
      activeSessionId: sessionRef.id
    });

    return { sessionId: sessionRef.id };
  });
});

exports.endParking = onCall(async (request) => {
  const userId = request.auth?.uid;
  const sessionId = request.data?.sessionId;

  if (!userId) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  if (!isValidParkingId(sessionId)) {
    throw new HttpsError(
      "invalid-argument",
      "The parking session ID is not valid."
    );
  }

  const userRef = database.collection("users").doc(userId);
  const sessionRef = database.collection("parkingSessions").doc(sessionId);
  const activeSessionRef = database
    .collection("activeParkingSessions")
    .doc(userId);

  return database.runTransaction(async (transaction) => {
    const userDocument = await transaction.get(userRef);

    if (!userDocument.exists || userDocument.get("role") !== "Motorist") {
      throw new HttpsError(
        "permission-denied",
        "Only Motorists can end parking."
      );
    }

    const sessionDocument = await transaction.get(sessionRef);

    if (!sessionDocument.exists) {
      throw new HttpsError(
        "not-found",
        "The parking session could not be found."
      );
    }

    const session = sessionDocument.data();

    if (session.userId !== userId) {
      throw new HttpsError(
        "permission-denied",
        "This parking session does not belong to you."
      );
    }

    if (!(session.startTime instanceof Timestamp)) {
      throw new HttpsError(
        "failed-precondition",
        "The parking start time is not valid."
      );
    }

    if (session.isActive === false) {
      if (
        !(session.endTime instanceof Timestamp) ||
        session.endTime.toMillis() < session.startTime.toMillis()
      ) {
        throw new HttpsError(
          "failed-precondition",
          "The saved parking end time is not valid."
        );
      }

      return { sessionId: sessionId, ended: true };
    }

    if (
      session.isActive !== true ||
      "endTime" in session ||
      session.startTime.toMillis() > Timestamp.now().toMillis()
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The parking session details are not valid."
      );
    }

    const activeDocument = await transaction.get(activeSessionRef);

    if (
      !activeDocument.exists ||
      activeDocument.get("userId") !== userId ||
      activeDocument.get("parkingSessionId") !== sessionId ||
      activeDocument.get("vehicleId") !== session.vehicleId
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Your active parking record does not match. Please refresh."
      );
    }

    const plateRef = database.collection("vehiclePlates").doc(plateKey(session.licensePlate));
    const plateRecord = await transaction.get(plateRef);

    transaction.update(sessionRef, {
      isActive: false,
      endTime: FieldValue.serverTimestamp()
    });

    transaction.delete(activeSessionRef);
    if (plateRecord.exists && plateRecord.get("activeSessionId") === sessionId) {
      transaction.update(plateRef, { activeSessionId: FieldValue.delete() });
    }

    return { sessionId: sessionId, ended: true };
  });
});

exports.extendParking = onCall(async (request) => {
  const userId = request.auth?.uid;
  const sessionId = request.data?.sessionId;
  const additionalMinutes = request.data?.additionalMinutes;
  const expectedDurationMinutes = request.data?.expectedDurationMinutes;
  const operationId = request.data?.operationId;

  if (!userId) {
    throw new HttpsError("unauthenticated", "Please sign in first.");
  }

  if (
    !isValidParkingId(sessionId) ||
    !isValidParkingId(operationId) ||
    ![30, 60, 120].includes(additionalMinutes) ||
    !Number.isSafeInteger(expectedDurationMinutes) ||
    expectedDurationMinutes <= 0
  ) {
    throw new HttpsError(
      "invalid-argument",
      "The parking extension details are not valid."
    );
  }

  const userRef = database.collection("users").doc(userId);
  const sessionRef = database.collection("parkingSessions").doc(sessionId);
  const activeSessionRef = database
    .collection("activeParkingSessions")
    .doc(userId);
  const walletRef = database.collection("wallets").doc(userId);
  const paymentRef = walletRef.collection("transactions").doc(operationId);

  return database.runTransaction(async (transaction) => {
    const userDocument = await transaction.get(userRef);

    if (!userDocument.exists || userDocument.get("role") !== "Motorist") {
      throw new HttpsError(
        "permission-denied",
        "Only Motorists can extend parking."
      );
    }

    const sessionDocument = await transaction.get(sessionRef);

    if (!sessionDocument.exists) {
      throw new HttpsError(
        "not-found",
        "The parking session could not be found."
      );
    }

    const session = sessionDocument.data();

    if (session.userId !== userId) {
      throw new HttpsError(
        "permission-denied",
        "This parking session does not belong to you."
      );
    }

    const previousPayment = await transaction.get(paymentRef);

    if (previousPayment.exists) {
      const previousAmount = previousPayment.get("amountLKR");

      if (
        previousPayment.get("userId") !== userId ||
        previousPayment.get("type") !== "Parking Extension" ||
        previousPayment.get("parkingSessionId") !== sessionId ||
        previousPayment.get("operationId") !== operationId ||
        previousPayment.get("additionalMinutes") !== additionalMinutes ||
        previousPayment.get("previousDurationMinutes")
          !== expectedDurationMinutes ||
        !Number.isSafeInteger(previousAmount) ||
        previousAmount <= 0
      ) {
        throw new HttpsError(
          "already-exists",
          "This operation ID was already used."
        );
      }

      return { sessionId: sessionId, amountLKR: previousAmount };
    }

    if (session.isActive !== true || "endTime" in session) {
      throw new HttpsError(
        "failed-precondition",
        "This parking session has ended."
      );
    }

    if (
      !(session.startTime instanceof Timestamp) ||
      !(session.paidUntil instanceof Timestamp) ||
      !isValidParkingId(session.vehicleId) ||
      !isValidParkingId(session.parkingZoneId) ||
      !isValidParkingId(session.operationId) ||
      !Number.isSafeInteger(session.durationMinutes) ||
      session.durationMinutes <= 0 ||
      !Number.isSafeInteger(session.hourlyRateLKR) ||
      session.hourlyRateLKR <= 0 ||
      !Number.isSafeInteger(session.totalPaidLKR) ||
      session.totalPaidLKR <= 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The saved parking details are not valid."
      );
    }

    if (
      !Number.isSafeInteger(session.maximumStayMinutes) ||
      session.maximumStayMinutes <= 0 ||
      !Number.isInteger(session.openingHour) ||
      session.openingHour < 0 ||
      session.openingHour > 23 ||
      !Number.isInteger(session.closingHour) ||
      session.closingHour <= session.openingHour ||
      session.closingHour > 24 ||
      session.maximumStayMinutes
        > (session.closingHour - session.openingHour) * 60 ||
      session.timeZoneId !== "Asia/Colombo"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This session has no valid saved time limits. "
          + "Please end it and start a new session."
      );
    }

    if (session.durationMinutes !== expectedDurationMinutes) {
      throw new HttpsError(
        "failed-precondition",
        "Your parking time changed. Refresh before extending."
      );
    }

    const startMillis = session.startTime.toMillis();
    const paidUntilMillis = session.paidUntil.toMillis();

    if (
      paidUntilMillis - startMillis !== session.durationMinutes * 60000
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The saved parking duration does not match its times."
      );
    }

    const newDurationMinutes = session.durationMinutes + additionalMinutes;

    if (
      !Number.isSafeInteger(newDurationMinutes) ||
      newDurationMinutes > session.maximumStayMinutes
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This extension would exceed the maximum parking time."
      );
    }

    const activeDocument = await transaction.get(activeSessionRef);

    if (
      !activeDocument.exists ||
      activeDocument.get("userId") !== userId ||
      activeDocument.get("parkingSessionId") !== sessionId ||
      activeDocument.get("vehicleId") !== session.vehicleId
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Your active parking record does not match. Please refresh."
      );
    }

    const originalPaymentRef = walletRef
      .collection("transactions")
      .doc(session.operationId);
    const originalPayment = await transaction.get(originalPaymentRef);
    const originalMinutes = originalPayment.get("durationMinutes");

    if (
      !originalPayment.exists ||
      originalPayment.get("userId") !== userId ||
      originalPayment.get("type") !== "Parking Payment" ||
      originalPayment.get("parkingSessionId") !== sessionId ||
      originalPayment.get("operationId") !== session.operationId ||
      ![30, 60, 120].includes(originalMinutes) ||
      originalMinutes > session.durationMinutes
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The original payment details are missing. "
          + "Please end this session and start a new one."
      );
    }

    const originalPriceLKR = parkingPrice(session.hourlyRateLKR, originalMinutes);

    if (
      !Number.isSafeInteger(originalPriceLKR) ||
      originalPriceLKR <= 0 ||
      originalPayment.get("amountLKR") !== originalPriceLKR
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The original parking payment is not valid."
      );
    }

    const zoneRef = database
      .collection("parkingZones")
      .doc(session.parkingZoneId);
    const zoneDocument = await transaction.get(zoneRef);

    if (
      !zoneDocument.exists ||
      zoneDocument.get("isPublished") !== true ||
      zoneDocument.get("isActive") !== true ||
      !isValidParkingId(zoneDocument.get("wardenAssignmentId"))
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This zone is not available for extensions."
      );
    }

    await checkWardenCoverage(
      transaction,
      session.parkingZoneId,
      zoneDocument.get("wardenAssignmentId")
    );

    const hours = parkingHours(
      session.startTime.toDate(),
      session.openingHour,
      session.closingHour,
      session.timeZoneId
    );
    const newPaidUntilMillis = paidUntilMillis + additionalMinutes * 60000;

    if (
      startMillis < hours.openingTimeMillis ||
      newPaidUntilMillis > hours.closingTimeMillis
    ) {
      throw new HttpsError(
        "failed-precondition",
        "This extension would go past the accepted opening hours."
      );
    }

    const priceLKR = parkingPrice(session.hourlyRateLKR, additionalMinutes);
    const newTotalPaidLKR = session.totalPaidLKR + priceLKR;

    if (
      !Number.isSafeInteger(priceLKR) ||
      priceLKR <= 0 ||
      !Number.isSafeInteger(newTotalPaidLKR)
    ) {
      throw new HttpsError(
        "failed-precondition",
        "The extension price is not valid."
      );
    }

    const walletDocument = await transaction.get(walletRef);

    if (
      !walletDocument.exists ||
      walletDocument.get("userId") !== userId ||
      !Number.isSafeInteger(walletDocument.get("balanceLKR")) ||
      walletDocument.get("balanceLKR") < 0
    ) {
      throw new HttpsError(
        "failed-precondition",
        "Your demo wallet details are not valid."
      );
    }

    const currentBalance = walletDocument.get("balanceLKR");

    if (currentBalance < priceLKR) {
      throw new HttpsError(
        "failed-precondition",
        "Your demo wallet does not have enough funds."
      );
    }

    const nowMillis = Date.now();

    if (startMillis > nowMillis || paidUntilMillis <= nowMillis) {
      throw new HttpsError(
        "failed-precondition",
        "Parking has expired or its start time is invalid. "
          + "Refresh your session before continuing."
      );
    }

    const newBalance = currentBalance - priceLKR;
    const newPaidUntil = Timestamp.fromMillis(newPaidUntilMillis);

    transaction.update(walletRef, {
      balanceLKR: newBalance
    });

    transaction.update(sessionRef, {
      durationMinutes: newDurationMinutes,
      paidUntil: newPaidUntil,
      totalPaidLKR: newTotalPaidLKR
    });

    transaction.create(paymentRef, {
      userId: userId,
      type: "Parking Extension",
      amountLKR: priceLKR,
      additionalMinutes: additionalMinutes,
      previousDurationMinutes: session.durationMinutes,
      balanceAfterLKR: newBalance,
      createdAt: FieldValue.serverTimestamp(),
      operationId: operationId,
      parkingSessionId: sessionId,
      paidUntilBefore: session.paidUntil,
      paidUntilAfter: newPaidUntil
    });

    return { sessionId: sessionId, amountLKR: priceLKR };
  });
});


const vehicleIdentity = require("./vehicleIdentity");
exports.completeMotoristProfile = vehicleIdentity.completeMotoristProfile;
exports.addMotoristVehicle = vehicleIdentity.addMotoristVehicle;
exports.updateMyProfile = vehicleIdentity.updateMyProfile;

const enforcement = require("./enforcement");
exports.getWardenZones = enforcement.getWardenZones;
exports.checkParkingPlate = enforcement.checkParkingPlate;
exports.submitWardenObservation = enforcement.submitWardenObservation;
exports.getWardenObservations = enforcement.getWardenObservations;
exports.getPendingWardenObservations = enforcement.getPendingWardenObservations;
exports.getReviewedWardenObservations = enforcement.getReviewedWardenObservations;
exports.getObservationReview = enforcement.getObservationReview;
exports.reviewWardenObservation = enforcement.reviewWardenObservation;
exports.getMyTickets = enforcement.getMyTickets;

const ticketPayments = require("./ticketPayments");
exports.setTicketAutoDeduct = ticketPayments.setTicketAutoDeduct;
exports.payTicket = ticketPayments.payTicket;
