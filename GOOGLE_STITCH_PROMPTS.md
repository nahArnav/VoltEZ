# VoltEZ — Google Stitch UI Improvement Prompts

> **Design System Reference**
> - **Dark theme**: Midnight Navy `#0A0F1F`, Graphite `#111827`, Surface `#1A2332`
> - **Accents**: Electric Cyan `#00E5FF`, Ion Blue `#3B82F6`, Emerald `#34D399`, Amber `#F59E0B`, Red `#EF4444`
> - **Font**: Inter (Google Fonts), weights 500–900
> - **Corner radius**: 12–22px cards, 10–14px buttons, 20px chips
> - **Border style**: 1px subtle borders with accent at 15–25% opacity
> - **Platform**: Mobile-first Flutter, Android + iOS

---

## 01 — Driver Home Dashboard

**Prompt:**
```
Design a premium dark-mode mobile dashboard for an EV charging app called VoltEZ.
The background is deep midnight navy (#0A0F1F). At the top, a greeting header
showing "Good evening, Swarali" with a notification bell icon in a rounded
cyan square. Below, a large battery status card with a gradient background
(emerald to dark), showing "72%" in bold 36px white text, a cyan progress
bar (thin 8px), and three mini-metrics in a row: "38.9 kWh / Capacity",
"245 km / Range", "CCS2 / Connector". Each metric has a small icon above
the value. Below the battery card, a search bar with rounded corners
(dark graphite fill, cyan border at 20% opacity, magnifying glass icon
left, placeholder text "Search destination or charger..."). Below that,
four quick-action tiles in a horizontal row: "Route Planner", "Find Charger",
"Active Session", "Booking History" — each with a rounded square icon
container (different accent colors at 12% opacity fill) and label text
below. At the bottom of the visible area, a section header "01 — NEARBY
CHARGERS" with a horizontal divider line and "See all" link. Below it,
a charger card: dark card (#111827) with cyan border at 18% opacity,
a circular charger avatar (cyan gradient), charger name "Phoenix Mall
Charger" in 16px bold white, address in grey 12px, a status chip
"AVAILABLE" in green pill, and three metric icons (bolt for 60 kW,
rupee for ₹14/kWh, star for 4.6). Amenities shown as small grey
chips: "WiFi", "Food Court", "Parking". Overall feel: modern, premium,
EV-tech, minimal, mobile-first.
```

---

## 02 — Active Charging Session Banner

**Prompt:**
```
Design an active session banner for an EV charging app (VoltEZ). Dark
midnight navy background. The banner has a gradient border from emerald
green to electric cyan. Inside: on the left, a pulsing emerald green
circle with a bolt icon. In the middle, uppercase "CHARGING NOW" label
in emerald green 11px bold with 1px letter-spacing, and below it the
charger name "Phoenix Mall Charger" in white 16px bold. On the right,
a large "68%" in emerald green 24px weight-900, and a small forward
arrow icon. The banner should feel alive and urgent — like a live
status indicator. Corner radius 18px. Padding 16px.
```

---

## 03 — Battery Status Card (Detailed)

**Prompt:**
```
Design a detailed battery status card for an electric vehicle dashboard
app. Dark card background (#111827) with a gradient from emerald green
(15% opacity) to solid dark, corner radius 22px, border 1px emerald
at 30% opacity. Top-left: small uppercase label "BATTERY STATUS" in
emerald green, 10px, weight-800, letter-spacing 1.4. Top-right: large
"72%" in emerald green, 36px, weight-900. Below, a thin horizontal
progress bar (8px height, emerald fill, dark surface background,
rounded 6px). Below the bar, three metrics in a centered row: icon
+ value + label — bolt icon + "38.9 kWh" + "Capacity", route icon +
"245 km" + "Range", ev_station icon + "CCS2" + "Connector". Icons
are 22px, values are white 16px bold, labels are grey 11px uppercase
with letter-spacing 1.0. When battery is below 20%, the card shifts
to amber/red gradient.
```

---

## 04 — Charger Card Component

**Prompt:**
```
Design a charger card component for an EV charging app (VoltEZ). Dark
card (#111827) with rounded corners (18px), a subtle border (1px,
electric cyan at 18% opacity), and a faint cyan glow shadow (blur 16px,
cyan at 6%). Inside: top row has a circular avatar (54px, cyan gradient
fill at 35% opacity, electric cyan ev_station icon 28px), charger name
"Phoenix Mall Charger" (16px bold white, max 1 line, ellipsis), address
"Phoenix Mall, 2.3 km away" (12px grey), and a status chip pill on
the right ("AVAILABLE" in emerald green pill, or "IN USE" in amber, or
"OFFLINE" in grey). Below, a metrics row with three items evenly spaced:
bolt icon + "60 kW" + "kW" label, rupee icon + "14" + "/kWh" label,
star icon + "4.6" + "Rating" label. Below, amenities as small grey
pill chips: "WiFi", "Food Court", "Parking". The card should feel
clean, scannable, and premium. Mobile-first layout, 20px page margin.
```

---

## 05 — Route Planner Input Screen

**Prompt:**
```
Design a route planner input screen for an EV charging app (VoltEZ). Dark
midnight navy background (#0A0F1F). A top app bar with a back arrow and
title "Route Planner" in 22px bold white, with a small subtitle "Plan
your trip and find the best charging stop" in grey 12px. The form
contains: 1) Origin field — dark surface input (#1A2332), rounded 12px,
with a location pin icon, placeholder "Starting point (or use current
location)", and a small cyan text link "Use Current Location" below
right. 2) Destination field — same style, placeholder "Where are you
going?". 3) Vehicle selector — dropdown showing current vehicle name
and specs (e.g. "Tata Nexon EV | 30.2 kWh | CCS2"). 4) Battery SOC
slider — horizontal slider from 0% to 100%, with current value displayed
as large text "62%" in cyan 28px bold above the slider, and label
"Current Battery" in grey. Slider track is dark, filled portion is
cyan gradient. 5) Reserve SOC slider — same style, default 15%,
label "Reserve Battery". 6) Preferred connector chips: "CCS2",
"Type 2", "CHAdeMO" as selectable pill chips. Below the form, a
large CTA button "FIND BEST CHARGING STOP" in electric cyan (#00E5FF)
with dark text, full width, rounded 14px, height 52px. The form should
be scrollable and feel clean and minimal.
```

---

## 06 — Route Recommendations (Top 3)

**Prompt:**
```
Design a charger recommendations screen showing top 3 results for an EV
charging app (VoltEZ). Dark midnight navy background. A custom header
with back arrow, title "Recommendations" in 18px bold, subtitle "Top
picks for your route" in grey 11px, and a "New Search" button (dark
surface pill with border). Below, a summary card (dark #111827, rounded
18px, cyan border at 15%): emerald checkmark + "Route Analysis Complete"
in green bold, then three summary chips in a row — car icon + "Tata
Nexon EV" in cyan, bolt icon + "18 kWh needed" in amber, ev_station
icon + "3 options" in blue. Route text below: "Mumbai → Pune" in grey.

Below the summary, "Top Recommendations" headline with a "TOP 3" cyan
pill badge. Then three recommendation cards stacked vertically:

Card #1 (Best Overall): rank badge "#1" in cyan rounded square,
charger name "VoltEZ Central Mall", address in grey, "Best Overall"
tag in cyan pill. Metrics grid: 2 columns × 2 rows — "6 min detour"
with route icon, "0 min wait" with clock icon, "27 min charging"
with bolt icon, "₹205" with rupee icon. Below: connector badge
"CCS2 • 60 kW" in a small outlined pill. Expandable section
"Why this charger?" with chevron — when expanded, shows explanation
chips: "Compatible with your vehicle", "No queue expected", "High
reliability (94%)", "Short detour". Bottom row: "94% match" cyan
chip on left, "DETAILS" button + "BOOK NOW" cyan button on right.

Card #2 (Fastest): rank "#2" in blue, blue "Fastest" tag.
Card #3 (Cheapest): rank "#3" in green, green "Cheapest" tag.

Card #1 should have a subtle cyan glow shadow to feel prioritized.
All cards: dark #111827, rounded 20px, 18px padding.
```

---

## 07 — Loading / Skeleton State (Recommendations)

**Prompt:**
```
Design a loading/skeleton state for an EV charger recommendations screen
(VoltEZ). Dark midnight navy background. At the top, a pulsing circular
icon (80px, cyan border at 25% opacity, cyan auto_awesome icon inside)
with animation opacity cycling 0.4–1.0. Below: "Finding best chargers..."
in white 26px bold, and "Scanning compatible stations along your route"
in grey 14px. Below, three skeleton cards stacked vertically. Each
skeleton card: dark card (#111827), rounded 20px, 1px border. Inside:
a row with a 36×36 rounded shimmer box (avatar placeholder), a column
of two shimmer boxes (140×14 and 200×10 for name and address), then a
large shimmer bar (full width × 48px, rounded 14px for metrics area)
and another full-width shimmer bar (full width × 36px, rounded 10px).
All shimmer boxes are surface-colored (#1A2332). The overall effect
should feel like a premium loading experience, not a generic spinner.
```

---

## 08 — Charger Details Screen

**Prompt:**
```
Design a charger details screen for an EV charging app (VoltEZ). Dark
midnight navy background. Top: back arrow + charger name "VoltEZ Central
Mall" in 22px bold white. Below the name, a status badge "Available" in
emerald green pill, and below that: "CCS2 • 60 kW" in a small outlined
chip with cyan text.

A large map placeholder area (dark surface, rounded 18px, with a map
pin icon centered) taking about 35% of screen height.

Below the map, a metrics card (dark #111827, rounded 18px): two columns
of metric tiles — "6 min detour" with route icon, "94% reliability"
with shield icon, "₹14/kWh" with rupee icon, "Recently confirmed"
with checkmark icon. Each tile: icon on top in accent color, value
in white 16px bold, label in grey 11px uppercase.

Next, "Amenities" section with horizontal scrollable chips: "WiFi",
"Food Court", "Parking", "Restroom", "24/7" — each a small dark pill
with grey border.

Next, "Available Ports" section: a card showing port "Port 1 — CCS2,
60 kW, Available" with a green dot, and "Port 2 — CCS2, 60 kW, In Use"
with an amber dot.

Bottom: a large CTA "SELECT & BOOK" in electric cyan (#00E5FF), full
width, rounded 14px, height 52px. Above it, a smaller "Open in Maps"
text link in cyan.
```

---

## 09 — Slot Selection Grid

**Prompt:**
```
Design a slot selection screen for an EV charging booking flow (VoltEZ).
Dark midnight navy background. At the top, a compact charger info bar
(dark #111827 card, rounded 14px): ev_station icon in cyan square,
charger name "VoltEZ Central Mall" in 16px bold, and specs
"60 kW · CCS2 · ₹14/kWh" in grey 12px.

Below: "Available Slots — Today" in 18px bold white, subtitle "Select
a slot to hold it for 5 minutes" in grey 11px.

Then a 2-column grid of slot cards. Each slot card: dark card
(#111827), rounded 14px, 12px padding. Available slots show time range
"14:00 – 14:30" in white 13px bold and "₹14/kWh" in green 11px.
Occupied slots are dimmed (50% opacity, grey text, status "Occupied").
Offline slots show "Offline" in red text. A selected/held slot has a
cyan border, cyan background at 15%, and "HELD" label in cyan.

Grid aspect ratio 2:1 (wider than tall), 10px spacing.

Above the grid, if a slot is being held: a countdown banner (amber
background at 10%, amber border) with hourglass icon, "Slot held —
confirm within:" text, large countdown timer "04:32" in amber 28px
monospace weight-900, and a "CONTINUE" button.
```

---

## 10 — Hold Countdown + Payment Flow

**Prompt:**
```
Design a hold countdown and payment screen for an EV booking flow
(VoltEZ). Dark midnight navy background. At the top, a large countdown
section: amber border card with timer icon, "SLOT HELD" in amber
11px bold uppercase, countdown "03:45" in amber 40px monospace
weight-900 with pulsing animation. Below: slot details — "2:30 PM –
3:15 PM" in white 16px bold, "CCS2 • 60 kW" in grey.

A divider line, then "Estimated Cost" section: large "₹205" in
white 28px weight-900, breakdown below: "14.6 kWh × ₹14/kWh" in
grey 12px.

Below, a "Payment Method" section: dark card with UPI icon + "Google
Pay" selected (cyan checkmark), and other options below (PhonePe, Card).

A prominent "PAY ₹205 & CONFIRM" button in electric cyan (#00E5FF),
full width, rounded 14px, height 52px. Below: "Cancel Booking" text
link in red/muted.

At the bottom, a note: "Backend confirms payment. You'll receive a
confirmation within seconds." in grey 10px italic.

When countdown reaches under 1 minute, the border and timer shift to
red. When expired: red banner "Slot Expired", dimmed content, "Choose
Another Slot" button in red.
```

---

## 11 — Booking Confirmation

**Prompt:**
```
Design a booking confirmation screen for an EV charging app (VoltEZ).
Dark midnight navy background. At the top center: a large emerald green
circle (80px) with a white checkmark icon, below it "Booking Confirmed"
in emerald green 26px weight-900. Below that, a unique booking ID
"#BK-2847" in grey 12px monospace.

A confirmation card (dark #111827, rounded 18px, subtle green border
at 20%): rows of details — "Charger" → "VoltEZ Central Mall", "Date"
→ "August 26, 2026", "Time" → "2:30 PM – 3:15 PM", "Connector"
→ "CCS2 • 60 kW", "Estimated Cost" → "₹205". Each row: label in
grey 12px uppercase on left, value in white 14px bold on right,
separated by thin dark divider.

Below the card, two buttons: primary "START NAVIGATION" in electric
cyan (full width, with map icon), and secondary "VIEW BOOKING DETAILS"
outlined button (dark surface with border). Both rounded 14px.

Below: "We'll send you reminders before your slot starts" in grey
11px centered text. Overall feel: celebratory but minimal, trustworthy.
```

---

## 12 — Live Charging Session Dashboard

**Prompt:**
```
Design a live charging session dashboard for an EV app (VoltEZ). Dark
midnight navy background. At the top, a thin "LIVE" indicator dot
(pulsing green) with "LIVE" text in emerald 11px weight-800, and
connection status "Connected" in grey 10px.

A large circular battery progress indicator centered on screen (140px
diameter): circular track in dark surface, filled arc in cyan gradient
based on charge percentage, with "68%" in white 36px weight-900 in
the center, and "Battery" label below in grey 12px.

Below the circle, a 2×3 metrics grid in a dark card (rounded 18px):
"18.4 kWh" consumed (bolt icon, cyan), "47 kW" current power (speed
icon, amber), "24 min" remaining (clock icon, emerald), "₹142" running
cost (rupee icon, white), "CHARGING" status (ev_station icon, cyan),
session start time "Started 2:30 PM" (info icon, grey).

Below, a "Session Details" mini card: charger name, connector type,
booking reference.

At the bottom, a large "STOP CHARGING" button in red (#EF4444) with
white text, full width, rounded 14px, height 52px. The button should
have a subtle red glow. The overall feel should be futuristic and
high-tech — like a Tesla-style charging screen.
```

---

## 13 — Session Completion Summary

**Prompt:**
```
Design a charging session completion summary for an EV app (VoltEZ).
Dark midnight navy background. Top: a checkmark in emerald circle +
"Charging Complete" in emerald 22px bold.

A summary card (dark #111827, rounded 18px): four metric tiles in a
2×2 grid — "Duration: 27 min" (clock icon, cyan), "Energy: 18.4 kWh"
(bolt icon, cyan), "Cost: ₹205" (rupee icon, white), "Charger: VoltEZ
Central Mall" (ev_station icon, emerald). Each tile: icon above in
accent color, value in white 16px bold, label in grey 11px.

Below, a "Rate Your Experience" section: five star icons in a row
(amber filled, grey unfilled), with label "How was your session?" in
14px white.

Below stars, optional issue category chips: "Charger unavailable",
"Charger malfunction", "Incorrect availability", "Payment issue",
"Other" — selectable pills in dark surface with grey border, amber
highlight when selected.

An optional feedback text field (dark surface, rounded 12px,
placeholder "Any additional feedback...").

Bottom: "SUBMIT & FINISH" button in electric cyan, full width.
Below: "VIEW BOOKING HISTORY" text link in grey.
```

---

## 14 — Booking History List

**Prompt:**
```
Design a booking history screen for an EV charging app (VoltEZ). Dark
midnight navy background. Top: back arrow + "Booking History" in 22px
bold white. Below, a filter/tab row: "All" (selected, cyan underline),
"Completed" (grey), "Upcoming" (grey), "Cancelled" (grey).

Below, a vertical list of booking history items. Each item: dark card
(#111827, rounded 14px, 1px grey border, 16px padding). Inside: top
row has a cyan ev_station icon in a rounded square (44px), charger name
"VoltEZ Central Mall" in 16px bold, date and time "Aug 26 · 2:30 PM –
3:15 PM" in grey 12px. Right-aligned: status chip pill ("COMPLETED"
in green, "CONFIRMED" in cyan, "CANCELLED" in red). Bottom row:
"₹205 · CCS2 · 60 kW" in grey 12px, and for completed bookings a
"Rate" text button in amber. 12px gap between items.

Empty state: centered muted ev_station icon (48px, grey at 30%),
"No charging sessions yet" in 18px bold, "Your booking history will
appear here" in grey 14px.
```

---

## 15 — Map Screen with Station Markers

**Prompt:**
```
Design a map screen for an EV charger discovery app (VoltEZ). The map
occupies the full screen with a dark map style (Google Maps dark theme).
Overlaid on top: a bottom sheet (rounded top 24px, dark #111827
background, 80% screen height when expanded, with a drag handle).

The bottom sheet contains: a search bar at top (dark surface, rounded
12px, "Search chargers or destinations..." in grey, magnifying glass
icon). Below: horizontal scrollable filter chips — "All", "CCS2",
"Type 2", "CHAdeMO", "7kW–30kW", "30kW–60kW", "60kW–150kW". Selected
chips have cyan fill at 15%, cyan border, cyan text. Unselected: dark
surface, grey border, grey text.

Below filters, a list of charger cards (same charger card component
as the home screen). Each card shows charger name, distance, power,
price, status chip, and connector type.

Map markers: green circles for available, amber for busy, red for
offline. Selected marker has a cyan ring and shows a mini preview card
above it (charger name, distance, "View Details" button).

Top of screen: a semi-transparent dark bar with a back arrow and
"Find Chargers" title. A floating location button (rounded square,
dark, with crosshair icon) in bottom-right of map area.
```

---

## 16 — Role Selection + Login Screen

**Prompt:**
```
Design a login and role selection screen for an EV platform app
(VoltEZ). Dark midnight navy background (#0A0F1F). Center-aligned
layout. At top: VoltEZ logo/text in electric cyan 40px weight-900
with a subtle cyan glow. Below: "Welcome to VoltEZ" in white 22px
bold, "Choose your role to continue" in grey 14px.

Two large role cards stacked vertically with 16px gap:

Card 1 — "I'm a Driver": dark card (#111827), rounded 22px, 1px cyan
border at 18%. Left side: a car/steering icon in a cyan gradient
circle (60px). Right side: "I'm a Driver" in white 18px bold, "Find
chargers, plan routes, book & charge" in grey 12px. A small cyan
forward arrow on the far right.

Card 2 — "I'm a Business Owner": dark card, rounded 22px, 1px
secondary blue (#3B82F6) border at 18%. Left side: a store/building
icon in a blue gradient circle. Right side: "I'm a Business Owner" in
white 18px bold, "Manage chargers, view analytics, earn" in grey 12px.
A small blue forward arrow.

Below the role cards, a "Login" form area (appears after role
selection): dark surface input fields with rounded 12px corners —
email field with mail icon, password field with lock icon and
visibility toggle. A "Forgot Password?" link in cyan 12px below
the password field. "LOGIN" button in electric cyan, full width,
rounded 14px. Below: "Don't have an account? Sign up" text with
"Sign up" in cyan.

The overall feel should be premium, clean, and trustworthy — the
first impression of the app.
```

---

## 17 — Business Owner Dashboard

**Prompt:**
```
Design a business owner dashboard for an EV charging platform (VoltEZ).
Dark midnight navy background. At top: "BUSINESS / OWNER" label in
cyan 10px uppercase with letter-spacing, greeting "Good evening,
Priya" in white 26px bold, notification bell icon in cyan rounded
square.

A stats overview card (dark #111827, rounded 22px, gradient from blue
at 10% to dark): four metrics in a 2×2 grid — "12 Active Chargers"
(bolt icon, cyan), "847 kWh Today" (energy icon, emerald), "₹11,858
Revenue" (rupee icon, amber), "4.6 Avg Rating" (star icon, yellow).
Each: icon + large value in white 24px bold + label in grey 11px
uppercase.

Below: "Charger Fleet" section with "See all" link. A horizontal
scrollable row of charger cards (compact version): each showing
charger name, port count, status (available/maintenance), and
today's sessions count.

"Recent Activity" section: a vertical list of 3-4 activity items
with timestamp, icon, description — "Phoenix Mall Charger booked
by Driver #2847", "Tech Park Station maintenance completed",
etc. Each item: small icon, text in 14px, timestamp in grey 11px.

Bottom nav: Home (selected, cyan), Chargers, Analytics, Profile.
Overall feel: data-rich but not cluttered, executive dashboard vibe.
```

---

## 18 — Empty / Error / Offline States Collection

**Prompt:**
```
Design a set of empty, error, and offline states for an EV charging app
(VoltEZ), all on dark midnight navy backgrounds (#0A0F1F).

State 1 — Empty (No Results): centered search_off icon (64px, grey at
30% opacity), "No chargers found" in white 18px bold, "No compatible
chargers were found along your route. Try adjusting your destination."
in grey 14px centered, "EDIT ROUTE" button in cyan with edit icon.

State 2 — Error: centered error icon (72px) in a red circle (red at
10% fill), "Something went wrong" in white 18px bold, error message
in grey 14px centered, "RETRY" button in cyan with refresh icon.

State 3 — Network Offline: centered wifi_off icon (64px, grey at 30%),
"You're offline" in white 18px bold, "Check your internet connection
and try again" in grey 14px, "RETRY" button in cyan.

State 4 — No Bookings Yet: centered history icon (48px, grey at 30%),
"No bookings yet" in 18px bold, "Your booking history will appear
here" in grey 14px.

State 5 — Stale Data Warning: amber banner (amber at 8% fill, amber
border at 25%), info icon in amber, "Some results have low confidence.
Data may be outdated — availability and pricing are based on last-known
status." in grey 12px.

State 6 — Session Expired: red banner (red at 10% fill), timer icon
in red, "Slot Expired" in red 14px bold, "This slot is no longer
held for you. Choose another slot." in grey 12px, "CHOOSE ANOTHER"
button in red.

Each state should feel helpful and guide the user to the next action.
```

---

## 19 — Status Chips & Badges System

**Prompt:**
```
Design a comprehensive set of status chips and badges for an EV charging
app (VoltEZ) on a dark midnight navy background (#0A0F1F).

Charger Status Chips:
- "AVAILABLE" — emerald green (#34D399) text on green at 15% fill,
  rounded 30px, 11px bold uppercase, letter-spacing 0.8
- "IN USE" — amber (#F59E0B) text on amber at 15% fill, same style
- "OFFLINE" — grey (#64748B) text on grey at 15% fill
- "MAINTENANCE" — red (#EF4444) text on red at 15% fill

Booking Status Chips:
- "PENDING" — amber on amber 15%
- "HELD" — cyan on cyan 15%
- "PAYMENT PENDING" — amber on amber 15%
- "CONFIRMED" — green on green 15%
- "CANCELLED" — red on red 15%
- "EXPIRED" — red on red 15%
- "FAILED" — red on red 15%
- "NO SHOW" — red on red 15%
- "CHECKED IN" — cyan on cyan 15%
- "CHARGING" — cyan on cyan 15%
- "COMPLETED" — green on green 15%

Recommendation Rank Badges:
- "#1 Best Overall" — cyan rank number, cyan tag pill
- "#2 Fastest" — blue rank number, blue tag pill
- "#3 Cheapest" — green rank number, green tag pill

Power/Connector Badges:
- "CCS2 • 60 kW" — outlined pill, cyan text, 1px cyan border at 30%
- "Type 2 • 22 kW" — same style

Confidence Badges:
- "94% match" — cyan fill at 10%, cyan text, small pill
- Low confidence (below 70%) — amber fill, amber text

Show all chips arranged in a grid/catalog layout for easy reference.
```

---

## 20 — Bottom Navigation Bar

**Prompt:**
```
Design a bottom navigation bar for an EV charging driver app (VoltEZ).
Dark surface background (#111827) with a subtle top border (1px,
#1E293B). Five items in a row:

1. "Home" — house icon, selected state: icon + label in electric cyan
   (#00E5FF), with a small cyan dot indicator above the icon
2. "Map" — map icon, unselected: grey (#64748B) icon and label
3. "Route" — route/planner icon, unselected: grey
4. "History" — clock/history icon, unselected: grey
5. "Profile" — person icon, unselected: grey

Selected item: cyan icon (22px), cyan label (10px weight-600), small
cyan dot (4px circle) centered above the icon. Unselected: grey icon
(22px), grey label (10px weight-500). The bar should have safe area
padding at the bottom for iPhone notch. Overall height ~64px + safe
area. The bar should feel minimal and not compete with page content.
```

---

## 21 — Section Headers & Dividers

**Prompt:**
```
Design the section header pattern for an EV charging app (VoltEZ) on
dark midnight navy background. The section header has: a small cyan
number ("01") in 11px weight-800, followed by a thin horizontal line
(1px, #1E293B grey), followed by the section title ("NEARBY CHARGERS")
in 10px uppercase weight-800 letter-spacing 1.4 in dimmer grey
(#64748B). On the right side, an action link ("See all") in 11px
cyan weight-800.

Show three variants:
1. "01 — NEARBY CHARGERS / See all" (default)
2. "02 — QUICK ACTIONS / See all" 
3. "03 — RECENT BOOKINGS / See all"

Also show a simple divider: full-width 1px line in #1E293B with
16px vertical margin.

And a card divider: 1px line in #1E293B inside a card, with
8px vertical margin.
```

---

## 22 — Input Fields & Forms

**Prompt:**
```
Design input field components for a dark-mode EV charging app (VoltEZ)
on midnight navy background (#0A0F1F).

Standard Input:
- Dark surface fill (#1A2332), rounded 12px, no border
- Left icon in grey 22px (e.g., search, location, mail)
- Placeholder text in grey (#64748B) 14px weight-500
- When focused: 1px cyan (#00E5FF) border, slightly brighter fill
- Height ~48px, horizontal padding 16px

Password Input:
- Same as standard, with lock icon left, visibility eye icon right
- Toggle visibility on tap

Dropdown/Selector:
- Same base style, with chevron-down icon right
- When opened: dropdown panel below with options, dark surface,
  cyan highlight on selected option

Slider (SOC):
- Custom dark track (#1A2332), filled portion in cyan gradient
- Thumb: 24px circle, cyan fill, white center dot
- Value label above thumb: large text (e.g., "62%") in cyan 28px bold
- Min/max labels in grey 10px

Multi-select Chips:
- Row of selectable chips: "CCS2", "Type 2", "CHAdeMO"
- Unselected: dark surface fill, grey border, grey text
- Selected: cyan fill at 15%, cyan border, cyan text

Show all variants arranged vertically with labels.
```

---

## 23 — Error Banner & Toast

**Prompt:**
```
Design error banner and toast notification components for an EV charging
app (VoltEZ) on dark midnight navy background (#0A0F1F).

Error Banner (inline):
- Full width, rounded 12px, 16px horizontal / 12px vertical padding
- Background: red (#EF4444) at 10% opacity
- Border: 1px red at 30% opacity
- Left: error_outline icon in red, 20px
- Center: error message text in white 12px weight-500
- Right: "RETRY" text link in cyan 12px weight-800
- Used inline in screens when API calls fail

Success Toast (snackbar):
- Bottom-positioned, rounded 12px, 16px padding
- Background: dark surface (#1A2332) with 1px emerald border at 20%
- Left: checkmark_circle icon in emerald (#34D399)
- Center: success message in white 14px
- Auto-dismiss after 3 seconds

Warning Toast:
- Same shape, amber (#F59E0B) icon and border at 20%
- Warning message text

Info Toast:
- Same shape, cyan (#00E5FF) icon and border at 20%
- Info message text

Show all four variants stacked vertically with sample content.
```

---

## 24 — Onboarding / Vehicle Setup

**Prompt:**
```
Design an onboarding vehicle setup screen for an EV charging app (VoltEZ)
on dark midnight navy background. A step indicator at top: "Step 2 of 3"
in grey 12px, with a thin progress bar (2/3 filled in cyan, rest grey).

Title: "Add Your Vehicle" in white 26px bold, subtitle "So we can find
compatible chargers" in grey 14px.

A vehicle form: dark surface inputs — "Vehicle Make" dropdown (e.g.,
"Tata", "MG", "Hyundai"), "Vehicle Model" dropdown (depends on make),
"Year" dropdown (2020–2026), "Battery Capacity (kWh)" number input
with a small info tooltip icon, "Connector Type" multi-select chips
("CCS2", "Type 2", "CHAdeMO") — show which connectors the vehicle
supports.

Below: a preview card showing the selected vehicle info — "Tata Nexon
EV Prime" in white 16px bold, "30.2 kWh · CCS2 · 2024" in grey 12px,
with a small car silhouette illustration in cyan.

"CONTINUE" button in electric cyan, full width. "Skip for now" text
link below in grey.
```

---

## 25 — Profile Screen

**Prompt:**
```
Design a driver profile screen for an EV charging app (VoltEZ) on dark
midnight navy background. Centered avatar at top: 80px circle with
cyan-to-blue gradient fill, white person icon 44px inside. Below:
user name "Swarali" in white 26px bold, "Driver" in grey 14px.

A vertical list of profile options, each in a dark card (#111827,
rounded 14px, 1px grey border, 16px padding):
- Row: rounded square icon container (40px, cyan at 10% fill, rounded
  12px) + icon in cyan + title "My Vehicle" in 16px bold + subtitle
  "Tata Nexon EV, 2024" in grey 12px + forward arrow in grey
- Row: "Booking History" + "View all bookings and sessions"
- Row: "Payment Methods" + "Manage UPI, cards, wallet"
- Row: "Notifications" + "Manage alerts"
- Row: "Help & Support" + "FAQs, contact us"
- Row: "About VoltEZ" + "Version 1.0.0"

8px gap between cards. Last item: "Logout" with red icon, "Sign out
of your account" in grey. The logout card has a subtle red border
at 15%.

Scrollable layout with 20px page margins.
```

---

## 26 — Check-in Screen

**Prompt:**
```
Design a charger check-in screen for an EV app (VoltEZ) on dark
midnight navy background. The screen appears when a driver arrives at
the charger location.

At top: back arrow + "Check In" in 22px bold white.

A large arrival card (dark #111827, rounded 22px, emerald border at
20%): centered layout — ev_station icon in a large emerald circle
(80px, emerald at 15% fill), "You've arrived!" in white 22px bold,
charger name "VoltEZ Central Mall" in 16px, address in grey 12px.

Below: booking summary card (dark #111827, rounded 18px): rows for
"Booking" → "#BK-2847", "Time" → "2:30 PM – 3:15 PM", "Connector"
→ "CCS2 • 60 kW", "Status" → "CONFIRMED" chip in green.

Below: a prominent "CHECK IN" button in emerald green (#34D399) full
width, rounded 14px, height 56px, with a QR code scan icon. The button
should glow subtly. Below it: "Scan QR code at the charger station"
in grey 11px centered.

At the bottom: "Having trouble?" text link in amber 12px.

When check-in is successful: green checkmark animation + "Checked In"
text. When too early: amber warning "Your slot starts at 2:30 PM".
When too late: red error "This booking has expired".
```

---

## 27 — Map Marker Bottom Sheet

**Prompt:**
```
Design a bottom sheet that appears when a map marker is tapped in an
EV charger discovery app (VoltEZ). The sheet slides up from the bottom
on a dark map background.

The sheet: dark background (#111827), rounded top corners 24px, drag
handle (40px × 4px grey rounded bar centered at top). 20px padding.

Top section: charger name "VoltEZ Central Mall" in white 18px bold,
address "Phoenix Mall, Andheri West, Mumbai" in grey 12px, distance
"2.3 km away" in cyan 12px.

Metrics row: four items in a row — "60 kW" with bolt icon in cyan,
"₹14/kWh" with rupee icon in white, "4.6 ★" with star icon in amber,
"CCS2" connector badge in outlined cyan pill.

Status: "Available" badge in emerald green pill with a pulsing green
dot.

"Wait time: ~0 min" in emerald 12px below.

Two buttons at bottom: "VIEW DETAILS" outlined button (dark surface,
grey border) and "NAVIGATE" filled button (electric cyan, dark text).
Both full width, stacked, 48px height, rounded 12px.

The sheet should feel like a quick preview — enough info to decide
without leaving the map.
```

---

## 28 — Notification Panel

**Prompt:**
```
Design a notification panel for an EV charging app (VoltEZ) on dark
midnight navy background. Back arrow + "Notifications" in 22px bold.

A filter row: "All" (selected, cyan), "Bookings" (grey), "Charging"
(grey), "Promotions" (grey).

A vertical list of notification cards (dark #111827, rounded 14px,
16px padding, 1px grey border):

Notification 1 (unread — cyan left border accent): charging
reminder icon (bolt in cyan circle), "Your slot starts in 30 min"
in white 14px bold, "Phoenix Mall Charger · 2:30 PM" in grey 12px,
"10 min ago" in grey 10px.

Notification 2 (read — no accent): booking confirmed icon (checkmark
in green circle), "Booking #BK-2847 confirmed" in white 14px, "₹205
estimated cost" in grey 12px, "1 hour ago" in grey 10px.

Notification 3 (read): payment icon (rupee in amber circle),
"Payment of ₹205 received" in white 14px, "Via Google Pay" in
grey 12px, "3 hours ago".

Notification 4 (read): maintenance icon (wrench in red circle),
"Phoenix Mall Charger under maintenance" in white 14px, "Estimated
restoration: 2 hours" in grey 12px, "Yesterday".

8px gap between cards. Unread cards have a slightly brighter
background (#1A2332 vs #111827).
```

---

## 29 — Skeleton / Loading Patterns Collection

**Prompt:**
```
Design a set of skeleton loading patterns for an EV charging app
(VoltEZ) on dark midnight navy background (#0A0F1F). All skeleton
elements use surface color (#1A2332) with rounded corners.

Pattern 1 — Card Skeleton: A charger card skeleton — rounded 18px,
18px padding. Top row: 54px circle avatar shimmer + 140px × 14px
name shimmer + 120px × 10px address shimmer. Below: three 80px × 36px
metric shimmers in a row. Below: 200px × 30px amenities bar shimmer.

Pattern 2 — List Skeleton: Five list item skeletons stacked — each
is a row: 44px rounded square shimmer + 180px × 14px + 120px × 10px
+ 60px × 20px status chip shimmer. 12px gap.

Pattern 3 — Grid Skeleton: Six slot card skeletons in 2-column grid.
Each: full-width × 80px rounded 14px shimmer.

Pattern 4 — Profile Skeleton: 80px circle shimmer (avatar) + 120px ×
20px (name) + 60px × 12px (role) centered. Below: three 100% width
× 56px rounded 14px item skeletons.

Pattern 5 — Detail Skeleton: Full width × 200px hero shimmer (rounded
18px), then two 48% width × 100px metric cards side by side, then
three 100% width × 44px row shimmers.

Show all five patterns arranged in a catalog layout with labels.
No animation needed — static shimmer blocks.
```

---

## 30 — Card Shadow & Glow System

**Prompt:**
```
Design a card elevation and glow system for a dark-mode EV app (VoltEZ)
on midnight navy background (#0A0F1F).

Show the same card (charger card) in multiple states:

1. Default: dark card (#111827), 1px grey border (#1E293B), no shadow.
   Clean and flat.

2. Subtle Glow: same card with a very faint cyan glow shadow
   (color: #00E5FF at 6%, blur: 16px, spread: 1px). Used for
   charger cards on the home screen.

3. Featured/Selected: card with stronger cyan glow (color: #00E5FF
   at 10%, blur: 20px, spread: 1px) and 1px cyan border at 30%.
   Used for the #1 recommendation.

4. Pressed/Active: card with slightly elevated surface (#1E293B)
   background and cyan border at 40%. Brief touch feedback.

5. Error State: card with red glow shadow (color: #EF4444 at 8%,
   blur: 16px) and 1px red border at 20%. Used for error alerts.

6. Success State: card with emerald glow (color: #34D399 at 8%,
   blur: 16px) and 1px emerald border at 20%. Used for confirmation.

Show all six cards arranged in a 2×3 grid on the dark background.
Each card labeled with its state name below it in grey 10px uppercase.
```

---

## Usage Notes

1. **Copy-paste these prompts directly** into Google Stitch.
2. Each prompt is self-contained — Stitch doesn't need the codebase context.
3. The color hex values are included so Stitch matches the exact VoltEZ palette.
4. The prompts specify pixel sizes, font weights, and opacity values for precision.
5. Use the generated designs as a reference to refine your Flutter implementations.
6. For best results, generate one screen at a time and iterate.
7. After generating, compare against the existing `AppColors` and `AppTypography` constants to ensure consistency.
