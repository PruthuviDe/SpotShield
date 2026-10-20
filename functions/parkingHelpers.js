const { getFirestore } = require("firebase-admin/firestore");
const { HttpsError } = require("firebase-functions/v2/https");

const database = getFirestore();

function isValidParkingId(value) {
  return typeof value === "string" && /^[A-Za-z0-9_-]{1,128}$/.test(value);
}

function normalizePlate(value) {
  if (typeof value !== "string") return "";
  const plate = value.trim().toUpperCase();
  return /^[A-Z0-9 -]{1,32}$/.test(plate) && plateKey(plate) ? plate : "";
}

function plateKey(plate) {
  return typeof plate === "string" ? plate.toUpperCase().replace(/[ -]/g, "") : "";
}

async function readPlateVehicle(transaction, plate) {
  const result = await transaction.get(database.collection("vehicles"));
  const matches = result.docs.filter(document =>
    plateKey(document.get("licensePlate")) === plateKey(plate)
  );
  if (matches.length > 1) {
    throw new HttpsError("failed-precondition", "This plate is linked to multiple accounts. Ask Admin to resolve the duplicate vehicle records.");
  }
  return matches[0] ?? null;
}

async function readPlateSessions(transaction, plate) {
  const result = await transaction.get(
    database.collection("parkingSessions").where("isActive", "==", true)
  );
  return result.docs.filter(document =>
    plateKey(document.get("licensePlate")) === plateKey(plate)
  );
}

function parkingPrice(hourlyRateLKR, minutes) {
  const price = minutes === 30
    ? Math.ceil(hourlyRateLKR / 2)
    : hourlyRateLKR * (minutes / 60);
  if (!Number.isSafeInteger(price) || price <= 0) {
    throw new HttpsError("failed-precondition", "The parking price is not valid.");
  }
  return price;
}

function parkingHours(date, openingHour, closingHour, timeZoneId) {
  const localTime = new Intl.DateTimeFormat("en-GB", {
    timeZone: timeZoneId, hour: "2-digit", minute: "2-digit",
    second: "2-digit", hourCycle: "h23"
  }).format(date);
  const [hour, minute, second] = localTime.split(":").map(Number);
  const midnightMillis = date.getTime()
    - (hour * 3600 + minute * 60 + second) * 1000 - date.getMilliseconds();
  return {
    openingTimeMillis: midnightMillis + openingHour * 3600000,
    closingTimeMillis: midnightMillis + closingHour * 3600000
  };
}

async function checkWardenCoverage(transaction, zoneId, assignmentId) {
  const assignment = await transaction.get(database.collection("wardenAssignments").doc(assignmentId));
  if (!assignment.exists || assignment.get("parkingZoneId") !== zoneId ||
      assignment.get("isActive") !== true || assignment.get("endedAt") !== undefined ||
      !isValidParkingId(assignment.get("wardenUserId"))) {
    throw new HttpsError("failed-precondition", "This zone needs an active Warden.");
  }
  const warden = await transaction.get(database.collection("users").doc(assignment.get("wardenUserId")));
  if (!warden.exists || warden.get("role") !== "Warden") {
    throw new HttpsError("failed-precondition", "This zone needs an approved Warden.");
  }
  return assignment;
}

module.exports = {
  isValidParkingId, normalizePlate, plateKey, readPlateVehicle,
  readPlateSessions, parkingPrice, parkingHours, checkWardenCoverage
};
