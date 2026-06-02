# PayPal Integration Setup Guide - BioShield Ultimate

## 📋 Your PayPal Credentials

| Credential | Value |
|------------|-------|
| Client ID | `AdYZjwcxNYqpWCglcoqt4cv0ESkJ-G3RChAAuuET` |
| Secret Key | `EAecZX7x2XtI61BA-b72HxH0A4xInOX6rnolchtua` |
| API Key | `8coHKYs478Md3iPe6WTBR9GOeBn1N97T2SoQJzNS` |

⚠️ **IMPORTANT**: Hizi ni **Sandbox (Test) credentials**. Hazifanyi kazi kwa pesa halisi.

---

## 🚀 Quick Setup

### Step 1: Run Database Migration
```bash
docker exec -i bioshield-postgres psql -U supabase_admin -d postgres < db/migrations/006_paypal_tables.sql
