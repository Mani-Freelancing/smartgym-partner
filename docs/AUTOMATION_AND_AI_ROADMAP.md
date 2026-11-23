# SmartGym OS — Automation & Zero/Minimal-Cost AI Roadmap

> **How to continue this in any future chat:**
> Simply write:
> `Read docs/AUTOMATION_AND_AI_ROADMAP.md and implement Phase 1` *(or Phase 2 / 3 / 4)*
> (Optionally trigger `/plan` before execution.)

---

## Current Baseline (Already Built)
- **Apps:** Flutter + BLoC dual entrypoints (`lib/main_partner.dart` & `lib/main_customer.dart`) backed by Firebase Auth + Cloud Firestore + strict tenant-scoped `firestore.rules`.
- **Attendance Check-in:** Local daily guard (`lib/data/services/attendance_guard_service.dart`) + Reception Floor QR verification (`customer_pass_screen.dart`) + `activeCrowd` increment/decrement.
- **Membership Dues & WhatsApp:** `dueAmount` tracking (`gym_member.dart`, `owner_revenue_screen.dart`) + 1-tap pre-filled WhatsApp launch (`lib/data/services/member_whatsapp_service.dart`).
- **AI Register Import:** Auto-rotating Gemini keys in `app_config/ai` + 100% free on-device fallback via `google_mlkit_text_recognition` (`lib/data/services/register_ai_importer_service.dart`).
- **Firebase Config (`firebase.json`):** Currently Firestore rules only (`functions/` and `firebase_messaging` are not set up yet).

---

## Better / Zero-to-Minimal-Cost Design Principles
Before blindly paying for SaaS tools, use this hybrid architecture to stay near **₹0/month at launch**:

1. **FCM Push First (₹0) + Direct Meta WhatsApp API (~₹0.115/msg, Zero Middleman Fee):**
   - Send daily reminders, meal reviews, and check-in confirmations via **Firebase Cloud Messaging (FCM)** for **₹0**.
   - Avoid paying ₹1,000–₹2,500/mo to third-party WhatsApp BSP dashboards (WATI / AiSensy / Interakt) by calling **Meta's direct WhatsApp Business Cloud API** straight from Cloud Functions (~₹0.115 + GST per utility template only for Day-1 Welcome Pass or 7-day inactive overdue rescue).
2. **₹0-Fee Owner UPI QR + ML Kit Screenshot Auto-Reader (vs. Razorpay 2% Fee):**
   - Keep zero-fee Merchant UPI QR (`upi://pay`) for budget-conscious gyms, paired with **on-device ML Kit OCR** to auto-extract UTR number & amount from payment screenshots at **₹0 cost**.
   - Offer **Razorpay (`razorpay_flutter` + webhook)** cleanly as the automated zero-touch option for gyms that want instant auto-renewal without manual checking.
3. **3-Tier Low-Cost AI Strategy:**
   - **Tier 1 (₹0 On-Device):** `google_mlkit_text_recognition` (register OCR fallback + UPI receipt UTR reader) and future ML Kit Pose Detection (rep counting / form checks).
   - **Tier 2 (Firestore Shared Cache = Near-₹0):** Cache common Indian gym meal macro estimates (`meal_macro_cache`) and workout split templates in Firestore so repeat lookups hit Firestore instead of paid LLM APIs.
   - **Tier 3 (Server-Side AI Proxy):** Move Gemini calls into Cloud Functions once `functions/` exists (protects API keys via Secret Manager, replaces `app_config/ai` client exposure, uses Flash-Lite for cheap text/macro tasks and Flash only for handwritten register photos).

---

## The 4 Implementation Phases

### Phase 1: Cloud Attendance Logs, Real Date Expiry & Free Push Notifications *(₹0 — Spark Plan OK)*
**Goal:** Persist real history in Firestore so both Owner analytics and Member streaks are accurate in the cloud, calculate expiry dynamically from dates, and enable free push notifications.
- [ ] Save every QR check-in and Slide-to-Walk-Out to `gyms/{gymId}/attendance/{logId}` (`memberId`, `phone`, `checkInAt`, `checkOutAt`, `durationMinutes`) and store `lastCheckInAt` + `streakDays` on `gyms/{gymId}/members/{memberId}`.
- [ ] Add `firestore.rules` rules for `attendance` (member creates own check-in/out within gym tenant; staff reads all).
- [ ] Compute/refresh `daysLeft` dynamically from `expiryDate` on app sync (not solely relying on the initial static integer).
- [ ] Add `firebase_messaging` + `flutter_local_notifications` to `pubspec.yaml`, request notification permission, and save device FCM tokens under `users/{uid}/fcmTokens` or `phone_index/{phone}`.

### Phase 2: Firebase Cloud Functions Backend & Midnight Cron Engine *(Requires Firebase Blaze Plan — ₹0 within Free Tier)*
**Goal:** Automate background jobs that still work even when the Owner's phone is switched off.
- [ ] Upgrade `smartgym-os` to Blaze Plan (set ₹200–₹500 billing budget alert) and run `firebase init functions` (TypeScript Node.js).
- [ ] **Daily Scheduled Function (00:05 AM IST):** Recalculate `daysLeft` for all active members across gyms, mark expired plans accurately, and reset stuck `activeCrowd` counters if anyone forgot to slide to walk out.
- [ ] **Daily Absent Radar Function (08:00 AM IST):** Query `lastCheckInAt < (now - 4 days)` and automatically populate `gyms/{gymId}/missing` for Trainers.
- [ ] **FCM Trigger Functions:** Send free push alerts when a meal gets trainer feedback (`meals` update), 3 days before expiry, or when a member enrolls/pays.
- [ ] **Secure Gemini AI Proxy Function:** Move `register_ai_importer_service.dart` + future Meal/Coach AI calls behind an authenticated Callable Cloud Function with per-gym daily rate limits + Firestore `meal_macro_cache`.

### Phase 3: Zero-Click Automated WhatsApp Cloud API *(Requires Meta Business Verification + Approved Templates)*
**Goal:** Replace manual `wa.me` link opens with automatic background WhatsApp delivery.
- [ ] Register Meta Business App + WhatsApp Business phone number and get approval for 3–4 Utility templates:
  1. `welcome_club_pass` (on enrollment)
  2. `membership_expiring_soon` (`daysLeft == 3` or `0`)
  3. `pending_fee_due_reminder` (`dueAmount > 0`)
  4. `payment_receipt_confirmed` (when due cleared or renewed)
- [ ] Cloud Function Firestore Trigger (`onDocumentCreated` on `gyms/{gymId}/members/{memberId}`): auto-send `welcome_club_pass`.
- [ ] Daily 09:00 AM IST Cron: auto-send `membership_expiring_soon` and `pending_fee_due_reminder` (skipping recently reminded members via `lastRemindedAt` cooldown field).

### Phase 4: Real Payment Gateway (`Razorpay`) & Webhook Auto-Renewal *(Requires Razorpay KYC)*
**Goal:** Turn `RenewMembershipViaUpiEvent` and due collection into real verified financial transactions.
- [ ] Upgrade `pubspec.yaml` with `razorpay_flutter` and configure Android/iOS keys.
- [ ] Cloud Function `createRenewalOrder`: validates gym fee/due from Firestore server-side and returns a Razorpay `order_id` or Payment Link (usable inside WhatsApp reminders).
- [ ] Cloud Function `razorpayWebhook`: verifies Razorpay `X-Razorpay-Signature` HMAC, atomically updates `feePaid`, `dueAmount = 0`, `expiryDate`, `daysLeft`, writes an immutable `payments/{paymentId}` ledger doc, and fires WhatsApp + FCM receipt.
- [ ] Optionally enable **ML Kit UPI Receipt OCR** in the existing manual UPI screenshot flow so zero-fee UPI QR payments auto-verify UTR & amount locally.
