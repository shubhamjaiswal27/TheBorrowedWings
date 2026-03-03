# Supabase Integration Setup Guide

## Prerequisites

1. **Flutter Environment**: Make sure you have Flutter SDK installed
2. **Supabase Account**: Create a free account at [supabase.com](https://supabase.com)

## Step 1: Create Supabase Project

1. Go to [Supabase Dashboard](https://app.supabase.com)
2. Click "New Project"
3. Choose your organization and project name
4. Set a strong database password
5. Select a region close to you
6. Wait for the project to be created (2-3 minutes)

## Step 2: Set Up Database Schema

1. In your Supabase project dashboard, go to the **SQL Editor**
2. Copy the contents of `supabase_schema.sql` from this project
3. Paste it into the SQL Editor and click **Run**
4. This will create all necessary tables, indexes, RLS policies, and permissions

## Step 3: Configure Supabase in Flutter App

1. In your Supabase project dashboard, go to **Settings** → **API**
2. Copy your **Project URL** and **anon public key**
3. Open `lib/config/supabase_config.dart`
4. Replace the placeholder values:

```dart
static const String supabaseUrl = 'YOUR_PROJECT_URL_HERE';
static const String supabaseAnonKey = 'YOUR_ANON_KEY_HERE';
```

## Step 4: Configure Authentication (Optional)

### Enable Email/Password Authentication
1. Go to **Authentication** → **Settings** in Supabase dashboard
2. Make sure **Enable email confirmations** is turned ON for production
3. For development, you can turn it OFF to skip email verification

### Custom SMTP (Optional for Production)
1. Go to **Authentication** → **Settings** → **SMTP Settings**
2. Configure your email provider (SendGrid, Mailgun, etc.)
3. This is needed for password reset emails and email confirmations

## Step 5: Install Dependencies

Run the following command in your Flutter project:

```bash
flutter pub get
```

## Step 6: Configure Deep Linking (Optional)

For password reset and email confirmation links, you may want to set up deep linking:

### Android
Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<activity
    android:name=".MainActivity"
    android:exported="true"
    android:launchMode="singleTop"
    android:theme="@style/LaunchTheme">
    <!-- ... existing intent filters ... -->
    
    <!-- Add this for Supabase auth callbacks -->
    <intent-filter android:autoVerify="true">
        <action android:name="android.intent.action.VIEW" />
        <category android:name="android.intent.category.DEFAULT" />
        <category android:name="android.intent.category.BROWSABLE" />
        <data android:scheme="your-app-scheme" android:host="login-callback" />
    </intent-filter>
</activity>
```

### iOS
Add to `ios/Runner/Info.plist`:

```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLName</key>
        <string>your-app-scheme</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>your-app-scheme</string>
        </array>
    </dict>
</array>
```

## Step 7: Test the Application

1. Run `flutter run` 
2. The app should start and show the login screen
3. Try registering a new account
4. Complete the pilot profile
5. Test creating gliders and flights

## Database Structure Overview

The app creates four main tables:

1. **pilots**: User profile information (linked to Supabase auth users)
2. **gliders**: Paragliding equipment owned by users
3. **flights**: Flight sessions with metadata
4. **flight_fixes**: GPS waypoints for each flight

All tables use Row Level Security (RLS) to ensure users can only access their own data.

## Troubleshooting

### Common Issues

1. **"Failed to initialize Supabase"**
   - Check your URL and anon key in `supabase_config.dart`
   - Make sure they don't have trailing spaces or quotes

2. **"Failed to create pilot profile"**
   - Verify the database schema was applied correctly
   - Check RLS policies are in place
   - Ensure the user is authenticated

3. **Authentication not working**
   - For development, disable email confirmations in Supabase
   - Check if your email provider is configured correctly
   - Verify the auth flow type in `supabase_config.dart`

### Development Tips

1. **Disable Email Confirmations**: For faster development, turn off email confirmations in Supabase Auth settings
2. **Use Supabase Logs**: Check the Supabase dashboard logs for API errors
3. **Flutter Debug Console**: Watch for error messages in the Flutter debug console

## Security Considerations

1. **Row Level Security**: Already configured to ensure data isolation between users
2. **API Keys**: The anon key is safe to expose in client code
3. **Service Role Key**: NEVER expose the service role key in client code
4. **HTTPS**: Always use HTTPS in production (Supabase provides this automatically)

## Production Deployment

1. **Email Configuration**: Set up custom SMTP for production
2. **Environment Variables**: Consider using environment variables for sensitive config
3. **App Store/Play Store**: Follow platform-specific requirements for auth flows
4. **Backup Strategy**: Consider setting up automated database backups in Supabase

## Support

If you encounter issues:

1. Check the Supabase documentation: [https://supabase.com/docs](https://supabase.com/docs)
2. Review Flutter Supabase package docs: [https://pub.dev/packages/supabase_flutter](https://pub.dev/packages/supabase_flutter)
3. Check this project's issues on GitHub

## Migration from SQLite

This implementation completely replaces the original SQLite database with Supabase. Key changes:

- Authentication is now required for all app features
- All data is stored in the cloud with real-time capabilities
- Row Level Security ensures data privacy
- Email/password authentication with optional email confirmation
- Automatic data sync across devices (when logged in with the same account)

The app maintains the same user experience but now requires internet connectivity and user accounts.