# SMS Verification Setup Guide

This guide will help you set up SMS verification codes using Twilio for the password reset feature.

## Prerequisites

1. A Twilio account (sign up at https://www.twilio.com/try-twilio)
2. Firebase project with Cloud Functions enabled
3. Node.js and npm installed (for deploying Cloud Functions)

## Step 1: Get Twilio Credentials

1. **Sign up for Twilio** (if you don't have an account):
   - Go to https://www.twilio.com/try-twilio
   - Create a free account (includes $15.50 credit for testing)

2. **Get your Account SID and Auth Token**:
   - Log in to your Twilio Console: https://console.twilio.com/
   - Your **Account SID** and **Auth Token** are displayed on the dashboard
   - Keep these credentials secure - never commit them to version control

3. **Get a Twilio Phone Number**:
   - In the Twilio Console, go to **Phone Numbers** > **Manage** > **Buy a number**
   - For testing, you can use a trial number (free, but can only send to verified numbers)
   - For production, purchase a phone number (costs ~$1/month + per-message fees)
   - Note: Trial accounts can only send SMS to verified phone numbers (add them in Twilio Console > Phone Numbers > Verified Caller IDs)

## Step 2: Install Dependencies

1. Navigate to the `functions` directory:
   ```bash
   cd functions
   ```

2. Install the Twilio package:
   ```bash
   npm install
   ```
   (This will install all dependencies including Twilio, which we already added to package.json)

## Step 3: Configure Twilio Credentials in Firebase

You have two options for storing Twilio credentials:

### Option A: Using Firebase Functions Config (Recommended for Development)

```bash
firebase functions:config:set twilio.account_sid="YOUR_ACCOUNT_SID" twilio.auth_token="YOUR_AUTH_TOKEN" twilio.phone_number="YOUR_TWILIO_PHONE_NUMBER"
```

**Important**: 
- Replace `YOUR_ACCOUNT_SID` with your actual Account SID
- Replace `YOUR_AUTH_TOKEN` with your actual Auth Token
- Replace `YOUR_TWILIO_PHONE_NUMBER` with your Twilio phone number in E.164 format (e.g., `+1234567890`)

Example:
```bash
firebase functions:config:set twilio.account_sid="AC1234567890abcdef" twilio.auth_token="your_auth_token_here" twilio.phone_number="+15551234567"
```

### Option B: Using Environment Variables (Recommended for Production)

For production, use Firebase Functions environment variables:

1. Set environment variables in Firebase Console:
   - Go to Firebase Console > Functions > Configuration
   - Add the following environment variables:
     - `TWILIO_ACCOUNT_SID`
     - `TWILIO_AUTH_TOKEN`
     - `TWILIO_PHONE_NUMBER`

2. Or use Firebase CLI:
   ```bash
   firebase functions:secrets:set TWILIO_ACCOUNT_SID
   firebase functions:secrets:set TWILIO_AUTH_TOKEN
   firebase functions:secrets:set TWILIO_PHONE_NUMBER
   ```

## Step 4: Deploy Cloud Functions

1. Make sure you're in the project root directory (not the `functions` directory)

2. Deploy the Cloud Functions:
   ```bash
   firebase deploy --only functions
   ```

3. Wait for the deployment to complete. You should see:
   ```
   ✔  functions[sendVerificationSMS(us-central1)] Successful create operation.
   ```

## Step 5: Test the Setup

1. **Test with a verified phone number** (if using Twilio trial account):
   - In Twilio Console, go to **Phone Numbers** > **Verified Caller IDs**
   - Add your phone number for testing
   - Use the "Forgot Password" feature in your app with this verified number

2. **Check the logs**:
   ```bash
   firebase functions:log
   ```
   Look for successful SMS sending messages.

3. **Verify SMS delivery**:
   - Request a password reset code in your app
   - Check your phone for the SMS message
   - The message should contain: "Your LevelUpSports verification code is: [6-digit code]"

## Troubleshooting

### SMS Not Sending

1. **Check Twilio Console**:
   - Go to **Monitor** > **Logs** > **Messaging**
   - Look for any error messages

2. **Check Firebase Functions Logs**:
   ```bash
   firebase functions:log --only sendVerificationSMS
   ```

3. **Common Issues**:
   - **Error 21211**: Invalid phone number format
     - Solution: Ensure phone numbers are in E.164 format (+1234567890)
   
   - **Error 21608**: Phone number not verified (trial account)
     - Solution: Verify the phone number in Twilio Console > Verified Caller IDs
   
   - **"SMS service not configured"**: Credentials not set
     - Solution: Run the `firebase functions:config:set` command again

### Cloud Function Not Found

- Make sure you deployed the functions:
  ```bash
  firebase deploy --only functions
  ```

- Check that the function name matches: `sendVerificationSMS`

### Firebase Not Initialized in Flutter

- Ensure `Firebase.initializeApp()` is called in your `main.dart`
- Check that `google-services.json` (Android) and `GoogleService-Info.plist` (iOS) are properly configured

## Cost Information

- **Twilio Trial Account**: 
  - $15.50 free credit
  - Can only send to verified phone numbers
  - Good for testing

- **Twilio Paid Account**:
  - Phone number: ~$1/month
  - SMS: ~$0.0075 per message (US) or varies by country
  - See https://www.twilio.com/pricing for current rates

## Security Best Practices

1. **Never commit credentials to version control**
   - Use Firebase Functions config or environment variables
   - Add `.env` files to `.gitignore` if using local environment variables

2. **Use Firebase Functions Secrets for production**:
   ```bash
   firebase functions:secrets:set TWILIO_ACCOUNT_SID
   firebase functions:secrets:set TWILIO_AUTH_TOKEN
   firebase functions:secrets:set TWILIO_PHONE_NUMBER
   ```

3. **Rate limiting**: Consider adding rate limiting to prevent abuse (not implemented in current version)

## Next Steps

Once SMS is working:
1. Test the complete password reset flow
2. Monitor usage and costs in Twilio Console
3. Consider upgrading from trial account for production use
4. Add rate limiting if needed

## Support

- Twilio Documentation: https://www.twilio.com/docs
- Firebase Functions Documentation: https://firebase.google.com/docs/functions
- Twilio Support: https://support.twilio.com/

