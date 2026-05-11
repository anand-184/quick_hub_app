const admin = require('firebase-admin');
const express = require('express');
const app = express();

app.use(express.json());

// Initialize Firebase Admin
// On Render, you should upload your service-account.json as a "Secret File"
// and set the path correctly. By default, Secret Files are in the root of the project.
try {
    const serviceAccount = require("./service-account.json");
    admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
    });
    console.log("Firebase Admin initialized successfully");
} catch (error) {
    console.error("Error initializing Firebase Admin:", error.message);
}

app.post('/send-notification', async (req, res) => {
    const { token, title, body, data } = req.body;

    if (!token) {
        return res.status(400).send("Device token is required");
    }

    const message = {
        notification: {
            title: title || "Quick Hub",
            body: body || "You have a new update",
        },
        data: data || {},
        token: token,
    };

    try {
        const response = await admin.messaging().send(message);
        console.log("Successfully sent message:", response);
        res.status(200).send({ success: true, messageId: response });
    } catch (error) {
        console.error("Error sending message:", error);
        res.status(500).send({ success: false, error: error.message });
    }
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
    console.log(`Server is running on port ${PORT}`);
});
