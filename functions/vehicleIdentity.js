const { getFirestore } = require("firebase-admin/firestore");
const { onCall, HttpsError } = require("firebase-functions/v2/https");
const { normalizePlate, plateKey, readPlateVehicle } = require("./parkingHelpers");
const database = getFirestore();

exports.completeMotoristProfile = onCall(async request => {
  const userId = request.auth?.uid;
  const email = request.auth?.token.email;
  const name = typeof request.data?.name === "string" ? request.data.name.trim() : "";
  const suppliedPlate = request.data?.licensePlate ?? "";
  const plate = normalizePlate(suppliedPlate);
  if (!userId || !email) throw new HttpsError("unauthenticated", "Please sign in first.");
  if (!name || name.length > 100 || typeof suppliedPlate !== "string" || (suppliedPlate.trim() && !plate)) {
    throw new HttpsError("invalid-argument", "Enter your name and a plate using letters, numbers, spaces or hyphens.");
  }
  const profileRef = database.collection("users").doc(userId);
  const vehicleRef = database.collection("vehicles").doc();
  return database.runTransaction(async transaction => {
    const profile = await transaction.get(profileRef);
    const application = await transaction.get(database.collection("wardenRequests").doc(userId));
    if (application.exists || (profile.exists && profile.get("role") !== "Motorist")) {
      throw new HttpsError("permission-denied", "This account cannot create a Driver profile.");
    }
    if (profile.exists) {
      const vehicleId = profile.get("primaryVehicleId");
      const vehicle = vehicleId ? await transaction.get(database.collection("vehicles").doc(vehicleId)) : null;
      if (profile.get("name") !== name || plateKey(vehicle?.get("licensePlate") ?? "") !== plateKey(plate)) {
        throw new HttpsError("already-exists", "Your profile already exists. Sign in to continue.");
      }
      return { userId: userId };
    }
    if (plate) await checkPlateAvailable(transaction, plate);
    const data = { name: name, email: email, role: "Motorist" };
    if (plate) {
      data.primaryVehicleId = vehicleRef.id;
      saveVehicle(transaction, userId, vehicleRef, plate);
    }
    transaction.create(profileRef, data);
    return { userId: userId };
  });
});

exports.addMotoristVehicle = onCall(async request => {
  const userId = request.auth?.uid;
  const plate = normalizePlate(request.data?.licensePlate);
  if (!userId) throw new HttpsError("unauthenticated", "Please sign in first.");
  if (!plate) throw new HttpsError("invalid-argument", "Enter a valid license plate.");
  const profileRef = database.collection("users").doc(userId);
  const vehicleRef = database.collection("vehicles").doc();
  return database.runTransaction(async transaction => {
    const profile = await transaction.get(profileRef);
    if (!profile.exists || profile.get("role") !== "Motorist") {
      throw new HttpsError("permission-denied", "Only Drivers can add a vehicle.");
    }
    const savedId = profile.get("primaryVehicleId");
    if (savedId) {
      const vehicle = await transaction.get(database.collection("vehicles").doc(savedId));
      if (vehicle.exists && plateKey(vehicle.get("licensePlate")) === plateKey(plate)) {
        return { vehicleId: savedId };
      }
      throw new HttpsError("failed-precondition", "Your account already has a vehicle.");
    }
    await checkPlateAvailable(transaction, plate);
    saveVehicle(transaction, userId, vehicleRef, plate);
    transaction.update(profileRef, { primaryVehicleId: vehicleRef.id });
    return { vehicleId: vehicleRef.id };
  });
});

async function checkPlateAvailable(transaction, plate) {
  const registry = await transaction.get(database.collection("vehiclePlates").doc(plateKey(plate)));
  const vehicle = await readPlateVehicle(transaction, plate);
  if ((registry.exists && registry.get("ownerUserId")) || vehicle) {
    throw new HttpsError("already-exists", "This plate is already linked to an account. Use that account or ask Admin for help.");
  }
}

function saveVehicle(transaction, userId, vehicleRef, plate) {
  transaction.create(vehicleRef, { ownerUserId: userId, licensePlate: plate, make: "", model: "" });
  transaction.set(database.collection("vehiclePlates").doc(plateKey(plate)), {
    ownerUserId: userId, vehicleId: vehicleRef.id, licensePlate: plate
  });
}
