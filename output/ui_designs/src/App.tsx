import { useState } from "react";

// ─── Design tokens (Stitch "Vibrant Professionalism") ─────────────────────────
const C = {
  surface: "#F8F9FA",
  surfaceDim: "#D9DADB",
  card: "#FFFFFF",
  containerLow: "#F3F4F5",
  container: "#EDEEEF",
  onSurface: "#191C1D",
  onSurfaceVariant: "#404943",
  outline: "#707973",
  outlineVariant: "#BFC9C1",
  primary: "#2D6A4F", // Leaf Green
  primaryDim: "#40916C",
  primaryContainer: "#A8E7C5",
  ocean: "#1D3557", // Ocean Blue
  oceanSoft: "#28477A",
  marigold: "#FFB703",
  coral: "#E76F51",
};

const HEAD = "'Outfit', sans-serif";

// ─── Icons (inline SVGs) ──────────────────────────────────────────────────────

function BellIcon() {
  return (
    <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M18 8A6 6 0 0 0 6 8c0 7-3 9-3 9h18s-3-2-3-9" />
      <path d="M13.73 21a2 2 0 0 1-3.46 0" />
    </svg>
  );
}

function BoltIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
    </svg>
  );
}

function RouteIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="6" cy="19" r="3" /><path d="M9 19h8.5a3.5 3.5 0 0 0 0-7h-11a3.5 3.5 0 0 1 0-7H15" /><circle cx="18" cy="5" r="3" />
    </svg>
  );
}

function PlugIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 22v-5" /><path d="M9 8V2" /><path d="M15 8V2" /><rect x="6" y="8" width="12" height="9" rx="2" />
    </svg>
  );
}

function SearchIcon() {
  return (
    <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
    </svg>
  );
}

function MapPinIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 10c0 6-8 12-8 12s-8-6-8-12a8 8 0 0 1 16 0Z" /><circle cx="12" cy="10" r="3" />
    </svg>
  );
}

function StarIcon({ size = 14 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="currentColor">
      <polygon points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2" />
    </svg>
  );
}

function RupeeIcon({ size = 14 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="M6 3h12" /><path d="M6 8h12" /><path d="m6 13 8.5 8" /><path d="M6 13h3" /><path d="M9 13c6.667 0 6.667-10 0-10" />
    </svg>
  );
}

function ChevronRightIcon() {
  return (
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <path d="m9 18 6-6-6-6" />
    </svg>
  );
}

function HomeIcon({ active }: { active?: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill={active ? C.primary : "none"} stroke={active ? C.primary : C.outline} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="m3 9 9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z" /><polyline points="9 22 9 12 15 12 15 22" />
    </svg>
  );
}

function MapIcon({ active }: { active?: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? C.primary : C.outline} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <polygon points="3 6 9 3 15 6 21 3 21 18 15 21 9 18 3 21" /><line x1="9" y1="3" x2="9" y2="18" /><line x1="15" y1="6" x2="15" y2="21" />
    </svg>
  );
}

function CalendarIcon({ active, color }: { active?: boolean; color?: string }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={color ?? (active ? C.primary : C.outline)} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <rect x="3" y="4" width="18" height="18" rx="2" ry="2" /><line x1="16" y1="2" x2="16" y2="6" /><line x1="8" y1="2" x2="8" y2="6" /><line x1="3" y1="10" x2="21" y2="10" />
    </svg>
  );
}

function UserIcon({ active }: { active?: boolean }) {
  return (
    <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke={active ? C.primary : C.outline} strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2" /><circle cx="12" cy="7" r="4" />
    </svg>
  );
}

function ArrowRightIcon({ size = 16 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
      <line x1="5" y1="12" x2="19" y2="12" /><polyline points="12 5 19 12 12 19" />
    </svg>
  );
}

// ─── Battery Card — Ocean Blue heavy header surface ───────────────────────────

function BatteryCard() {
  const pct = 72;
  return (
    <div
      className="rounded-2xl p-5"
      style={{
        background: `linear-gradient(150deg, ${C.oceanSoft} 0%, ${C.ocean} 100%)`,
        boxShadow: "0 14px 34px rgba(29,53,87,0.28)",
      }}
    >
      <div className="flex items-start justify-between mb-3">
        <span
          className="text-[12px] font-semibold"
          style={{ color: C.marigold, letterSpacing: "0.05em" }}
        >
          BATTERY STATUS
        </span>
        <span className="text-[40px] leading-none" style={{ color: "#FFFFFF", fontFamily: HEAD, fontWeight: 700 }}>
          {pct}%
        </span>
      </div>

      {/* Progress bar */}
      <div className="w-full h-[7px] rounded-full mb-4" style={{ background: "rgba(255,255,255,0.14)" }}>
        <div
          className="h-full rounded-full"
          style={{ width: `${pct}%`, background: `linear-gradient(90deg, ${C.primaryDim}, ${C.primaryContainer})` }}
        />
      </div>

      {/* Metrics row */}
      <div className="grid grid-cols-3 gap-2">
        {[
          { icon: <BoltIcon size={14} />, value: "38.9 kWh", label: "Capacity", color: C.primaryContainer },
          { icon: <RouteIcon size={14} />, value: "245 km", label: "Range", color: C.marigold },
          { icon: <PlugIcon size={14} />, value: "CCS2", label: "Connector", color: "#B0C7F1" },
        ].map(({ icon, value, label, color }) => (
          <div key={label} className="flex flex-col items-center gap-1">
            <span style={{ color }}>{icon}</span>
            <span className="text-[13px] font-semibold" style={{ color: "#F0F1F2" }}>{value}</span>
            <span className="text-[12px]" style={{ color: "rgba(240,241,242,0.6)" }}>{label}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Active Session Banner ────────────────────────────────────────────────────

function ActiveSessionBanner() {
  return (
    <div
      className="rounded-2xl p-4 flex items-center gap-3"
      style={{
        background: C.card,
        boxShadow: "0 8px 24px rgba(29,53,87,0.10)",
        border: `1px solid ${C.outlineVariant}`,
      }}
    >
      {/* Pulsing bolt */}
      <div className="relative flex-shrink-0">
        <div className="w-11 h-11 rounded-full animate-pulse" style={{ background: "rgba(45,106,79,0.18)" }} />
        <div
          className="w-11 h-11 rounded-full flex items-center justify-center absolute inset-0 text-white"
          style={{ background: C.primary }}
        >
          <BoltIcon size={18} />
        </div>
      </div>

      <div className="flex-1 min-w-0">
        <div className="text-[12px] font-bold" style={{ color: C.primary, letterSpacing: "0.05em" }}>
          CHARGING NOW
        </div>
        <div className="text-[16px] font-semibold truncate" style={{ color: C.onSurface, fontFamily: HEAD }}>
          Phoenix Mall Charger
        </div>
      </div>

      <div className="flex items-center gap-2 flex-shrink-0">
        <span className="text-[22px]" style={{ color: C.ocean, fontFamily: HEAD, fontWeight: 700 }}>68%</span>
        <span style={{ color: C.primary }}><ArrowRightIcon size={16} /></span>
      </div>
    </div>
  );
}

// ─── Search Bar ───────────────────────────────────────────────────────────────

function SearchBar() {
  return (
    <div
      className="flex items-center gap-3 px-4 py-3.5 rounded-xl"
      style={{ background: C.containerLow, border: `1px solid ${C.outlineVariant}` }}
    >
      <span style={{ color: C.ocean }}><SearchIcon /></span>
      <span className="text-[16px]" style={{ color: C.outline }}>
        Search destination or charger...
      </span>
    </div>
  );
}

// ─── Quick Actions ────────────────────────────────────────────────────────────

const quickActions = [
  { label: "Route\nPlanner", bg: "rgba(45,106,79,0.12)", icon: <RouteIcon size={20} />, color: C.primary },
  { label: "Find\nCharger", bg: "rgba(29,53,87,0.12)", icon: <MapPinIcon size={20} />, color: C.ocean },
  { label: "Active\nSession", bg: "rgba(255,183,3,0.16)", icon: <BoltIcon size={20} />, color: "#8A6300" },
  { label: "Booking\nHistory", bg: "rgba(231,111,81,0.14)", icon: <CalendarIcon color={C.coral} />, color: C.coral },
];

function QuickActions() {
  return (
    <div className="grid grid-cols-4 gap-2.5">
      {quickActions.map(({ label, bg, icon, color }) => (
        <button
          key={label}
          className="flex flex-col items-center gap-2 py-3.5 rounded-xl transition-transform active:scale-95"
          style={{ background: C.card, border: `1px solid ${C.outlineVariant}` }}
        >
          <div
            className="w-12 h-12 rounded-xl flex items-center justify-center"
            style={{ background: bg, color }}
          >
            {icon}
          </div>
          <span
            className="text-[12px] font-semibold text-center leading-tight whitespace-pre-line"
            style={{ color: C.onSurfaceVariant }}
          >
            {label}
          </span>
        </button>
      ))}
    </div>
  );
}

// ─── Charger Card ─────────────────────────────────────────────────────────────

interface ChargerCardProps {
  name: string;
  address: string;
  distance: string;
  status: "AVAILABLE" | "IN USE" | "OFFLINE";
  power: string;
  price: string;
  rating: string;
  amenities: string[];
}

const statusStyles: Record<string, { bg: string; text: string }> = {
  AVAILABLE: { bg: "rgba(45,106,79,0.14)", text: C.primary },
  "IN USE": { bg: "rgba(255,183,3,0.18)", text: "#8A6300" },
  OFFLINE: { bg: "rgba(231,111,81,0.14)", text: "#B23A22" },
};

function ChargerCard({ name, address, distance, status, power, price, rating, amenities }: ChargerCardProps) {
  const st = statusStyles[status];
  return (
    <div
      className="rounded-2xl p-4"
      style={{ background: C.card, boxShadow: "0 8px 24px rgba(29,53,87,0.08)", border: `1px solid ${C.outlineVariant}` }}
    >
      {/* Top row */}
      <div className="flex items-start gap-3 mb-3">
        <div
          className="w-[54px] h-[54px] rounded-full flex items-center justify-center flex-shrink-0"
          style={{ background: "rgba(29,53,87,0.10)" }}
        >
          <span style={{ color: C.ocean }}><PlugIcon size={26} /></span>
        </div>
        <div className="flex-1 min-w-0">
          <div className="text-[16px] font-semibold truncate" style={{ color: C.onSurface, fontFamily: HEAD }}>{name}</div>
          <div className="text-[14px] mt-0.5" style={{ color: C.onSurfaceVariant }}>{address} · {distance}</div>
        </div>
        <span
          className="text-[12px] font-bold px-3 py-1 rounded-full flex-shrink-0"
          style={{ background: st.bg, color: st.text, letterSpacing: "0.05em" }}
        >
          {status}
        </span>
      </div>

      {/* Metrics */}
      <div className="flex items-center justify-around py-3 rounded-xl mb-3" style={{ background: C.containerLow }}>
        <div className="flex items-center gap-1.5">
          <span style={{ color: C.primary }}><BoltIcon size={13} /></span>
          <span className="text-[14px] font-semibold" style={{ color: C.onSurface }}>{power}</span>
          <span className="text-[12px]" style={{ color: C.outline }}>kW</span>
        </div>
        <div className="w-px h-4" style={{ background: C.outlineVariant }} />
        <div className="flex items-center gap-1.5">
          <span style={{ color: C.ocean }}><RupeeIcon size={13} /></span>
          <span className="text-[14px] font-semibold" style={{ color: C.onSurface }}>{price}</span>
          <span className="text-[12px]" style={{ color: C.outline }}>/kWh</span>
        </div>
        <div className="w-px h-4" style={{ background: C.outlineVariant }} />
        <div className="flex items-center gap-1.5">
          <span style={{ color: C.marigold }}><StarIcon size={13} /></span>
          <span className="text-[14px] font-semibold" style={{ color: C.onSurface }}>{rating}</span>
          <span className="text-[12px]" style={{ color: C.outline }}>Rating</span>
        </div>
      </div>

      {/* Amenities */}
      <div className="flex flex-wrap gap-1.5">
        {amenities.map((a) => (
          <span
            key={a}
            className="text-[12px] font-medium px-3 py-1 rounded-full"
            style={{ background: C.container, color: C.onSurfaceVariant }}
          >
            {a}
          </span>
        ))}
      </div>
    </div>
  );
}

// ─── Main App ─────────────────────────────────────────────────────────────────

const chargers: ChargerCardProps[] = [
  {
    name: "Phoenix Mall Charger",
    address: "Phoenix Mall",
    distance: "2.3 km",
    status: "AVAILABLE",
    power: "60",
    price: "₹14",
    rating: "4.6",
    amenities: ["WiFi", "Food Court", "Parking"],
  },
  {
    name: "VoltEZ Central Station",
    address: "FC Road, Pune",
    distance: "4.1 km",
    status: "IN USE",
    power: "150",
    price: "₹18",
    rating: "4.8",
    amenities: ["Parking", "Restroom", "24/7"],
  },
  {
    name: "EcoCharge Hub",
    address: "Baner, Pune",
    distance: "6.7 km",
    status: "AVAILABLE",
    power: "22",
    price: "₹12",
    rating: "4.3",
    amenities: ["WiFi", "Parking"],
  },
];

const tabs = [
  { label: "Home", icon: HomeIcon },
  { label: "Map", icon: MapIcon },
  { label: "Bookings", icon: CalendarIcon },
  { label: "Profile", icon: UserIcon },
];

export default function App() {
  const [activeTab, setActiveTab] = useState(0);

  return (
    <div
      className="min-h-full w-full flex items-center justify-center overflow-auto py-6"
      style={{ background: C.surfaceDim }}
    >
      {/* Phone shell */}
      <div
        className="relative flex flex-col overflow-hidden flex-shrink-0"
        style={{
          width: "390px",
          height: "844px",
          maxHeight: "calc(100vh - 48px)",
          background: C.surface,
          borderRadius: "44px",
          boxShadow: "0 32px 80px rgba(29,53,87,0.22), 0 0 0 1px rgba(0,0,0,0.06)",
          fontFamily: "'Inter', sans-serif",
        }}
      >
        {/* Status bar */}
        <div className="flex justify-between items-center px-8 pt-4 pb-2 flex-shrink-0">
          <span className="text-[13px] font-semibold" style={{ color: C.onSurface }}>9:41</span>
          <div className="flex items-center gap-1.5">
            {[3, 4, 5].map((h) => (
              <div key={h} className="w-1 rounded-sm" style={{ height: h, background: C.onSurface }} />
            ))}
            <div className="w-4 h-2.5 rounded-sm border flex items-center" style={{ borderColor: C.onSurface }}>
              <div className="h-full rounded-sm ml-0.5" style={{ width: "70%", background: C.onSurface }} />
            </div>
          </div>
        </div>

        {/* Scrollable content */}
        <div className="flex-1 overflow-y-auto px-5 pb-4" style={{ scrollbarWidth: "none" }}>

          {/* Header */}
          <div className="flex items-center justify-between mb-5">
            <div>
              <p className="text-[14px] font-medium" style={{ color: C.onSurfaceVariant }}>Good evening</p>
              <h1 className="text-[24px] leading-tight" style={{ color: C.onSurface, fontFamily: HEAD, fontWeight: 700, letterSpacing: "-0.02em" }}>Swarali 👋</h1>
            </div>
            <button
              className="w-10 h-10 rounded-full flex items-center justify-center"
              style={{ background: C.primary, color: "#FFFFFF" }}
            >
              <BellIcon />
            </button>
          </div>

          {/* Battery card */}
          <div className="mb-4">
            <BatteryCard />
          </div>

          {/* Active session */}
          <div className="mb-4">
            <ActiveSessionBanner />
          </div>

          {/* Search */}
          <div className="mb-5">
            <SearchBar />
          </div>

          {/* Quick actions */}
          <div className="mb-6">
            <QuickActions />
          </div>

          {/* Nearby chargers section */}
          <div className="mb-3">
            <div className="flex items-center justify-between">
              <span className="text-[12px] font-bold" style={{ color: C.onSurfaceVariant, letterSpacing: "0.05em" }}>
                NEARBY CHARGERS
              </span>
              <button className="text-[14px] font-semibold flex items-center gap-1" style={{ color: C.primary }}>
                See all <ChevronRightIcon />
              </button>
            </div>
            <div className="h-px mt-2" style={{ background: C.outlineVariant }} />
          </div>

          <div className="flex flex-col gap-3">
            {chargers.map((c) => (
              <ChargerCard key={c.name} {...c} />
            ))}
          </div>
        </div>

        {/* Bottom nav — Ocean Blue grounded surface */}
        <div
          className="flex-shrink-0 flex items-center px-2 pt-3 pb-6"
          style={{ background: C.card, boxShadow: "0 -1px 0 rgba(0,0,0,0.06)" }}
        >
          {tabs.map(({ label, icon: Icon }, i) => (
            <button
              key={label}
              className="flex-1 flex flex-col items-center gap-1"
              onClick={() => setActiveTab(i)}
            >
              <Icon active={activeTab === i} />
              <span
                className="text-[12px] font-semibold"
                style={{ color: activeTab === i ? C.primary : C.outline }}
              >
                {label}
              </span>
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
