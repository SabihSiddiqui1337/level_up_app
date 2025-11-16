// Cloud Functions for Firebase
// This file should be placed in a 'functions' directory at the root of your project
// Run: npm install firebase-functions firebase-admin
// Deploy: firebase deploy --only functions

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const twilio = require('twilio');

admin.initializeApp();

// Initialize Twilio client
// Get credentials from Firebase Functions config
// Set these using: firebase functions:config:set twilio.account_sid="YOUR_SID" twilio.auth_token="YOUR_TOKEN" twilio.phone_number="YOUR_PHONE"
const twilioClient = twilio(
  functions.config().twilio?.account_sid || process.env.TWILIO_ACCOUNT_SID,
  functions.config().twilio?.auth_token || process.env.TWILIO_AUTH_TOKEN
);
const twilioPhoneNumber = functions.config().twilio?.phone_number || process.env.TWILIO_PHONE_NUMBER;

// Cloud Function to send notifications when a new event is created
exports.sendEventNotification = functions.firestore
  .document('event_notifications/{notificationId}')
  .onCreate(async (snap, context) => {
    const notificationData = snap.data();
    
    // Check if notification has already been sent
    if (notificationData.sent === true) {
      console.log('Notification already sent, skipping...');
      return null;
    }
    
    const eventId = notificationData.eventId;
    const eventTitle = notificationData.eventTitle;
    const eventDate = notificationData.eventDate;
    
    try {
      // Get all FCM tokens from Firestore
      const tokensSnapshot = await admin.firestore()
        .collection('fcm_tokens')
        .get();
      
      if (tokensSnapshot.empty) {
        console.log('No FCM tokens found');
        return null;
      }
      
      // Extract all tokens
      const tokens = tokensSnapshot.docs.map(doc => doc.data().token).filter(token => token);
      
      if (tokens.length === 0) {
        console.log('No valid FCM tokens found');
        return null;
      }
      
      // Create notification message
      const message = {
        notification: {
          title: 'New Event: ' + eventTitle,
          body: 'Event Date: ' + eventDate + ' - Register now!',
        },
        data: {
          eventId: eventId,
          eventTitle: eventTitle,
          eventDate: eventDate,
          type: 'event_created',
        },
        android: {
          priority: 'high',
          notification: {
            sound: 'default',
            channelId: 'event_notifications',
            clickAction: 'FLUTTER_NOTIFICATION_CLICK',
          },
        },
        apns: {
          payload: {
            aps: {
              sound: 'default',
              badge: 1,
            },
          },
        },
        tokens: tokens, // Send to multiple tokens
      };
      
      // Send notification using FCM Admin SDK
      const response = await admin.messaging().sendEachForMulticast(message);
      
      console.log('Successfully sent notification:', response.successCount);
      console.log('Failed to send notification:', response.failureCount);
      
      // Mark notification as sent
      await snap.ref.update({
        sent: true,
        sentAt: admin.firestore.FieldValue.serverTimestamp(),
        successCount: response.successCount,
        failureCount: response.failureCount,
      });
      
      return null;
    } catch (error) {
      console.error('Error sending notification:', error);
      // Mark notification as failed
      await snap.ref.update({
        sent: false,
        error: error.message,
      });
      return null;
    }
  });

// Cloud Function to send SMS verification code
exports.sendVerificationSMS = functions.https.onCall(async (data, context) => {
  // Verify that the request is authenticated (optional - you can remove this if you want unauthenticated access)
  // if (!context.auth) {
  //   throw new functions.https.HttpsError('unauthenticated', 'The function must be called while authenticated.');
  // }

  const { phone, code } = data;

  // Validate input
  if (!phone || !code) {
    throw new functions.https.HttpsError('invalid-argument', 'Phone number and code are required.');
  }

  // Validate phone number format (should be E.164 format: +1234567890)
  const phoneRegex = /^\+?[1-9]\d{1,14}$/;
  const normalizedPhone = phone.replace(/\D/g, ''); // Remove non-digits
  const formattedPhone = normalizedPhone.startsWith('1') && normalizedPhone.length === 11
    ? `+${normalizedPhone}`
    : normalizedPhone.length === 10
    ? `+1${normalizedPhone}`
    : `+${normalizedPhone}`;

  if (!phoneRegex.test(formattedPhone.replace('+', ''))) {
    throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number format.');
  }

  // Check if Twilio is configured
  if (!twilioClient || !twilioPhoneNumber) {
    console.error('Twilio not configured. Please set TWILIO_ACCOUNT_SID, TWILIO_AUTH_TOKEN, and TWILIO_PHONE_NUMBER.');
    throw new functions.https.HttpsError('failed-precondition', 'SMS service not configured.');
  }

  try {
    // Send SMS via Twilio
    const message = await twilioClient.messages.create({
      body: `Your LevelUpSports verification code is: ${code}. This code expires in 10 minutes.`,
      from: twilioPhoneNumber,
      to: formattedPhone,
    });

    console.log(`SMS sent successfully to ${formattedPhone}. Message SID: ${message.sid}`);
    
    return {
      success: true,
      messageSid: message.sid,
      phone: formattedPhone,
    };
  } catch (error) {
    console.error('Error sending SMS:', error);
    
    // Handle Twilio-specific errors
    if (error.code === 21211) {
      throw new functions.https.HttpsError('invalid-argument', 'Invalid phone number.');
    } else if (error.code === 21608) {
      throw new functions.https.HttpsError('permission-denied', 'Phone number is not verified. Please verify your phone number in Twilio console.');
    } else {
      throw new functions.https.HttpsError('internal', `Failed to send SMS: ${error.message}`);
    }
  }
});

