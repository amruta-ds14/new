# ENIGMA Technical Club — Supabase Backend

This version uses **Supabase Auth + Supabase Postgres** instead of the local `data.json` database.

## What is stored online
- Student accounts: Supabase Authentication
- Student profiles: `profiles`
- Team discussions: `discussions`
- Event registrations: `event_registrations`
- Join ENIGMA applications: `join_applications`
- Student resources: `resources`

## 1. Create a Supabase project
Create a project in Supabase, then open its SQL Editor.

## 2. Create the database
Open `supabase/schema.sql` from this project and run the whole file in the Supabase SQL Editor.

The SQL creates the tables, profile trigger, indexes, sample resources and Row Level Security policies.

## 3. Get your project settings
In Supabase, copy:
- Project URL
- Publishable key (older projects may call this the `anon` key)

For a browser app, the publishable/anon key is intended to be used with RLS. **Never put a Supabase secret/service-role key in the browser.** Supabase documents that secret/service-role keys bypass RLS and must stay server-side. 

## 4. Configure the Node.js server
Copy:

`.env.example` → `.env`

Then fill in:

```env
SUPABASE_URL=https://YOUR_PROJECT_REF.supabase.co
SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_KEY
```

## 5. Install and run

```bash
npm install
npm start
```

Open:

`http://localhost:3000`

## Authentication
The website uses Supabase email/password authentication for:
- Sign up
- Login
- Logout
- Persistent session
- Forgot password email

If email confirmation is enabled in your Supabase Auth settings, a new student must confirm their email before logging in.

## Security
RLS is enabled for the exposed tables. Students can manage only their own profile, registrations and application, while discussions are publicly readable and only their author can delete them.

For a production deployment, keep RLS enabled and review Supabase's Security Advisor before publishing.
