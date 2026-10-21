process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.FIREBASE_AUTH_EMULATOR_HOST = "127.0.0.1:9099";
const test = require("node:test");
const assert = require("node:assert/strict");
const { randomUUID } = require("node:crypto");
const { initializeApp, deleteApp } = require("firebase-admin/app");
const { getFirestore, Timestamp } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");
const projectId = "demo-spotshield";
const app = initializeApp({ projectId }, "enforcement-tests");
const database = getFirestore(app);
const auth = getAuth(app);
const prefix = "fix-test-" + Date.now();
const zoneId = prefix + "-zone";
const assignmentId = prefix + "-assignment";
const plate = "FIX" + Date.now();
const secondPlate = plate + "B";
const unknownPlate = plate + "U";
const users = ["admin", "warden", "driver", "second", "newDriver", "forger"].map(name => ({ id: prefix + "-" + name, name }));
const documents = [];
const authIds = [];

async function seed(path, data) {
  documents.push(database.doc(path));
  await database.doc(path).set(data);
}

async function call(name, user, data = {}) {
  const response = await fetch(`http://127.0.0.1:5001/${projectId}/us-central1/${name}`, {
    method: "POST", headers: { "Content-Type": "application/json", ...(user ? { Authorization: "Bearer " + user.token } : {}) },
    body: JSON.stringify({ data })
  });
  const body = await response.json();
  if (body.error) {
    const error = new Error(body.error.message);
    error.status = body.error.status;
    throw error;
  }
  return body.result;
}

async function denied(action, status) {
  await assert.rejects(action, error => error.status === status);
}

async function signIn(user) {
  const response = await fetch("http://127.0.0.1:9099/identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=demo-api-key", {
    method: "POST", headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ email: user.email, password: user.password, returnSecureToken: true })
  });
  const result = await response.json();
  assert.ok(result.idToken);
  return result.idToken;
}

function reportRequest(licensePlate = plate, operationId = randomUUID()) {
  return { parkingZoneId: zoneId, licensePlate, operationId, notes: "Physically observed test vehicle", isConfirmed: true };
}

async function issueTicket(licensePlate = plate) {
  const request = reportRequest(licensePlate);
  await call("submitWardenObservation", users[1], request);
  await call("reviewWardenObservation", users[0], {
    observationId: request.operationId, action: "issueTicket", reason: "Confirmed test vehicle without paid parking"
  });
  return request.operationId;
}

async function directWrite(user, path, fields) {
  return fetch(`http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents/${path}`, {
    method: "PATCH", headers: { Authorization: "Bearer " + user.token, "Content-Type": "application/json" },
    body: JSON.stringify({ fields })
  });
}

async function start(user, operationId = randomUUID()) {
  const profile = await database.doc("users/" + user.id).get();
  return call("startParking", user, {
    parkingZoneId: zoneId, vehicleId: profile.get("primaryVehicleId"),
    durationMinutes: 30, policyVersion: 1, isParkedHere: true, operationId
  });
}

async function cleanup() {
  for (const collection of ["parkingSessions", "wardenObservations", "simulatedTickets"]) {
    const result = await database.collection(collection).where("parkingZoneId", "==", zoneId).get();
    for (const document of result.docs) await database.recursiveDelete(document.ref);
  }
  for (const user of users) {
    for (const collection of ["users", "wallets", "activeParkingSessions"]) {
      await database.recursiveDelete(database.collection(collection).doc(user.id));
    }
    const vehicles = await database.collection("vehicles").where("ownerUserId", "==", user.id).get();
    for (const vehicle of vehicles.docs) await database.recursiveDelete(vehicle.ref);
  }
  for (const value of [plate, secondPlate, unknownPlate]) await database.doc("vehiclePlates/" + value).delete();
  for (const document of documents) await database.recursiveDelete(document);
  for (const id of authIds) await auth.deleteUser(id);
  await deleteApp(app);
}

test("parking enforcement, ticket payments, recovery and protected writes", { timeout: 180000 }, async t => {
  try {
    for (const user of users) {
      user.password = randomUUID();
      user.email = user.id + "@example.com";
      await auth.createUser({ uid: user.id, email: user.email, password: user.password });
      authIds.push(user.id);
      user.token = await signIn(user);
    }
    const [admin, warden, driver, second, newDriver] = users;
    await seed("users/" + admin.id, { role: "Admin", name: "Test Admin", email: admin.email });
    await seed("users/" + warden.id, { role: "Warden", name: "Test Warden", email: warden.email });
    await seed("parkingZones/" + zoneId, {
      name: "Enforcement regression fixture", hourlyRateLKR: 200,
      latitude: 6.9271, longitude: 79.8612, radiusMeters: 100,
      openingHour: 0, closingHour: 24, maximumStayMinutes: 120, timeZoneId: "Asia/Colombo",
      isPublished: true, isActive: true, policyVersion: 1, wardenAssignmentId: assignmentId
    });
    await seed("wardenAssignments/" + assignmentId, { parkingZoneId: zoneId, wardenUserId: warden.id, assignedByUserId: admin.id, assignedAt: new Date(), isActive: true });

    await t.test("trusted profile setup prevents canonical plate duplication and supports late vehicle setup", async () => {
      const request = { name: "Driver", licensePlate: plate, role: "Admin", email: "wrong@example.com" };
      await call("completeMotoristProfile", driver, request);
      await call("completeMotoristProfile", driver, request);
      const profile = await database.doc("users/" + driver.id).get();
      assert.equal(profile.get("role"), "Motorist");
      assert.equal(profile.get("email"), driver.email);
      await denied(() => call("completeMotoristProfile", second, { name: "Second", licensePlate: plate.toLowerCase().replace("fix", "f-i x") }), "ALREADY_EXISTS");
      await call("completeMotoristProfile", second, { name: "Second", licensePlate: "" });
      const added = await call("addMotoristVehicle", second, { licensePlate: secondPlate });
      const retried = await call("addMotoristVehicle", second, { licensePlate: secondPlate });
      assert.equal(added.vehicleId, retried.vehicleId);
      await denied(() => call("addMotoristVehicle", second, { licensePlate: "OTHER123" }), "FAILED_PRECONDITION");
      await denied(() => call("completeMotoristProfile", warden, { name: "Warden", licensePlate: "" }), "PERMISSION_DENIED");
      await seed("wallets/" + driver.id, { userId: driver.id, balanceLKR: 2000, autoDeductEnabled: false });
      await seed("wallets/" + second.id, { userId: second.id, balanceLKR: 2000, autoDeductEnabled: false });
    });

    let staleRequest;
    let sessionId;
    await t.test("unauthorized roles and unconfirmed reports are rejected; retry resolves the same case", async () => {
      await denied(() => call("getWardenZones", driver), "PERMISSION_DENIED");
      await denied(() => call("getWardenZones", null), "UNAUTHENTICATED");
      staleRequest = reportRequest();
      await denied(() => call("submitWardenObservation", warden, { ...staleRequest, isConfirmed: false }), "INVALID_ARGUMENT");
      const results = await Promise.all([call("submitWardenObservation", warden, staleRequest), call("submitWardenObservation", warden, staleRequest)]);
      assert.equal(results[0].observationId, results[1].observationId);
      assert.equal(results[0].observationId, staleRequest.operationId);
      await denied(() => call("submitWardenObservation", warden, { ...staleRequest, notes: "Changed payload" }), "ALREADY_EXISTS");
      const saved = await database.collection("wardenObservations").where("parkingZoneId", "==", zoneId).get();
      assert.equal(saved.size, 1);
      await denied(() => call("reviewWardenObservation", warden, { observationId: staleRequest.operationId, action: "issueTicket", reason: "Test reason" }), "PERMISSION_DENIED");
    });

    await t.test("valid parking blocks stale ticket issue and new violation reports", async () => {
      const operationId = randomUUID();
      const result = await start(driver, operationId);
      sessionId = result.sessionId;
      assert.equal((await start(driver, operationId)).sessionId, sessionId);
      const check = await call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: plate });
      assert.equal(check.status, "Valid");
      assert.equal(check.canReport, false);
      await denied(() => call("submitWardenObservation", warden, reportRequest()), "FAILED_PRECONDITION");
      const review = await call("getObservationReview", admin, { observationId: staleRequest.operationId });
      assert.equal(review.canIssueTicket, false);
      await denied(() => call("reviewWardenObservation", admin, { observationId: staleRequest.operationId, action: "issueTicket", reason: "Old observation" }), "FAILED_PRECONDITION");
      assert.equal((await database.doc("simulatedTickets/" + staleRequest.operationId).get()).exists, false);
      await call("reviewWardenObservation", admin, { observationId: staleRequest.operationId, action: "dismiss", reason: "Current valid parking found" });
      await call("reviewWardenObservation", admin, { observationId: staleRequest.operationId, action: "dismiss", reason: "Retry decision" });
      assert.equal((await database.doc("wardenObservations/" + staleRequest.operationId).get()).get("decisionReason"), "Current valid parking found");
      await denied(() => call("reviewWardenObservation", admin, { observationId: staleRequest.operationId, action: "issueTicket", reason: "Conflicting decision" }), "FAILED_PRECONDITION");
    });

    await t.test("per-plate locking survives a missing user pointer; extension and end remain atomic and retryable", async () => {
      const pointerRef = database.doc("activeParkingSessions/" + driver.id);
      const pointer = (await pointerRef.get()).data();
      await pointerRef.delete();
      await denied(() => start(driver), "FAILED_PRECONDITION");
      await pointerRef.set(pointer);
      const operationId = randomUUID();
      const extension = { sessionId, additionalMinutes: 30, expectedDurationMinutes: 30, operationId };
      await call("extendParking", driver, extension);
      await call("extendParking", driver, extension);
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 1800);
      assert.equal((await database.doc("parkingSessions/" + sessionId).get()).get("durationMinutes"), 60);
      await call("endParking", driver, { sessionId });
      await call("endParking", driver, { sessionId });
      assert.equal((await database.doc("vehiclePlates/" + plate).get()).get("activeSessionId"), undefined);
      assert.equal((await pointerRef.get()).exists, false);
    });

    await t.test("legacy duplicate vehicles are blocked rather than assigned to an arbitrary owner", async () => {
      const duplicateRef = database.doc("vehicles/" + prefix + "-duplicate");
      await seed(duplicateRef.path, { ownerUserId: second.id, licensePlate: plate.toLowerCase(), make: "", model: "" });
      await denied(() => call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: plate }), "FAILED_PRECONDITION");
      await denied(() => start(driver), "FAILED_PRECONDITION");
      await duplicateRef.delete();
    });

    let ticketRequest;
    await t.test("a genuine no-check-in case issues one due ticket visible only to its Motorist", async () => {
      ticketRequest = reportRequest();
      await call("submitWardenObservation", warden, ticketRequest);
      const review = await call("getObservationReview", admin, { observationId: ticketRequest.operationId });
      assert.equal(review.canIssueTicket, true);
      assert.equal(review.recipientKnown, true);
      const decision = { observationId: ticketRequest.operationId, action: "issueTicket", reason: "No paid session on current check" };
      await Promise.all([call("reviewWardenObservation", admin, decision), call("reviewWardenObservation", admin, decision)]);
      const ticket = await database.doc("simulatedTickets/" + ticketRequest.operationId).get();
      assert.equal(ticket.get("userId"), driver.id);
      assert.equal(ticket.get("fineAmountLKR"), 1000);
      assert.equal(ticket.get("paymentStatus"), "Due");
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 1800);
      const mine = await call("getMyTickets", driver);
      const other = await call("getMyTickets", second, { userId: driver.id });
      assert.equal(mine.tickets.length, 1);
      assert.equal(other.tickets.length, 0);
      await denied(() => call("getMyTickets", warden), "PERMISSION_DENIED");
      const reviewed = await call("getReviewedWardenObservations", admin);
      assert.ok(reviewed.observations.some(row => row.id === ticketRequest.operationId));
    });

    await t.test("only the signed-in Motorist can change consent or pay an owned ticket", async () => {
      for (const user of [null, admin, warden]) {
        const status = user ? "PERMISSION_DENIED" : "UNAUTHENTICATED";
        await denied(() => call("setTicketAutoDeduct", user, { enabled: true }), status);
        await denied(() => call("payTicket", user, { ticketId: ticketRequest.operationId }), status);
      }
      await denied(() => call("setTicketAutoDeduct", driver, { enabled: "true" }), "INVALID_ARGUMENT");
      await denied(() => call("payTicket", driver, { ticketId: "invalid/id" }), "INVALID_ARGUMENT");
      await denied(() => call("payTicket", second, { ticketId: ticketRequest.operationId }), "NOT_FOUND");
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 1800);
      assert.equal((await database.doc("wallets/" + second.id).get()).get("balanceLKR"), 2000);
    });

    let autoPaidTicketId;
    await t.test("new tickets with consent and enough funds are paid exactly once even when issue is retried", async () => {
      await call("setTicketAutoDeduct", driver, { enabled: true, userId: second.id });
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("autoDeductEnabled"), true);
      assert.equal((await database.doc("wallets/" + second.id).get()).get("autoDeductEnabled"), false);
      const request = reportRequest();
      await call("submitWardenObservation", warden, request);
      const decision = { observationId: request.operationId, action: "issueTicket", reason: "Auto-payment test" };
      await Promise.all([call("reviewWardenObservation", admin, decision), call("reviewWardenObservation", admin, decision)]);
      autoPaidTicketId = request.operationId;
      const ticket = await database.doc("simulatedTickets/" + autoPaidTicketId).get();
      const payments = await database.collection("wallets/" + driver.id + "/transactions").where("ticketId", "==", autoPaidTicketId).get();
      assert.equal(ticket.get("paymentStatus"), "Paid");
      assert.equal(payments.size, 1);
      assert.equal(payments.docs[0].get("amountLKR"), 1000);
      assert.equal(payments.docs[0].get("balanceAfterLKR"), 800);
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 800);
      assert.equal((await database.doc("simulatedTickets/" + ticketRequest.operationId).get()).get("paymentStatus"), "Due");
      await call("payTicket", driver, { ticketId: autoPaidTicketId });
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 800);
      assert.equal((await database.collection("wallets/" + driver.id + "/transactions").where("ticketId", "==", autoPaidTicketId).get()).size, 1);
    });

    let insufficientTicketId;
    await t.test("insufficient funds leave automatic and manual payments due without a partial charge", async () => {
      insufficientTicketId = await issueTicket();
      const ticket = await database.doc("simulatedTickets/" + insufficientTicketId).get();
      assert.equal(ticket.get("paymentStatus"), "Due");
      assert.match(ticket.get("paymentMessage"), /Not enough demo funds/);
      await denied(() => call("payTicket", driver, { ticketId: insufficientTicketId }), "FAILED_PRECONDITION");
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 800);
      assert.equal((await database.doc("wallets/" + driver.id + "/transactions/ticket-payment-" + insufficientTicketId).get()).exists, false);
      assert.equal((await database.doc("simulatedTickets/" + insufficientTicketId).get()).get("paymentStatus"), "Due");
    });

    await t.test("top-up and consent changes never charge existing due tickets", async () => {
      await call("setTicketAutoDeduct", driver, { enabled: false });
      await call("topUpWallet", driver, { amountLKR: 1000, operationId: randomUUID() });
      await call("setTicketAutoDeduct", driver, { enabled: true });
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 1800);
      for (const ticketId of [ticketRequest.operationId, insufficientTicketId]) {
        assert.equal((await database.doc("simulatedTickets/" + ticketId).get()).get("paymentStatus"), "Due");
        assert.equal((await database.doc("wallets/" + driver.id + "/transactions/ticket-payment-" + ticketId).get()).exists, false);
      }
    });

    await t.test("concurrent manual retries produce one debit and one ticket ledger row", async () => {
      const request = { ticketId: ticketRequest.operationId };
      const results = await Promise.all([call("payTicket", driver, request), call("payTicket", driver, request), call("payTicket", driver, request)]);
      assert.ok(results.every(result => result.paymentStatus === "Paid"));
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 800);
      const ticket = await database.doc("simulatedTickets/" + request.ticketId).get();
      assert.equal(ticket.get("paymentStatus"), "Paid");
      assert.equal(ticket.get("paymentMethod"), "Manual");
      const payments = await database.collection("wallets/" + driver.id + "/transactions").where("ticketId", "==", request.ticketId).get();
      assert.equal(payments.size, 1);
      assert.equal(payments.docs[0].get("type"), "Ticket Payment");
      assert.equal(payments.docs[0].get("amountLKR"), 1000);
      assert.equal(payments.docs[0].get("balanceAfterLKR"), 800);
      const path = `wallets/${driver.id}/transactions/${payments.docs[0].id}`;
      const url = `http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents/${path}`;
      assert.equal((await fetch(url, { headers: { Authorization: "Bearer " + driver.token } })).status, 200);
      assert.equal((await fetch(url, { headers: { Authorization: "Bearer " + second.token } })).status, 403);
    });

    await t.test("fresh sign-in reloads saved Paid and Due outcomes for Motorist and Admin", async () => {
      driver.token = await signIn(driver);
      admin.token = await signIn(admin);
      const mine = await call("getMyTickets", driver);
      const reviewed = await call("getReviewedWardenObservations", admin);
      for (const [id, status] of [[autoPaidTicketId, "Paid"], [ticketRequest.operationId, "Paid"], [insufficientTicketId, "Due"]]) {
        assert.equal(mine.tickets.find(ticket => ticket.id === id).paymentStatus, status);
        assert.equal(reviewed.observations.find(observation => observation.id === id).ticketPaymentStatus, status);
      }
      assert.equal((await call("getMyTickets", second)).tickets.length, 0);
    });

    await t.test("different tickets paid concurrently cannot overdraw the same wallet", async () => {
      await call("setTicketAutoDeduct", driver, { enabled: false });
      await call("topUpWallet", driver, { amountLKR: 1000, operationId: randomUUID() });
      const otherTicketId = await issueTicket();
      const ids = [insufficientTicketId, otherTicketId];
      const results = await Promise.allSettled(ids.map(ticketId => call("payTicket", driver, { ticketId })));
      assert.equal(results.filter(result => result.status === "fulfilled").length, 1);
      assert.equal(results.find(result => result.status === "rejected").reason.status, "FAILED_PRECONDITION");
      assert.equal((await database.doc("wallets/" + driver.id).get()).get("balanceLKR"), 800);
      const statuses = [];
      let paymentCount = 0;
      for (const ticketId of ids) {
        statuses.push((await database.doc("simulatedTickets/" + ticketId).get()).get("paymentStatus"));
        const payments = await database.collection("wallets/" + driver.id + "/transactions").where("ticketId", "==", ticketId).get();
        paymentCount += payments.size;
      }
      assert.deepEqual(statuses.sort(), ["Due", "Paid"]);
      assert.equal(paymentCount, 1);
    });

    await t.test("outside hours, inactive zones, changed policy and ended assignment block enforcement", async () => {
      const pending = reportRequest(secondPlate);
      await call("submitWardenObservation", warden, pending);
      const hour = Number(new Intl.DateTimeFormat("en-GB", { timeZone: "Asia/Colombo", hour: "2-digit", hourCycle: "h23" }).format(new Date()));
      await database.doc("parkingZones/" + zoneId).update({ openingHour: hour === 23 ? 0 : 23, closingHour: hour === 23 ? 1 : 24, maximumStayMinutes: 60, policyVersion: 2 });
      const check = await call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: secondPlate });
      assert.equal(check.status, "Outside Hours");
      await denied(() => call("submitWardenObservation", warden, reportRequest(secondPlate)), "FAILED_PRECONDITION");
      assert.equal((await call("submitWardenObservation", warden, ticketRequest)).observationId, ticketRequest.operationId);
      await denied(() => call("reviewWardenObservation", admin, { observationId: pending.operationId, action: "issueTicket", reason: "Outside hours" }), "FAILED_PRECONDITION");
      await database.doc("parkingZones/" + zoneId).update({ openingHour: 0, closingHour: 24, maximumStayMinutes: 120, policyVersion: 3 });
      await denied(() => call("reviewWardenObservation", admin, { observationId: pending.operationId, action: "issueTicket", reason: "Changed policy" }), "FAILED_PRECONDITION");
      await database.doc("parkingZones/" + zoneId).update({ isActive: false });
      assert.equal((await call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: secondPlate })).status, "Inactive Zone");
      await denied(() => call("submitWardenObservation", warden, reportRequest(secondPlate)), "FAILED_PRECONDITION");
      await database.doc("parkingZones/" + zoneId).update({ isActive: true });
      await database.doc("wardenAssignments/" + assignmentId).update({ isActive: false, endedAt: new Date() });
      await denied(() => call("submitWardenObservation", warden, reportRequest(secondPlate)), "FAILED_PRECONDITION");
      await call("reviewWardenObservation", admin, { observationId: pending.operationId, action: "dismiss", reason: "Coverage and policy changed" });
      await database.doc("wardenAssignments/" + assignmentId).update({ isActive: true, endedAt: require("firebase-admin/firestore").FieldValue.delete() });
    });

    await t.test("overstay and expiring states are distinct; legacy sessions still protect the plate", async () => {
      const profile = await database.doc("users/" + second.id).get();
      const operationId = randomUUID();
      const started = await call("startParking", second, {
        parkingZoneId: zoneId, vehicleId: profile.get("primaryVehicleId"),
        durationMinutes: 30, policyVersion: 3, isParkedHere: true, operationId
      });
      const sessionRef = database.doc("parkingSessions/" + started.sessionId);
      const registryRef = database.doc("vehiclePlates/" + secondPlate);
      await registryRef.delete();
      const pointerRef = database.doc("activeParkingSessions/" + second.id);
      const pointer = (await pointerRef.get()).data();
      await pointerRef.delete();
      await denied(() => call("startParking", second, {
        parkingZoneId: zoneId, vehicleId: profile.get("primaryVehicleId"),
        durationMinutes: 30, policyVersion: 3, isParkedHere: true, operationId: randomUUID()
      }), "FAILED_PRECONDITION");
      await pointerRef.set(pointer);
      let check = await call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: secondPlate });
      assert.equal(check.status, "Valid");
      const now = Date.now();
      await sessionRef.update({ startTime: Timestamp.fromMillis(now - 29 * 60000), paidUntil: Timestamp.fromMillis(now + 60000) });
      check = await call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: secondPlate });
      assert.equal(check.status, "Expiring Soon");
      assert.equal(check.canReport, false);
      await sessionRef.update({ startTime: Timestamp.fromMillis(now - 31 * 60000), paidUntil: Timestamp.fromMillis(now - 60000) });
      check = await call("checkParkingPlate", warden, { parkingZoneId: zoneId, licensePlate: secondPlate });
      assert.equal(check.status, "Overstay");
      const request = reportRequest(secondPlate);
      await call("submitWardenObservation", warden, request);
      const results = await Promise.allSettled([
        call("reviewWardenObservation", admin, { observationId: request.operationId, action: "issueTicket", reason: "Paid time expired" }),
        call("reviewWardenObservation", admin, { observationId: request.operationId, action: "dismiss", reason: "Competing decision" })
      ]);
      assert.equal(results.filter(result => result.status === "fulfilled").length, 1);
      const observation = await database.doc("wardenObservations/" + request.operationId).get();
      const ticket = await database.doc("simulatedTickets/" + request.operationId).get();
      assert.equal(ticket.exists, observation.get("reviewStatus") === "Ticket Issued");
      await call("endParking", second, { sessionId: started.sessionId });
      assert.equal((await registryRef.get()).get("activeSessionId"), undefined);
    });

    await t.test("unknown vehicles do not receive a guessed owner and can register later", async () => {
      const request = reportRequest(unknownPlate);
      await call("submitWardenObservation", warden, request);
      await call("reviewWardenObservation", admin, { observationId: request.operationId, action: "issueTicket", reason: "Unregistered vehicle without paid parking" });
      const ticketRef = database.doc("simulatedTickets/" + request.operationId);
      assert.equal((await ticketRef.get()).get("userId"), "");
      await call("completeMotoristProfile", newDriver, { name: "New Driver", licensePlate: unknownPlate });
      assert.equal((await ticketRef.get()).get("userId"), "");
    });

    await t.test("client writes cannot bypass identity, roles, wallets or ticket decisions", async () => {
      const attempts = [
        ["vehicles/" + prefix + "-forged", { ownerUserId: { stringValue: driver.id }, licensePlate: { stringValue: plate }, make: { stringValue: "" }, model: { stringValue: "" } }],
        ["vehiclePlates/" + plate, { ownerUserId: { stringValue: second.id } }],
        ["users/" + driver.id, { name: { stringValue: "Driver" }, email: { stringValue: driver.email }, role: { stringValue: "Admin" } }],
        ["wallets/" + driver.id, { userId: { stringValue: driver.id }, balanceLKR: { integerValue: "999999" }, autoDeductEnabled: { booleanValue: false } }],
        ["simulatedTickets/" + ticketRequest.operationId, { paymentStatus: { stringValue: "Paid" } }]
      ];
      for (const [path, fields] of attempts) assert.equal((await directWrite(driver, path, fields)).status, 403, path);
      const forger = users[5];
      const forgedVehicleId = prefix + "-forged-registration";
      const base = `projects/${projectId}/databases/(default)/documents/`;
      const response = await fetch(`http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents:commit`, {
        method: "POST", headers: { Authorization: "Bearer " + forger.token, "Content-Type": "application/json" },
        body: JSON.stringify({ writes: [
          { update: { name: base + "users/" + forger.id, fields: {
            name: { stringValue: "Forger" }, email: { stringValue: forger.email },
            role: { stringValue: "Motorist" }, primaryVehicleId: { stringValue: forgedVehicleId }
          } } },
          { update: { name: base + "vehicles/" + forgedVehicleId, fields: {
            ownerUserId: { stringValue: forger.id }, licensePlate: { stringValue: plate },
            make: { stringValue: "" }, model: { stringValue: "" }
          } } }
        ] })
      });
      assert.equal(response.status, 403, "old direct registration batch must not bypass the plate registry");
      assert.equal((await database.doc("users/" + forger.id).get()).exists, false);
      assert.equal((await database.doc("vehicles/" + forgedVehicleId).get()).exists, false);
      const ownProfile = await directWrite(forger, "users/" + forger.id, {
        name: { stringValue: "Forger" }, email: { stringValue: forger.email }, role: { stringValue: "Motorist" }
      });
      assert.equal(ownProfile.status, 200, "ordinary own Motorist profile remains allowed");
      const crossRead = await fetch(`http://127.0.0.1:8080/v1/projects/${projectId}/databases/(default)/documents/users/${driver.id}`, {
        headers: { Authorization: "Bearer " + second.token }
      });
      assert.equal(crossRead.status, 403);

    });
  } finally {
    await cleanup();
    console.log("Temporary enforcement test data and accounts removed.");
  }
});
