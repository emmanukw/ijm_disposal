# IJM Disposal of Items — booking web app

A Flutter web app backed by Firebase (Firestore and Auth) for booking items that IJM is disposing of.

**Staff only.** Only people with a **verified @ijm.org email** can open the site. Staff create an account (name, @ijm.org email and password) and confirm it by clicking a link sent to their inbox. Admins listed in `admins` can sign in with any email.

**Staff (booking site `/`)**
- Live countdown to when booking opens or closes.
- Item cards show a photo, price, total quantity, pieces remaining and a progress bar.
- To book, staff confirm their name and choose a quantity. A Firestore transaction makes sure two people can never book the last piece.
- **Per-person booking limits** (set by the admin): a maximum per item and/or a maximum in total. The booking dialog shows how many more a person may book.
- When the quantity reaches 0, the item is greyed out and marked **FINISHED**.
- **Live bookings panel** on the main page: every booking (name, item, quantity, exact date and time), newest first, in its own scrollable box. New bookings appear instantly and are briefly highlighted. Read-only for staff.
- **View bookings** on each item card: the full list of who booked that item, how many and when.
- **Live bids** dashboard: totals, status per item (tap an item to see its bookings) and a live feed of every bid.

**Admin (`/admin`)**
- Add, edit and delete items. Photos are shrunk in the browser to small JPEG thumbnails.
- **Settings:** the event title, the opening and closing times (which drive the countdown) and the **booking limits per person**.
- **Bookings:** mark each booking **Paid** and/or **Collected**, add a note (e.g. an M-Pesa reference), search, and filter by Unpaid / Not collected / Collected. Totals show booked, paid and outstanding amounts. Only admins can see this page.
- Cancel a booking: the pieces go back in stock and the person's allowance is freed.
- Download a report as **Excel** (sheets: Bids, Items Summary and By Person) or **CSV**. Both include paid and collected status.

## One-time Firebase setup

1. Create a project at <https://console.firebase.google.com>. The free **Spark** plan is enough, because no Cloud Storage bucket is used.
2. **Build → Firestore Database → Create database** (production mode).
3. **Build → Authentication → Sign-in method**: enable **Email/Password**. Anonymous sign-in is not used; leave it disabled.
4. Authentication → Users → **Add user** for each admin (email and password). Copy the user's **UID**.
5. Firestore → start a collection `admins` → add a document whose **ID is that UID** (any field, e.g. `email: "..."`).
6. Connect the app to the project:
   ```bash
   npm i -g firebase-tools && firebase login
   dart pub global activate flutterfire_cli
   flutterfire configure --platforms=web     # overwrites lib/firebase_options.dart
   firebase use --add                         # pick your project
   ```
7. Deploy the security rules: `firebase deploy --only firestore:rules`
8. Sign in at `/admin` and open **Settings** to set the closing time (and any booking limits). Until a closing time is set, booking stays closed.

## Run and deploy

```bash
flutter run -d chrome                      # development
flutter build web --no-web-resources-cdn   # production build → build/web
firebase deploy --only hosting
```

## Local demo with emulators (no real project needed)

```bash
firebase emulators:start --only auth,firestore --project demo-ijm-disposal
python3 tool/seed_emulator.py              # sample data; admin = admin@ijm.org / admin123, staff = staff@ijm.org / staff123
# temporarily set projectId: 'demo-ijm-disposal' in lib/firebase_options.dart, then:
flutter run -d chrome --dart-define=USE_EMULATOR=true
```

## Where things live

| Path | Purpose |
|---|---|
| `lib/config.dart` | Currency (`KES`) and org name |
| `lib/theme.dart` | Colours, fonts, component styling |
| `lib/services/repository.dart` | All Firestore/Auth logic (booking transaction, CRUD) |
| `lib/services/report_service.dart` | CSV / Excel export |
| `lib/pages/home_page.dart` | Public site |
| `lib/pages/admin_page.dart` | Admin login, items, schedule, bids, reports |
| `lib/pages/login_page.dart` | Staff sign in, registration, email verification, password reset |
| `lib/widgets/admin_bids.dart` | Admin bookings page (paid / collected / notes) |
| `firestore.rules` | Security: verified @ijm.org staff (or admins) only. Only admins edit items and settings or see payment status. Staff can only create a valid bid, decrement stock by exactly that quantity, and stay within the per-person limits while booking is open |

## Data model

- `settings/auction` — `title`, `startsAt?`, `endsAt`, `maxPerItemPerPerson`, `maxTotalPerPerson` (0 = no limit)
- `items/{id}` — `name`, `description`, `imageBase64`, `quantity`, `remaining`, `price`, `createdAt`, `lastBidId`
- `bids/{id}` — `itemId`, `itemName`, `bidderName`, `email`, `quantity`, `unitPrice`, `uid`, `createdAt` (server time)
- `bidders/{uid}` — per-person running totals for limits: `name`, `email`, `total`, `items{itemId: count}`, `lastBidId`
- `bidStatus/{bidId}` — admin only: `paid`, `paidAt`, `collected`, `collectedAt`, `note`, `updatedBy`
- `admins/{uid}` — marks a user as admin (managed in the console only)

## Changing the staff email domain

Update `allowedEmailDomain` in `lib/config.dart` **and** `staffDomainRegex()` in `firestore.rules`, then redeploy both the rules and the hosting.

## Security rules test

With the emulators running and seeded (see above):

```bash
cd tool/rules_test && npm install && npm test
```

It tries 22 things an attacker or curious staff member might do, such as reading as an outsider, booking over the limit, editing their own tally or marking their own bid paid, and checks that each is allowed or denied as intended.
