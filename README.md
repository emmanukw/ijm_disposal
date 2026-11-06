# IJM Disposal of Items — booking web app

A Flutter web app backed by Firebase (Firestore and Auth) for booking items that IJM is disposing of.

**Bidders (public site `/`)**
- Live countdown to when booking opens or closes.
- Item cards show a photo, price, total quantity, pieces remaining and a progress bar.
- To book, bidders enter their name and choose a quantity. A Firestore transaction makes sure two people can never book the last piece.
- When the quantity reaches 0, the item is greyed out and marked **FINISHED**.
- **Live bids** dashboard, visible to everyone: totals, status per item (who booked) and a live feed of every bid with its date and time.

**Admin (`/admin`)**
- Add, edit and delete items. Photos are shrunk in the browser to small JPEG thumbnails.
- Set the event title and the opening and closing times, which drive the countdown.
- See all bids. An admin can cancel a bid, which puts the pieces back in stock.
- Download a report as **Excel** (sheets: Bids and Items Summary) or **CSV**.

## One-time Firebase setup

1. Create a project at <https://console.firebase.google.com>. The free **Spark** plan is enough, because no Cloud Storage bucket is used.
2. **Build → Firestore Database → Create database** (production mode).
3. **Build → Authentication → Sign-in method**: enable **Anonymous** (for bidders) and **Email/Password** (for admins).
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
8. Sign in at `/admin` and open **Schedule** to set the closing time. Until a closing time is set, booking stays closed.

## Run and deploy

```bash
flutter run -d chrome                      # development
flutter build web --no-web-resources-cdn   # production build → build/web
firebase deploy --only hosting
```

## Local demo with emulators (no real project needed)

```bash
firebase emulators:start --only auth,firestore --project demo-ijm-disposal
python3 tool/seed_emulator.py              # sample items/bids; admin = admin@ijm.org / admin123
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
| `firestore.rules` | Security: only admins edit items/schedule; bidders can only create a valid bid and decrement stock by exactly that bid's quantity while booking is open |

## Data model

- `settings/auction` — `title`, `startsAt?`, `endsAt`
- `items/{id}` — `name`, `description`, `imageBase64`, `quantity`, `remaining`, `price`, `createdAt`, `lastBidId`
- `bids/{id}` — `itemId`, `itemName`, `bidderName`, `quantity`, `unitPrice`, `uid`, `createdAt` (server time)
- `admins/{uid}` — marks a user as admin (managed in the console only)
