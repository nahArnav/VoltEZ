# VoltEZ UI/UX Redesign Prompts for Figma

> **Design System Reference**
> - **Primary palette:** Emerald Green (#10B981), Deep Ocean Blue (#1E40AF), Warm Beige (#F5F0E8), Pure White (#FFFFFF)
> - **Accent palette:** Soft Teal (#14B8A6), Sky Blue (#38BDF8), Mint (#A7F3D0), Gold (#F59E0B)
> - **Neutrals:** Charcoal (#1F2937), Slate (#64748B), Light Gray (#E5E7EB), Off-White (#F9FAFB)
> - **Font:** Inter or Plus Jakarta Sans, weights 400–800
> - **Corner radius:** 16–24px cards, 12–16px buttons, 24px chips
> - **Style:** Clean, modern, trustworthy, premium EV-tech feel
> - **Platform:** Mobile-first Flutter, Android + iOS

---

## 01 — Driver Home Dashboard (Light Theme)

**Prompt:**
```
Design a premium light-mode mobile dashboard for an EV charging app called VoltEZ.
The background is warm beige (#F5F0E8). At the top, a greeting header showing
"Good evening, Swarali" in charcoal (#1F2937) 22px bold, with a notification bell
icon in a rounded emerald green (#10B981) circle on the right. Below, a large
battery status card with a soft gradient background (emerald green 10% to white),
showing "72%" in bold 40px deep ocean blue (#1E40AF), a thin emerald progress bar
(6px height, rounded), and three mini-metrics in a row: "38.9 kWh / Capacity",
"245 km / Range", "CCS2 / Connector". Each metric has a small icon above in
emerald green. Below the battery card, a search bar with rounded corners (white
fill, subtle shadow, emerald border at 20% opacity, magnifying glass icon left,
placeholder text "Search destination or charger..." in slate gray). Below that,
four quick-action tiles in a horizontal row: "Route Planner", "Find Charger",
"Active Session", "Booking History" — each with a rounded square icon container
(soft teal, sky blue, emerald, gold backgrounds at 12% opacity) and label text
below in charcoal. At the bottom, a section header "NEARBY CHARGERS" with a thin
beige divider and "See all" link in emerald. Below it, a charger card: white
card (#FFFFFF) with 20px border radius, soft shadow (0 4px 20px rgba(0,0,0,0.06)),
a circular charger avatar (emerald gradient), charger name "Phoenix Mall Charger"
in 16px bold charcoal, address in slate 12px, a status chip "AVAILABLE" in mint
green pill, and three metric icons (bolt for 60 kW, rupee for ₹14/kWh, star
for 4.6). Amenities shown as small beige chips: "WiFi", "Food Court", "Parking".
Overall feel: clean, trustworthy, premium, warm, mobile-first. Light and airy
with green-blue accent pops on a warm beige canvas.
```

---

## 02 — Active Charging Session Banner

**Prompt:**
```
Design an active session banner for an EV charging app (VoltEZ). Warm beige
background (#F5F0E8). The banner has a soft gradient border from emerald green
to deep ocean blue. Inside: on the left, a pulsing emerald green circle with a
white bolt icon. In the middle, uppercase "CHARGING NOW" label in emerald green
11px bold with 1px letter-spacing, and below it the charger name "Phoenix Mall
Charger" in charcoal 16px bold. On the right, a large "68%" in deep ocean blue
24px weight-800, and a small forward arrow icon in emerald. The banner should
feel alive and urgent — like a live status indicator. Corner radius 18px.
Padding 16px. White card background with subtle emerald glow shadow.
```

---

## 03 — Battery Status Card (Detailed)

**Prompt:**
```
Design a detailed battery status card for an electric vehicle dashboard app.
White card background (#FFFFFF) with a soft gradient from emerald green (8%
opacity) to solid white, corner radius 22px, subtle shadow (0 2px 16px
rgba(16,185,129,0.08)). Top-left: small uppercase label "BATTERY STATUS" in
emerald green, 10px, weight-700, letter-spacing 1.4. Top-right: large "72%"
in deep ocean blue (#1E40AF), 40px, weight-800. Below, a thin horizontal
progress bar (8px height, emerald fill, light beige background, rounded 6px).
Below the bar, three metrics in a centered row: icon + value + label — bolt
icon in emerald + "38.9 kWh" in charcoal 16px bold + "Capacity" in slate 11px,
route icon in blue + "245 km" in charcoal + "Range" in slate, ev_station icon
in teal + "CCS2" in charcoal + "Connector" in slate. When battery is below 20%,
the card shifts to warm amber/gold gradient.
```

---

## 04 — Charger Card Component (Light Theme)

**Prompt:**
```
Design a charger card component for an EV charging app (VoltEZ). White card
(#FFFFFF) with rounded corners (20px), a subtle border (1px, emerald at 10%
opacity), and a soft shadow (0 4px 20px rgba(0,0,0,0.06)). Inside: top row
has a circular avatar (54px, emerald gradient fill at 20% opacity, emerald
ev_station icon 28px), charger name "Phoenix Mall Charger" (16px bold
charcoal, max 1 line, ellipsis), address "Phoenix Mall, 2.3 km away" (12px
slate), and a status chip pill on the right ("AVAILABLE" in mint green pill,
or "IN USE" in warm amber, or "OFFLINE" in light gray). Below, a metrics
row with three items evenly spaced: bolt icon in emerald + "60 kW" + "kW"
label in slate, rupee icon in blue + "14" + "/kWh" label, star icon in gold
+ "4.6" + "Rating" label. Below, amenities as small beige pill chips: "WiFi",
"Food Court", "Parking". The card should feel clean, scannable, and premium.
Mobile-first layout, 20px page margin. Light background with green-blue accent.
```

---

## 05 — Route Planner Input Screen

**Prompt:**
```
Design a route planner input screen for an EV charging app (VoltEZ). Warm beige
background (#F5F0E8). A top app bar with a back arrow and title "Route Planner"
in 22px bold charcoal, with a small subtitle "Plan your trip and find the best
charging stop" in slate 12px. The form contains: 1) Origin field — white card
input (#FFFFFF), rounded 16px, with a location pin icon in emerald, placeholder
"Starting point (or use current location)", and a small emerald text link "Use
Current Location" below right. 2) Destination field — same style, placeholder
"Where are you going?". 3) Vehicle selector — dropdown showing current vehicle
name and specs (e.g. "Tata Nexon EV | 30.2 kWh | CCS2"). 4) Battery SOC slider
— horizontal slider from 0% to 100%, with current value displayed as large
text "62%" in deep ocean blue 28px bold above the slider, and label "Current
Battery" in slate. Slider track is light beige, filled portion is emerald
gradient. 5) Reserve SOC slider — same style, default 15%, label "Reserve
Battery". 6) Preferred connector chips: "CCS2", "Type 2", "CHAdeMO" as
selectable pill chips in emerald when selected. Below the form, a large CTA
button "FIND BEST CHARGING STOP" in deep ocean blue (#1E40AF) with white
text, full width, rounded 16px, height 52px. The form should be scrollable
and feel clean, warm, and minimal.
```

---

## 06 — Route Recommendations (Top 3)

**Prompt:**
```
Design a charger recommendations screen showing top 3 results for an EV
charging app (VoltEZ). Warm beige background (#F5F0E8). A custom header
with back arrow, title "Recommendations" in 18px bold charcoal, subtitle
"Top picks for your route" in slate 11px, and a "New Search" button (white
card pill with emerald border). Below, a summary card (white #FFFFFF, rounded
20px, soft shadow): emerald checkmark + "Route Analysis Complete" in emerald
bold, then three summary chips in a row — car icon + "Tata Nexon EV" in
blue, bolt icon + "18 kWh needed" in amber, ev_station icon + "3 options"
in teal. Route text below: "Mumbai → Pune" in slate.

Below the summary, "Top Recommendations" headline with a "TOP 3" emerald
pill badge. Then three recommendation cards stacked vertically:

Card #1 (Best Overall): rank badge "#1" in emerald rounded square, charger
name "VoltEZ Central Mall", address in slate, "Best Overall" tag in emerald
pill. Metrics grid: 2 columns x 2 rows — "6 min detour" with route icon,
"0 min wait" with clock icon, "27 min charging" with bolt icon, "₹205" with
rupee icon. Below: connector badge "CCS2 • 60 kW" in a small outlined pill.
Expandable section "Why this charger?" with chevron — when expanded, shows
explanation chips: "Compatible with your vehicle", "No queue expected", "High
reliability (94%)", "Short detour". Bottom row: "94% match" emerald chip on
left, "DETAILS" button + "BOOK NOW" deep ocean blue button on right.

Card #2 (Fastest): rank "#2" in blue, blue "Fastest" tag.
Card #3 (Cheapest): rank "#3" in teal, teal "Cheapest" tag.

Card #1 should have a subtle emerald glow shadow to feel prioritized.
All cards: white #FFFFFF, rounded 20px, 18px padding, soft shadows.
```

---

## 07 — Loading / Skeleton State (Recommendations)

**Prompt:**
```
Design a loading/skeleton state for an EV charger recommendations screen
(VoltEZ). Warm beige background (#F5F0E8). At the top, a pulsing circular
icon (80px, emerald border at 25% opacity, emerald auto_awesome icon inside)
with animation opacity cycling 0.4–1.0. Below: "Finding best chargers..."
in charcoal 26px bold, and "Scanning compatible stations along your route"
in slate 14px. Below, three skeleton cards stacked vertically. Each skeleton
card: white card (#FFFFFF), rounded 20px, soft shadow. Inside: a row with a
36x36 rounded shimmer box (avatar placeholder), a column of two shimmer boxes
(140x14 and 200x10 for name and address), then a large shimmer bar (full
width x 48px, rounded 14px for metrics area) and another full-width shimmer
bar (full width x 36px, rounded 10px). All shimmer boxes are light beige
(#E5E7EB). The overall effect should feel like a premium loading experience,
not a generic spinner.
```

---

## 08 — Charger Details Screen

**Prompt:**
```
Design a charger details screen for an EV charging app (VoltEZ). Warm beige
background (#F5F0E8). Top: back arrow + charger name "VoltEZ Central Mall"
in 22px bold charcoal. Below the name, a status badge "Available" in emerald
green pill, and below that: "CCS2 • 60 kW" in a small outlined chip with
emerald text.

A large map placeholder area (white card, rounded 20px, with a map pin icon
in emerald centered) taking about 35% of screen height.

Below the map, a metrics card (white #FFFFFF, rounded 20px, soft shadow):
two columns of metric tiles — "6 min detour" with route icon in blue, "94%
reliability" with shield icon in emerald, "₹14/kWh" with rupee icon in
charcoal, "Recently confirmed" with checkmark icon in teal. Each tile: icon
on top in its accent color, value in charcoal 16px bold, label in slate 11px
uppercase.

Next, "Amenities" section with horizontal scrollable chips: "WiFi", "Food
Court", "Parking", "Restroom", "24/7" — each a small white card pill with
beige border.

Next, "Available Ports" section: a card showing port "Port 1 — CCS2, 60 kW,
Available" with an emerald dot, and "Port 2 — CCS2, 60 kW, In Use" with an
amber dot.

Bottom: a large CTA "SELECT & BOOK" in deep ocean blue (#1E40AF), full width,
rounded 16px, height 52px. Above it, a smaller "Open in Maps" text link in
emerald.
```

---

## 09 — Slot Selection Grid

**Prompt:**
```
Design a slot selection screen for an EV charging booking flow (VoltEZ).
Warm beige background (#F5F0E8). At the top, a compact charger info bar
(white card, rounded 16px): ev_station icon in emerald square, charger name
"VoltEZ Central Mall" in 16px bold charcoal, and specs "60 kW · CCS2 ·
₹14/kWh" in slate 12px.

Below: "Available Slots — Today" in 18px bold charcoal, subtitle "Select a
slot to hold it for 5 minutes" in slate 11px.

Then a 2-column grid of slot cards. Each slot card: white card (#FFFFFF),
rounded 16px, 12px padding. Available slots show time range "14:00 – 14:30"
in charcoal 13px bold and "₹14/kWh" in emerald 11px. Occupied slots are
dimmed (50% opacity, slate text, status "Occupied"). Offline slots show
"Offline" in red text. A selected/held slot has an emerald border, emerald
background at 8%, and "HELD" label in emerald.

Grid aspect ratio 2:1 (wider than tall), 10px spacing.

Above the grid, if a slot is being held: a countdown banner (amber
background at 8%, amber border) with hourglass icon, "Slot held — confirm
within:" text, large countdown timer "04:32" in amber 28px monospace
weight-800, and a "CONTINUE" button in deep ocean blue.
```

---

## 10 — Hold Countdown + Payment Flow

**Prompt:**
```
Design a hold countdown and payment screen for an EV booking flow (VoltEZ).
Warm beige background (#F5F0E8). At the top, a large countdown section: amber
border white card with timer icon, "SLOT HELD" in amber 11px bold uppercase,
countdown "03:45" in amber 40px monospace weight-800 with pulsing animation.
Below: slot details — "2:30 PM – 3:15 PM" in charcoal 16px bold, "CCS2 • 60
kW" in slate.

A divider line, then "Estimated Cost" section: large "₹205" in charcoal 28px
weight-800, breakdown below: "14.6 kWh × ₹14/kWh" in slate 12px.

Below, a "Payment Method" section: white card with UPI icon + "Google Pay"
selected (emerald checkmark), and other options below (PhonePe, Card).

A prominent "PAY ₹205 & CONFIRM" button in deep ocean blue (#1E40AF), full
width, rounded 16px, height 52px. Below: "Cancel Booking" text link in red/muted.

At the bottom, a note: "Backend confirms payment. You'll receive a
confirmation within seconds." in slate 10px italic.

When countdown reaches under 1 minute, the border and timer shift to red.
When expired: red banner "Slot Expired", dimmed content, "Choose Another
Slot" button in red.
```

---

## 11 — Booking Confirmation

**Prompt:**
```
Design a booking confirmation screen for an EV charging app (VoltEZ). Warm
beige background (#F5F0E8). At the top center: a large emerald green circle
(80px) with a white checkmark icon, below it "Booking Confirmed" in emerald
green 28px weight-800. Below that, a unique booking ID "#BK-2847" in slate
12px monospace.

A confirmation card (white #FFFFFF, rounded 20px, subtle emerald border at
15%): rows of details — "Charger" → "VoltEZ Central Mall", "Date" → "August
26, 2026", "Time" → "2:30 PM – 3:15 PM", "Connector" → "CCS2 • 60 kW",
"Estimated Cost" → "₹205". Each row: label in slate 12px uppercase on left,
value in charcoal 14px bold on right, separated by thin beige divider.

Below the card, two buttons: primary "START NAVIGATION" in deep ocean blue
(full width, with map icon), and secondary "VIEW BOOKING DETAILS" outlined
button (white card with emerald border). Both rounded 16px.

Below: "What's next?" section with three steps: 1) Navigate to charger
(icon + text), 2) Check in at port (icon + text), 3) Start charging
(icon + text). Each step has a number circle in emerald and connecting line.
```

---

## 12 — Business Dashboard (Owner Side)

**Prompt:**
```
Design a business owner dashboard for an EV charging platform (VoltEZ). Warm
beige background (#F5F0E8). Top: "VOLTEZ / BUSINESS" label in emerald 11px
weight-700 letter-spacing 2.5, greeting "Good evening, ABC Motors." in
charcoal 28px weight-800, notification bell in emerald circle.

Section "TODAY AT A GLANCE" with four stat cards in 2x2 grid: "08 ACTIVE
CHARGERS" (emerald accent), "24 BOOKINGS TODAY" (blue accent), "₹18.4K
REVENUE TODAY" (charcoal accent), "76% UTILIZATION" (teal accent). Each
card: white background, rounded 16px, subtle shadow, colored accent bar
on top.

Section "YOUR CHARGERS" with a white card list: three charger rows with
icon, name, type, and status dot (green/amber/gray). "ADD CHARGER" button
in emerald outline.

Section "TODAY'S BOOKINGS" with a white card: three booking rows with time,
customer name, charger, and status badge.

Section "NETWORK UTILIZATION" with a teal gradient card showing "76%" large
number and a 7-day bar chart in white bars.

Section "VOLTEZ INSIGHT" with a white card: AI recommendation with gold
icon, insight text, and "View recommendation →" link in emerald.

Bottom navigation: Home, Chargers, Bookings, Analytics, Profile — with
emerald active state. Overall feel: professional, clean, data-rich but
not cluttered. Warm and trustworthy.
```

---

## 13 — Charger Management (Business Side)

**Prompt:**
```
Design a charger management screen for a business owner (VoltEZ). Warm beige
background (#F5F0E8). Top app bar with back arrow and "Charger Fleet" in
charcoal 20px bold.

Filter row: "All" chip (emerald, selected), "Active" chip, "Paused" chip,
"Offline" chip — horizontal scrollable.

Charger list: white cards with charger icon (emerald circle), name in bold
charcoal, type + power in slate, status dot, price per kWh, reliability
score as a small progress bar. Swipe actions: Pause/Resume, Edit, Delete.

"Add New Charger" floating action button in emerald with + icon.

Each charger card expandable to show ports: list of ports with connector
type, power, status toggle (green/gray switch), and "Manage Availability"
link.

Bottom sheet for adding charger: form with name, power, access type, price,
location pin on mini map, amenity checkboxes. "Save Charger" button in
deep ocean blue.
```

---

## 14 — Availability Scheduler (Business Side)

**Prompt:**
```
Design an availability scheduler screen for a charger port (VoltEZ). Warm
beige background (#F5F0E8). Top: port info bar — "Port 1 — CCS2, 60 kW"
with status dot.

Weekly calendar view: 7 day columns, each with time slots from 6 AM to 10 PM.
Available slots shown in emerald, occupied in amber, offline in gray. User
can tap to create new slot or drag to extend.

"Create New Slot" button in emerald. Bottom sheet form: start time, end time,
price override slider (₹10–₹25/kWh), repeat weekly toggle, "Save" button
in deep ocean blue.

List of upcoming slots below calendar: white cards with date, time range,
price, status, and edit/delete icons. "Bulk Actions" option for selecting
multiple slots.
```

---

## 15 — Profile Screen (Driver Side)

**Prompt:**
```
Design a driver profile screen for VoltEZ. Warm beige background (#F5F0E8).
Top: large avatar circle with emerald gradient, user name "Swarali" in
charcoal 24px bold, "Driver" label in slate.

Profile options as white cards with emerald icons: "My Vehicle" (car icon,
"Tata Nexon EV, 2024"), "Booking History" (receipt icon), "Payment Methods"
(card icon), "Notifications" (bell icon), "Help & Support" (question icon),
"About VoltEZ" (info icon, "Version 1.0.0"). Each card has right arrow in
slate.

"Logout" button at bottom in red outline.

Overall feel: clean, organized, easy to scan. Each option is a tappable
white card with consistent spacing and emerald icon accents.
```

---

## 16 — Onboarding Flow (Driver)

**Prompt:**
```
Design a 3-step onboarding flow for new EV drivers on VoltEZ. Warm beige
background (#F5F0E8).

Step 1: "Welcome to VoltEZ" — large emerald bolt icon, headline in charcoal
28px, subtitle "Your smart EV charging companion" in slate, illustration
of an EV charging. "Get Started" button in deep ocean blue.

Step 2: "Add Your Vehicle" — form card (white, rounded 20px): vehicle make
dropdown, model dropdown, battery capacity input, connector type chips
(CCS2, Type 2, CHAdeMO) as selectable pills. "Next" button in emerald.

Step 3: "Set Your Preferences" — preferred connector chips, max detour
distance slider, notification toggles (booking confirmations, slot reminders,
price alerts). "Finish Setup" button in deep ocean blue with emerald
checkmark.

Progress dots at bottom: 3 dots, current step filled in emerald, others
in beige. Smooth page transitions. "Skip" link in slate for each step.
```

---

## General Design Principles to Apply

1. **Consistent spacing:** 8px grid system (8, 16, 24, 32, 40, 48)
2. **Typography hierarchy:** Display (28–32px), Headline (20–24px), Body (14–16px), Label (10–12px), Caption (8–10px)
3. **Elevation:** Use soft shadows (0 2px 16px rgba(0,0,0,0.06)) instead of hard borders
4. **Color usage:** Emerald for primary actions, Deep Ocean Blue for CTAs and headings, Beige for backgrounds, White for cards
5. **States:** Every interactive element needs default, pressed, disabled, loading, and error states
6. **Accessibility:** Minimum 4.5:1 contrast ratio for text, 44x44px minimum tap targets
7. **Dark mode:** Create a companion dark theme using Charcoal (#1F2937) background, Dark Slate (#374151) cards, with the same green/blue accents
