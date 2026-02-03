# CRAKS Payment Management System - Setup Guide

## 1. Supabase Setup

1. Go to [supabase.com](https://supabase.com) and create a free project
2. Go to **SQL Editor** and run these files in order:
   - `supabase/schema.sql` - Creates all tables, indexes, and triggers
   - `supabase/rls-policies.sql` - Enables Row Level Security
   - `supabase/seed-data.sql` - Optional demo data
3. Go to **Authentication > Users** and create your first admin user
4. Copy that user's UUID, then run in SQL Editor:
   ```sql
   INSERT INTO users (id, email, full_name, role)
   VALUES ('YOUR_AUTH_USER_UUID', 'ishaq@craks.com', 'Ishaq', 'admin');
   ```
5. Note your **Project URL** and **anon public key** from Settings > API

## 2. Configure the App

Edit `js/supabase-client.js` and replace:
```javascript
const SUPABASE_URL = 'https://YOUR_PROJECT.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR_ANON_KEY';
```

## 3. Deploy to Netlify

1. Push code to a GitHub repository
2. Go to [netlify.com](https://netlify.com), connect your repo
3. Build settings:
   - Build command: (leave empty)
   - Publish directory: `.`
4. Deploy

## 4. First Login

1. Visit your deployed site
2. Log in with the admin email/password you created in Supabase Auth
3. Go to **Manage Users** to add team members

## 5. Adding Users

For each team member:
1. Go to Manage Users page
2. Fill in their details and set role to "team"
3. They can then log in with their email/password

## Notes

- The `_redirects` file handles SPA routing on Netlify
- All API keys should ideally be in environment variables for production
- The free Supabase plan supports up to 500MB database and 50,000 monthly active users
