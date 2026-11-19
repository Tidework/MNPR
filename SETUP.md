# Putting MNPR online

MNPR runs as a website (GitHub Pages) with accounts and a shared map (Supabase).
Most of it is built. These are the steps only Lyle can do, in order.

## 1. A Supabase account just for MNPR (done, 19 Nov 2026)

Project `MNPR - Manual Number Plate Recognition` (`pkzkkawhfdbvqdzhymzy`, Ireland eu-west-1), in its own account,
separate from Tidework. Claude reaches it with a Supabase access token saved as a network secret for
`api.supabase.com` on the MNPR cloud environment. The database (`supabase/migrations/`) and the plate
checker are deployed, `PLATE_PEPPER` is set, and `src/config.json` holds the public address and key.
`supabase/tests/live_test.mjs` checks the live project end to end.

## 2. Sign-in emails

In the Supabase dashboard for `mnpr`: **Authentication → URL Configuration**:
- **Site URL**: the website address from step 4 (for example `https://<github-name>.github.io/MNPR/`).
- **Redirect URLs**: add the same address.

Supabase's free email sender only manages a few sign-in emails an hour. That's fine for testing with friends. Before a wider launch, add your own email sender (for example Resend) under **Authentication → Emails → SMTP**.

## 3. The DVLA plate check

1. Apply for a Vehicle Enquiry Service API key: https://register-for-ves.driver-vehicle-licensing.api.gov.uk/
   (about: https://developer-portal.driver-vehicle-licensing.api.gov.uk/apis/vehicle-enquiry-service/vehicle-enquiry-service-description.html)
   Say it's for a game that checks a number plate a player has seen is a real registration; nothing about the vehicle is stored. Read their terms before you agree.
2. When the key arrives, add it in Supabase: **Edge Functions → Secrets → Add**, name `DVLA_API_KEY`. Never paste it in a chat or in this repo.

Until then, confirmed plates are checked for a valid UK format showing the right number.

## 4. The website (GitHub Pages)

1. On GitHub, open the MNPR repository → **Settings → General → Danger Zone → Change visibility → Public**. (There are no secrets in the code.)
2. **Settings → Pages**: Source **Deploy from a branch**, Branch **main**, folder **/ (root)**, Save.
3. After a minute the site is live at the address shown there. Every push to `main` updates it.
