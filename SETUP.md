# Putting MNPR online

MNPR runs as a website (GitHub Pages) with accounts and a shared map (Supabase).
Most of it is built. These are the steps only Lyle can do, in order.

## 1. A Supabase account just for MNPR

1. Go to https://supabase.com and sign up with an email that isn't your Tidework one (or, signed in, make a new organisation called MNPR). Pick the **Free** plan.
2. Create a project called `mnpr`. Region: **London (eu-west-2)**. Save the database password somewhere safe (you won't need to give it to Claude).
3. In claude.ai, go to **Settings → Connectors → Supabase** and connect it to the new account or organisation, so Claude can see the `mnpr` project.
4. Tell Claude it's done. Claude then:
   - loads the database (`supabase/migrations/`), already tested by `supabase/tests/`,
   - deploys the plate checker (`supabase/functions/confirm-plate/`),
   - fills in `src/config.json` with the project's public address and public key (safe to publish),
   - sets the secret `PLATE_PEPPER` used to scramble plates.

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
