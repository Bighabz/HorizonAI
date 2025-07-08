# n8n Credentials Setup Guide

Set up these credentials in your n8n instance at https://n8n.waxmybot.com

## 1. Supabase Credentials

**Name:** Supabase API

**Credential Type:** Supabase API

**Fields:**
- **Host:** `https://hdevbjifbhxcacpjxstr.supabase.co`
- **Service Role Secret:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhkZXZiamlmYmh4Y2FjcGp4c3RyIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MDAzNTg5OSwiZXhwIjoyMDY1NjExODk5fQ.hC2mkt8gFtz9tDfIEO73eVrZuQTXs98WDvL2n-3ln1o`

## 2. Telegram Bot API

**Name:** Telegram Bot API

**Credential Type:** Telegram API

**Fields:**
- **Access Token:** `7799820694:AAHiGF8k3SiVfcy8_o2xqac7JkwqOmj3y2s`

## 3. OpenAI API

**Name:** OpenAI API

**Credential Type:** OpenAI API

**Fields:**
- **API Key:** `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`

## 4. Dumpling AI API

**Name:** Dumpling AI API

**Credential Type:** Header Auth

**Fields:**
- **Name:** `Authorization`
- **Value:** `Bearer sk_wHUE8kEVOvO8InedX5K9MjHxlB6Ws02mPSBBQvPnaH5Nss8q`

## How to Add Credentials in n8n:

1. Go to your n8n instance
2. Click on **Credentials** in the left sidebar
3. Click **Add Credential**
4. Search for the credential type
5. Fill in the fields as shown above
6. Click **Save**

## Important Notes:

- Make sure the credential names match exactly as shown above
- The workflow references these credentials by name
- Keep these credentials secure and don't share them publicly
- Consider rotating these keys periodically for security

## Database Connection (for reference):

If you need direct database access:
- **Host:** `db.hdevbjifbhxcacpjxstr.supabase.co`
- **Port:** `5432`
- **Database:** `postgres`
- **User:** `postgres`
- **Password:** `Aboveground1997!`