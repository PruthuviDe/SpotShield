const { getFirestore, FieldValue, Timestamp } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const {
  isValidParkingId, normalizePlate, plateKey, readPlateVehicle,
  readPlateSessions, parkingHours, checkWardenCoverage
} = require("./parkingHelpers");
const { ticketFineLKR, ticketPaymentRefFor } = require("./ticketPayments");
const database = getFirestore();

async function requireRole(transaction, userId, role) {
  if (!userId) throw new HttpsError("unauthenticated", "Please sign in first.");
  const user = await transaction.get(database.collection("users").doc(userId));
  if (!user.exists || user.get("role") !== role) {
    throw new HttpsError("permission-denied", "This action requires the " + role + " role.");
  }
}

exports.getWardenZones = onCall(async request => {
  const userId = request.auth?.uid;
  return database.runTransaction(async transaction => {
    await requireRole(transaction, userId, "Warden");
    const assignments = await transaction.get(database.collection("wardenAssignments").where("wardenUserId", "==", userId));
    const zones = [];
    for (const assignment of assignments.docs) {
      if (!assignment.get("isActive") || assignment.get("endedAt") !== undefined) continue;
      const zone = await transaction.get(database.collection("parkingZones").doc(assignment.get("parkingZoneId")));
      if (zone.exists && zone.get("isPublished") && zone.get("isActive") && zone.get("wardenAssignmentId") === assignment.id) {
        zones.push({ id: zone.id, name: zone.get("name") });
      }
    }
    return { zones: zones };
  });
});

exports.checkParkingPlate = onCall(async request => {
  const { zoneId, plate } = readCheckRequest(request);
  return database.runTransaction(async transaction => {
    await requireRole(transaction, request.auth?.uid, "Warden");
    const check = await readParkingCheck(transaction, zoneId, plate, request.auth.uid);
    return publicCheck(check);
  });
});

exports.submitWardenObservation = onCall(async request => {
  const { zoneId, plate } = readCheckRequest(request);
  const operationId = request.data?.operationId;
  const notes = typeof request.data?.notes === "string" ? request.data.notes.trim() : "";
  if (!isValidParkingId(operationId) || notes.length > 200 || request.data?.isConfirmed !== true) {
    throw new HttpsError("invalid-argument", "Confirm the observed plate and zone before submitting. Notes must be under 200 characters.");
  }
  const observationRef = database.collection("wardenObservations").doc(operationId);
  return database.runTransaction(async transaction => {
    await requireRole(transaction, request.auth?.uid, "Warden");
    const previous = await transaction.get(observationRef);
    if (previous.exists) {
      if (previous.get("wardenUserId") !== request.auth.uid || previous.get("parkingZoneId") !== zoneId ||
          plateKey(previous.get("licensePlate")) !== plateKey(plate) || previous.get("notes") !== notes) {
        throw new HttpsError("already-exists", "This submission ID belongs to another observation.");
      }
      return { observationId: observationRef.id };
    }
    const check = await readParkingCheck(transaction, zoneId, plate, request.auth.uid);
    if (!check.canReport) throw new HttpsError("failed-precondition", check.parkingStatus);
    transaction.create(observationRef, {
      wardenUserId: request.auth.uid,
      parkingZoneId: zoneId,
      zoneName: check.zone.name,
      licensePlate: plate,
      observedAt: FieldValue.serverTimestamp(),
      checkedAt: Timestamp.fromMillis(check.checkedAtMillis),
      policyVersion: check.zone.policyVersion,
      reviewStatus: "Awaiting Review",
      notes: notes,
      isViolation: true,
      parkingStatus: check.parkingStatus,
      parkingSessionId: check.parkingSessionId,
      operationId: operationId
    });
    return { observationId: observationRef.id };
  });
});

exports.getWardenObservations = onCall(async request => {
  await database.runTransaction(transaction => requireRole(transaction, request.auth?.uid, "Warden"));
  const result = await database.collection("wardenObservations").where("wardenUserId", "==", request.auth.uid).get();
  return { observations: observationRows(result) };
});

exports.getPendingWardenObservations = onCall(async request => {
  await database.runTransaction(transaction => requireRole(transaction, request.auth?.uid, "Admin"));
  const result = await database.collection("wardenObservations").where("reviewStatus", "==", "Awaiting Review").get();
  return { observations: observationRows(result) };
});

exports.getReviewedWardenObservations = onCall(async request => {
  await database.runTransaction(transaction => requireRole(transaction, request.auth?.uid, "Admin"));
  const result = await database.collection("wardenObservations").where("reviewStatus", "in", ["Ticket Issued", "Dismissed"]).get();
  const observations = observationRows(result);
  const rows = await Promise.all(observations.map(async observation => {
    if (!observation.ticketId) return observation;
    const ticket = await database.collection("simulatedTickets").doc(observation.ticketId).get();
    return {
      ...observation,
      ticketPaymentStatus: ticket.exists ? ticket.get("paymentStatus") ?? "" : ""
    };
  }));
  return { observations: rows };
});

exports.getObservationReview = onCall(async request => {
  const id = request.data?.observationId;
  if (!isValidParkingId(id)) throw new HttpsError("invalid-argument", "Choose an observation.");
  return database.runTransaction(async transaction => {
    await requireRole(transaction, request.auth?.uid, "Admin");
    const observation = await transaction.get(database.collection("wardenObservations").doc(id));
    if (!observation.exists) throw new HttpsError("not-found", "This observation could not be found.");
    const saved = observation.data();
    let check;
    let issueBlockedReason = "";
    try {
      check = await readParkingCheck(transaction, saved.parkingZoneId, saved.licensePlate, saved.wardenUserId);
      issueBlockedReason = issueRestriction(saved, check);
    } catch (error) {
      if (!(error instanceof HttpsError)) throw error;
      check = resultFor("Cannot Check", error.message);
      issueBlockedReason = error.message;
    }
    return {
      ...publicCheck(check),
      canIssueTicket: saved.reviewStatus === "Awaiting Review" && !issueBlockedReason,
      issueBlockedReason: issueBlockedReason,
      recipientKnown: Boolean(check.ownerUserId)
    };
  });
});

exports.reviewWardenObservation = onCall(async request => {
  const id = request.data?.observationId;
  const action = request.data?.action;
  const reason = typeof request.data?.reason === "string" ? request.data.reason.trim() : "";
  if (!isValidParkingId(id) || !["dismiss", "issueTicket"].includes(action) || !reason || reason.length > 200) {
    throw new HttpsError("invalid-argument", "Choose an action and enter a decision reason under 200 characters.");
  }
  const observationRef = database.collection("wardenObservations").doc(id);
  const ticketRef = database.collection("simulatedTickets").doc(id);
  const finalStatus = action === "issueTicket" ? "Ticket Issued" : "Dismissed";
  return database.runTransaction(async transaction => {
    await requireRole(transaction, request.auth?.uid, "Admin");
    const document = await transaction.get(observationRef);
    if (!document.exists) throw new HttpsError("not-found", "This observation could not be found.");
    const observation = document.data();
    if (observation.reviewStatus === finalStatus) return { observationId: id, status: finalStatus };
    if (observation.reviewStatus !== "Awaiting Review") {
      throw new HttpsError("failed-precondition", "This observation already has a different decision. Refresh the records.");
    }
    const decision = {
      reviewStatus: finalStatus,
      reviewedByUserId: request.auth.uid,
      reviewedAt: FieldValue.serverTimestamp(),
      decisionReason: reason
    };
    if (action === "issueTicket") {
      const check = await readParkingCheck(transaction, observation.parkingZoneId, observation.licensePlate, observation.wardenUserId);
      const restriction = issueRestriction(observation, check);
      if (restriction) throw new HttpsError("failed-precondition", restriction);
      const registryRef = database.collection("vehiclePlates").doc(plateKey(observation.licensePlate));
      const registry = await transaction.get(registryRef);
      const existingTicket = await transaction.get(ticketRef);
      const ownerUserId = check.ownerUserId ?? "";
      const walletRef = ownerUserId ? database.collection("wallets").doc(ownerUserId) : null;
      const wallet = walletRef ? await transaction.get(walletRef) : null;
      const paymentRef = ownerUserId ? ticketPaymentRefFor(ownerUserId, id) : null;
      const previousPayment = paymentRef ? await transaction.get(paymentRef) : null;
      if (existingTicket.exists || previousPayment?.exists) {
        throw new HttpsError("failed-precondition", "A ticket or payment record already exists for this observation.");
      }
      let paymentStatus = "Due";
      let paymentMessage = ownerUserId
        ? "Auto-deduction is off. Pay from your demo wallet when ready."
        : "No Motorist account is linked. This ticket cannot be paid from a wallet.";
      let newBalanceLKR = null;
      if (ownerUserId && wallet?.exists) {
        if (wallet.get("userId") !== ownerUserId) {
          paymentMessage = "The wallet could not be verified. This ticket remains due.";
        } else if (wallet.get("autoDeductEnabled") === true) {
          const balanceLKR = wallet.get("balanceLKR");
          if (!Number.isSafeInteger(balanceLKR) || balanceLKR < 0) {
            paymentMessage = "The wallet balance could not be verified. This ticket remains due.";
          } else if (balanceLKR < ticketFineLKR) {
            paymentMessage = "Not enough demo funds. This ticket remains due.";
          } else {
            paymentStatus = "Paid";
            paymentMessage = "Automatically paid from your demo wallet.";
            newBalanceLKR = balanceLKR - ticketFineLKR;
          }
        }
      } else if (ownerUserId && !wallet?.exists) {
        paymentMessage = "No wallet was found. Create one before paying this ticket.";
      }
      if (!registry.exists) {
        transaction.create(registryRef, {
          ownerUserId: ownerUserId,
          vehicleId: check.vehicleId ?? "",
          licensePlate: observation.licensePlate
        });
      }
      transaction.create(ticketRef, {
        observationId: id,
        userId: ownerUserId,
        parkingZoneId: observation.parkingZoneId,
        zoneName: check.zone.name,
        licensePlate: observation.licensePlate,
        fineAmountLKR: ticketFineLKR,
        issuedAt: FieldValue.serverTimestamp(),
        issuedByAdminUserId: request.auth.uid,
        reason: reason,
        paymentStatus: paymentStatus,
        paymentMessage: paymentMessage,
        decisionParkingStatus: check.status,
        checkedAt: Timestamp.fromMillis(check.checkedAtMillis),
        policyVersion: check.zone.policyVersion
      });
      if (newBalanceLKR !== null) {
        transaction.update(walletRef, { balanceLKR: newBalanceLKR });
        transaction.create(paymentRef, {
          userId: ownerUserId,
          type: "Ticket Payment",
          amountLKR: ticketFineLKR,
          balanceAfterLKR: newBalanceLKR,
          createdAt: FieldValue.serverTimestamp(),
          operationId: paymentRef.id,
          ticketId: id
        });
      }
      decision.ticketId = ticketRef.id;
      decision.decisionParkingStatus = check.status;
      decision.decisionCheckedAt = Timestamp.fromMillis(check.checkedAtMillis);
    }
    transaction.update(observationRef, decision);
    return { observationId: id, status: finalStatus };
  });
});

exports.getMyTickets = onCall(async request => {
  await database.runTransaction(transaction => requireRole(transaction, request.auth?.uid, "Motorist"));
  const tickets = await database.collection("simulatedTickets").where("userId", "==", request.auth.uid).get();
  return {
    tickets: tickets.docs.map(document => ({
      ...document.data(), id: document.id, issuedAtMillis: document.get("issuedAt").toMillis(), issuedAt: null
    })).sort((first, second) => second.issuedAtMillis - first.issuedAtMillis).slice(0, 50)
  };
});

function readCheckRequest(request) {
  if (!request.auth?.uid) throw new HttpsError("unauthenticated", "Please sign in first.");
  const zoneId = request.data?.parkingZoneId;
  const plate = normalizePlate(request.data?.licensePlate);
  if (!isValidParkingId(zoneId) || !plate) throw new HttpsError("invalid-argument", "Enter a valid plate and zone.");
  return { zoneId, plate };
}

function resultFor(status, message) {
  return {
    status: status, parkingStatus: message,
    canReport: ["Overstay", "No Check-in"].includes(status),
    hasValidParking: ["Valid", "Expiring Soon"].includes(status),
    checkedAtMillis: Date.now(), parkingSessionId: null
  };
}

async function readParkingCheck(transaction, zoneId, plate, wardenUserId) {
  const document = await transaction.get(database.collection("parkingZones").doc(zoneId));
  if (!document.exists) return resultFor("Inactive Zone", "This parking zone no longer exists. Dismiss the outdated observation.");
  const zone = document.data();
  if (!isValidParkingId(zone.wardenAssignmentId)) return resultFor("Inactive Zone", "This zone has no current Warden coverage.");
  const assignment = await checkWardenCoverage(transaction, zoneId, zone.wardenAssignmentId);
  if (assignment.get("wardenUserId") !== wardenUserId) {
    throw new HttpsError("permission-denied", "The Warden assignment changed. Recheck the vehicle with the currently assigned Warden.");
  }
  if (zone.isPublished !== true || zone.isActive !== true) return resultFor("Inactive Zone", "This parking zone is inactive.");
  const now = new Date();
  const hours = parkingHours(now, zone.openingHour, zone.closingHour, zone.timeZoneId);
  if (now.getTime() < hours.openingTimeMillis || now.getTime() >= hours.closingTimeMillis) {
    return resultFor("Outside Hours", "This zone is outside its enforcement hours.");
  }
  const registry = await transaction.get(database.collection("vehiclePlates").doc(plateKey(plate)));
  const vehicle = await readPlateVehicle(transaction, plate);
  if (registry.exists && registry.get("ownerUserId") &&
      (registry.get("ownerUserId") !== vehicle?.get("ownerUserId") || registry.get("vehicleId") !== vehicle?.id)) {
    throw new HttpsError("failed-precondition", "This plate's account link needs Admin review. No ticket can be issued.");
  }
  const sessions = await readPlateSessions(transaction, plate);
  if (sessions.length > 1) throw new HttpsError("failed-precondition", "This plate has conflicting open sessions. Ask Admin to resolve them.");
  const session = sessions[0];
  let check = resultFor("No Check-in", "No current parking was found in this zone.");
  if (session && session.get("parkingZoneId") === zoneId) {
    const paidUntil = session.get("paidUntil");
    const startTime = session.get("startTime");
    if (!(paidUntil instanceof Timestamp) || !(startTime instanceof Timestamp) || startTime.toMillis() > now.getTime()) {
      return resultFor("Cannot Check", "The saved session cannot be verified. Refresh or ask Admin for help.");
    }
    const remaining = paidUntil.toMillis() - now.getTime();
    if (remaining > 0) {
      check = resultFor(remaining <= 300000 ? "Expiring Soon" : "Valid", "A current paid parking session was found in this zone.");
    } else {
      check = resultFor("Overstay", "The paid parking time has ended.");
    }
    check.parkingSessionId = session.id;
  }
  check.zone = zone;
  check.ownerUserId = vehicle?.get("ownerUserId") ?? "";
  check.vehicleId = vehicle?.id ?? "";
  return check;
}

function publicCheck(check) {
  return {
    status: check.status, parkingStatus: check.parkingStatus,
    hasValidParking: check.hasValidParking, canReport: check.canReport,
    checkedAtMillis: check.checkedAtMillis, parkingSessionId: check.parkingSessionId
  };
}

function issueRestriction(observation, check) {
  if (!observation.isViolation) return "Valid parking cannot receive a ticket.";
  if (!check.canReport) return check.parkingStatus;
  if (!Number.isInteger(observation.policyVersion) || observation.policyVersion !== check.zone.policyVersion) {
    return "The zone policy changed or this older observation has no saved policy. Dismiss it and request a fresh check.";
  }
  return "";
}

function observationRows(result) {
  return result.docs.map(document => {
    const row = document.data();
    return {
      id: document.id, wardenUserId: row.wardenUserId,
      parkingZoneId: row.parkingZoneId, zoneName: row.zoneName,
      licensePlate: row.licensePlate, observedAtMillis: row.observedAt?.toMillis() ?? 0,
      reviewStatus: row.reviewStatus, notes: row.notes ?? "", isViolation: row.isViolation === true,
      parkingStatus: row.parkingStatus, ticketId: row.ticketId ?? "",
      decisionReason: row.decisionReason ?? "", reviewedAtMillis: row.reviewedAt?.toMillis() ?? 0
    };
  }).sort((first, second) => (second.reviewedAtMillis || second.observedAtMillis) - (first.reviewedAtMillis || first.observedAtMillis)).slice(0, 50);
}
