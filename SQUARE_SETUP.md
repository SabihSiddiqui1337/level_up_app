# Square Payment Integration Setup Guide

This guide will help you set up Square payment processing for the Level Up Sports app.

## Prerequisites

1. A Square Developer account (sign up at https://developer.squareup.com/)
2. Firebase project with Cloud Functions enabled
3. Node.js and npm installed (for deploying Cloud Functions)

## Step 1: Get Square Credentials

1. **Sign up for Square Developer** (if you don't have an account):
   - Go to https://developer.squareup.com/
   - Create a free account

2. **Create a Square Application**:
   - Log in to Square Developer Console: https://developer.squareup.com/apps
   - Click "New Application"
   - Give it a name (e.g., "Level Up Sports")
   - Select your application type
   - Note your **Application ID** (you already have: `sandbox-sq0idb-X0C_ewi4_MT4Xd-bqO_hew`)

3. **Get your Access Token**:
   - In your Square application, go to the "Credentials" section
   - For **Sandbox** (testing): Copy your "Sandbox Access Token"
   - For **Production**: Copy your "Production Access Token"
   - ⚠️ Keep these tokens secure - never commit them to version control

4. **Get your Location ID**:
   - Go to Square Developer Console > Locations
   - Copy your **Location ID** (you'll need this for processing payments)
   - If you don't have a location, create one in your Square Dashboard

## Step 2: Install Dependencies

1. Navigate to the `functions` directory:
   ```bash
   cd functions
   ```

2. Install the Square package:
   ```bash
   npm install
   ```
   (This will install all dependencies including Square SDK, which we already added to package.json)

## Step 3: Configure Square Credentials in Firebase

You have two options for storing Square credentials:

### Option A: Using Firebase Functions Config (Recommended for Development)

```bash
firebase functions:config:set square.application_id="YOUR_APPLICATION_ID" square.access_token="YOUR_ACCESS_TOKEN" square.location_id="YOUR_LOCATION_ID"
```

**Important**: 
- Replace `YOUR_APPLICATION_ID` with your Square Application ID (e.g., `sandbox-sq0idb-X0C_ewi4_MT4Xd-bqO_hew`)
- Replace `YOUR_ACCESS_TOKEN` with your Sandbox or Production Access Token
- Replace `YOUR_LOCATION_ID` with your Square Location ID

Example:
```bash
firebase functions:config:set square.application_id="sandbox-sq0idb-X0C_ewi4_MT4Xd-bqO_hew" square.access_token="EAAAxxxxxxxxxxxx" square.location_id="L8XXXXXXXXXXXX"
```

### Option B: Using Environment Variables (Recommended for Production)

For production, use Firebase Functions environment variables:

1. Set environment variables in Firebase Console:
   - Go to Firebase Console > Functions > Configuration
   - Add the following environment variables:
     - `SQUARE_APPLICATION_ID`
     - `SQUARE_ACCESS_TOKEN`
     - `SQUARE_LOCATION_ID`

2. Or use Firebase CLI:
   ```bash
   firebase functions:secrets:set SQUARE_APPLICATION_ID
   firebase functions:secrets:set SQUARE_ACCESS_TOKEN
   firebase functions:secrets:set SQUARE_LOCATION_ID
   ```

## Step 4: Update Flutter App with Application ID

The Square Application ID is already set in `lib/screens/payment_screen.dart`:
```dart
static const String _squareApplicationId = 'sandbox-sq0idb-X0C_ewi4_MT4Xd-bqO_hew';
```

If you need to change it, update this constant in the payment screen.

## Step 5: Install Flutter Dependencies

1. In the project root, run:
   ```bash
   flutter pub get
   ```

This will install the `square_in_app_payments` package.

## Step 6: Deploy Cloud Functions

1. Make sure you're in the project root directory (not the `functions` directory)

2. Deploy the Cloud Functions:
   ```bash
   firebase deploy --only functions
   ```

3. Wait for the deployment to complete. You should see:
   ```
   ✔  functions[processSquarePayment(us-central1)] Successful create operation.
   ```

## Step 7: Test the Setup

### Testing with Square Sandbox

1. **Use Square Test Cards**:
   - Square provides test card numbers for sandbox testing
   - Go to: https://developer.squareup.com/docs/testing/test-values
   - Use these test cards:
     - **Success**: `4111 1111 1111 1111`
     - **Decline**: `4000 0000 0000 0002`
     - **CVV**: Any 3 digits (e.g., `123`)
     - **Expiry**: Any future date (e.g., `12/25`)

2. **Test the Payment Flow**:
   - Open your app and go through the registration process
   - When you reach the payment screen, click "Complete Payment"
   - Square's card entry screen will appear
   - Enter a test card number
   - The payment should process successfully

3. **Check the Logs**:
   ```bash
   firebase functions:log --only processSquarePayment
   ```
   Look for successful payment processing messages.

### Verify Payment in Square Dashboard

1. Log in to Square Developer Console
2. Go to **Payments** section
3. You should see test payments listed there

## Troubleshooting

### Payment Not Processing

1. **Check Square Console**:
   - Go to Square Developer Console > Payments
   - Look for any error messages

2. **Check Firebase Functions Logs**:
   ```bash
   firebase functions:log --only processSquarePayment
   ```

3. **Common Issues**:
   - **"Payment service not configured"**: Credentials not set
     - Solution: Run the `firebase functions:config:set` command again
   
   - **"Invalid access token"**: Wrong access token
     - Solution: Verify your access token in Square Developer Console
   
   - **"Invalid location ID"**: Wrong location ID
     - Solution: Get the correct Location ID from Square Dashboard

### Square SDK Not Initializing

- Check that the Application ID is correct in `payment_screen.dart`
- Ensure you have internet connection
- Check console logs for initialization errors

### Cloud Function Not Found

- Make sure you deployed the functions:
  ```bash
  firebase deploy --only functions
  ```

- Check that the function name matches: `processSquarePayment`

## Moving to Production

When you're ready to accept real payments:

1. **Get Production Credentials**:
   - In Square Developer Console, switch to "Production" mode
   - Get your Production Application ID
   - Get your Production Access Token
   - Get your Production Location ID

2. **Update Firebase Config**:
   ```bash
   firebase functions:config:set square.application_id="PROD_APP_ID" square.access_token="PROD_ACCESS_TOKEN" square.location_id="PROD_LOCATION_ID"
   ```

3. **Update Flutter App**:
   - Update `_squareApplicationId` in `payment_screen.dart` with your production Application ID

4. **Redeploy**:
   ```bash
   firebase deploy --only functions
   ```

5. **Test with Real Card** (small amount first):
   - Use a real credit card with a small test amount
   - Verify the payment appears in your Square Dashboard

## Cost Information

- **Square Processing Fees**:
  - Online payments: 2.9% + $0.30 per transaction
  - See https://squareup.com/pricing for current rates

- **Firebase Functions**:
   - Free tier: 2 million invocations/month
   - See https://firebase.google.com/pricing for details

## Security Best Practices

1. **Never commit credentials to version control**
   - Use Firebase Functions config or environment variables
   - Add `.env` files to `.gitignore` if using local environment variables

2. **Use Firebase Functions Secrets for production**:
   ```bash
   firebase functions:secrets:set SQUARE_ACCESS_TOKEN
   ```

3. **Rotate credentials regularly**:
   - Change access tokens periodically
   - Revoke old tokens in Square Developer Console

4. **Monitor for suspicious activity**:
   - Check Square Dashboard regularly
   - Set up alerts for unusual payment patterns

## Support

- Square Developer Documentation: https://developer.squareup.com/docs
- Square Support: https://squareup.com/help
- Firebase Functions Documentation: https://firebase.google.com/docs/functions
- Square In-App Payments Flutter Plugin: https://pub.dev/packages/square_in_app_payments

