-- Callen App — Supabase schema για συγχρονισμό ιστορικού κλήσεων
--
-- Πώς το χρησιμοποιείς:
--   1. Φτιάξε δωρεάν project στο https://supabase.com (Sign up -> New project).
--   2. Πήγαινε στο project σου -> SQL Editor -> New query.
--   3. Επικόλλησε ΟΛΟ αυτό το αρχείο και πάτα Run.
--   4. Πήγαινε στο Project Settings -> API. Θα δεις:
--        - "Project URL"      -> αυτό μπαίνει στο πεδίο "Supabase URL" της εφαρμογής
--        - "anon public" key  -> αυτό μπαίνει στο πεδίο "Supabase Anon Key" της εφαρμογής
--   5. Βάλε το ΙΔΙΟ URL + anon key σε ΟΛΕΣ τις συσκευές σου (Android + Linux)
--      ώστε να "βλέπουν" τα ίδια δεδομένα.
--
-- ΣΗΜΑΝΤΙΚΟ για την ασφάλεια:
--   Το "anon key" δεν είναι μυστικό με την κλασική έννοια (σχεδιάστηκε να
--   μπαίνει σε mobile apps) - η προστασία έρχεται από το Row Level Security
--   (RLS) παρακάτω. Επειδή αυτό είναι ΔΙΚΟ ΣΟΥ project (όχι πολλαπλών
--   χρηστών/tenants), το πιο απλό και ρεαλιστικό μοντέλο είναι: "όποιος
--   ξέρει το URL + anon key του project σου, μπορεί να διαβάσει/γράψει
--   στον πίνακα". Γι' αυτό:
--     - Μην ανεβάσεις ποτέ δημόσια (π.χ. σε public repo) το anon key σου.
--     - Τα ίδια τα δεδομένα (payload) είναι ούτως ή άλλως κρυπτογραφημένα
--       από την εφαρμογή πριν φτάσουν εδώ, οπότε ακόμα κι αν κάποιος
--       αποκτούσε πρόσβαση στον πίνακα, θα έβλεπε μόνο άσχετα bytes χωρίς
--       τον κωδικό κρυπτογράφησής σου.
--   Αν αργότερα θέλεις πολλούς χρήστες/tenants με πραγματική απομόνωση
--   δεδομένων, θα χρειαστείς Supabase Auth + πιο αυστηρές πολιτικές RLS
--   (auth.uid() = owner_id), κάτι που είναι εκτός του σκοπού εδώ.

create table if not exists public.call_entries (
  entry_id       text primary key,        -- σταθερό id της κλήσης (uuid v4 από την εφαρμογή)
  device_origin  text not null,            -- ποια συσκευή τη δημιούργησε (καθαρό κείμενο, όχι ευαίσθητο)
  payload        text not null,            -- ΚΡΥΠΤΟΓΡΑΦΗΜΕΝΟ blob (base64) - όλα τα πραγματικά δεδομένα της κλήσης
  updated_at     timestamptz not null default now()
);

-- Index για γρήγορο incremental "τι άλλαξε από την τελευταία φορά" pull.
create index if not exists idx_call_entries_updated_at
  on public.call_entries (updated_at);

-- Ενεργοποίηση Row Level Security (best practice - πάντα ενεργό σε public schema).
alter table public.call_entries enable row level security;

-- Επιτρέπουμε στο anon role (αυτό που χρησιμοποιεί η εφαρμογή με το anon key)
-- να διαβάζει και να γράφει. Η "απομόνωση" εδώ είναι το ίδιο το project σου
-- (URL + anon key), όχι κάποιο extra φίλτρο ανά χρήστη.
drop policy if exists "anon full access" on public.call_entries;
create policy "anon full access"
  on public.call_entries
  for all
  to anon
  using (true)
  with check (true);
