# PocketBase setup για Callen App

Το PocketBase δεν έχει "SQL editor" σαν το Supabase — φτιάχνεις τη
συλλογή (collection) μέσα από το Admin UI. Βήματα:

1. Κατέβασε/τρέξε το PocketBase (https://pocketbase.io/docs/) — είναι ένα
   μόνο εκτελέσιμο αρχείο, τρέχει και τοπικά (π.χ. σε ένα VPS σου ή ακόμα
   και στο ίδιο το Linux desktop, αν θέλεις να είναι πάντα self-hosted).
2. Άνοιξε το Admin UI (συνήθως `http://<server>:8090/_/`) και κάνε
   δημιουργία λογαριασμού admin.
3. Πήγαινε **Collections -> New collection**, όνομα: `call_entries`,
   τύπος: **Base**.
4. Πρόσθεσε τα εξής πεδία:

   | Field name          | Type | Options                          |
   |----------------------|------|-----------------------------------|
   | `entry_id`           | Text | **Required**, **Unique** ✅ index |
   | `device_origin`      | Text | Required                          |
   | `payload`             | Text | Required (μεγάλο μέγεθος, είναι το κρυπτογραφημένο blob) |
   | `client_updated_at`  | Text | Required (ISO-8601 timestamp string, string ώστε να φιλτράρεται εύκολα) |

   (Τα `id`, `created`, `updated` τα διαχειρίζεται ήδη μόνο του το
   PocketBase — δεν τα πειράζουμε.)

5. Στο tab **API Rules** της συλλογής, όρισε ποιος επιτρέπεται να κάνει
   list/view/create/update:
   - Απλούστερη επιλογή (προσωπικό project, μόνο εσύ το χρησιμοποιείς):
     βάλε σε όλα τα rules `@request.auth.id != ""` ώστε να χρειάζεται
     τουλάχιστον ένας συνδεδεμένος χρήστης — και δημιούργησε έναν χρήστη
     για τον εαυτό σου (Collections -> `users` -> New record), μετά πάρε
     το **auth token** του (μέσω `/api/collections/users/auth-with-password`
     ή απλά από το Admin UI αν σου δίνει προσωρινό token).
   - Αυτό το token μπαίνει στο πεδίο **"PocketBase Admin/Auth Token"** της
     εφαρμογής (μαζί με τη διεύθυνση του server σου στο πεδίο URL).
   - ΣΗΜΕΙΩΣΗ ασφάλειας: μη χρησιμοποιείς το πραγματικό **superuser/admin**
     token σε συσκευή που μπορεί να χαθεί/κλαπεί (π.χ. κινητό) — προτίμησε
     πάντα ένα κανονικό PocketBase user token, περιορισμένο μόνο σε αυτή
     τη συλλογή μέσω των API Rules.

6. Τα δεδομένα στο `payload` είναι ήδη κρυπτογραφημένα από την εφαρμογή
   πριν φτάσουν εδώ — το PocketBase (και όποιος έχει πρόσβαση στη βάση
   του) βλέπει μόνο άσχετο base64 blob, ποτέ αριθμούς τηλεφώνου ή ονόματα.

Μόλις τα παραπάνω είναι έτοιμα:
- **PocketBase URL** στην εφαρμογή = π.χ. `https://my-pocketbase.example.com`
- **PocketBase Admin/Auth Token** = το token του βήματος 5
