const admin = require('firebase-admin');
const express = require('express');
const app = express();
app.use(express.json());

// 1. Download your serviceAccountKey.json from Firebase Console 
// (Settings -> Service Accounts -> Generate New Private Key)
const serviceAccount = require("./serviceAccountKey.json");

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

app.post('/send-notification', async (req, res) => {
  const { token, title, body, data } = req.body;
  const message = {
    notification: { title, body },
    data: data || {},
    token: token,
  };

  try {
    await admin.messaging().send(message);
    res.status(200).send("Notification Sent");
  } catch (error) {
    res.status(500).send(error.message);
  }
});

app.listen(process.env.PORT || 3000, () => console.log('Server Running'));