#!/usr/bin/env python3
"""Generate a simplified VoltEZ architecture diagram as JPG."""

from PIL import Image, ImageDraw, ImageFont
import math, textwrap

W, H = 1600, 1000
img = Image.new("RGB", (W, H), "#F5F0E8")
draw = ImageDraw.Draw(img)

# Colors
GREEN_DARK  = "#2D5A27"
GREEN_MED   = "#3A7D32"
GREEN_LIGHT = "#5AA64D"
GREEN_PALE  = "#A8D5A0"
WHITE       = "#FFFFFF"
CREAM       = "#F5F0E8"
GREY        = "#666666"
BLUE_LIGHT  = "#D6EAF8"
ORANGE_LIGHT= "#FDEBD0"
CYAN_LIGHT  = "#D1F2EB"
BLUE_BORDER = "#5DADE2"
ORANGE_BORDER="#E67E22"
CYAN_BORDER = "#1ABC9C"

def try_font(size):
    for path in [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
        "/System/Library/Fonts/SFNSMono.ttf",
        "C:/Windows/Fonts/arial.ttf",
        "/usr/share/fonts/TTF/DejaVuSans.ttf",
    ]:
        try: return ImageFont.truetype(path, size)
        except: pass
    return ImageFont.load_default()

font_lg  = try_font(20)
font_md  = try_font(16)
font_sm  = try_font(13)
font_xs  = try_font(11)
font_title = try_font(26)

def box(x, y, w, h, fill, border_color, border_w=2, radius=12):
    draw.rounded_rectangle([x, y, x+w, y+h], radius=radius, fill=fill, outline=border_color, width=border_w)

def label(text, x, y, font=font_md, fill="#000000", anchor="mt"):
    draw.text((x, y), text, fill=fill, font=font, anchor=anchor)

def center_text(text, x, y, font=font_md, fill="#000000"):
    draw.text((x, y), text, fill=fill, font=font, anchor="mt")

def arrow(x1, y1, x2, y2, color=GREY, w=2, head=8):
    draw.line([(x1, y1), (x2, y2)], fill=color, width=w)
    angle = math.atan2(y2 - y1, x2 - x1)
    lx = x2 - head * math.cos(angle - 0.35)
    ly = y2 - head * math.sin(angle - 0.35)
    rx = x2 - head * math.cos(angle + 0.35)
    ry = y2 - head * math.sin(angle + 0.35)
    draw.polygon([(x2, y2), (lx, ly), (rx, ry)], fill=color)

def dash_arrow(x1, y1, x2, y2, color=GREY, w=2, dash=8, gap=5, head=8):
    dx, dy = x2 - x1, y2 - y1
    length = math.hypot(dx, dy)
    if length == 0: return
    ux, uy = dx/length, dy/length
    d = 0
    while d < length - dash:
        sx = x1 + ux * d
        sy = y1 + uy * d
        ed = min(d + dash, length)
        ex = x1 + ux * ed
        ey = y1 + uy * ed
        draw.line([(sx, sy), (ex, ey)], fill=color, width=w)
        d += dash + gap
    angle = math.atan2(dy, dx)
    lx = x2 - head * math.cos(angle - 0.35)
    ly = y2 - head * math.sin(angle - 0.35)
    rx = x2 - head * math.cos(angle + 0.35)
    ry = y2 - head * math.sin(angle + 0.35)
    draw.polygon([(x2, y2), (lx, ly), (rx, ry)], fill=color)

def bullet_list(x, y, items, font=font_sm, fill="#333333"):
    for i, item in enumerate(items):
        draw.text((x, y + i * 22), f"• {item}", fill=fill, font=font)

# ─── TITLE ───────────────────────────────────────────────────────────
center_text("VoltEZ — Simplified System Architecture", W//2, 20, font=font_title, fill=GREEN_DARK)
draw.line([(100, 55), (W-100, 55)], fill=GREEN_DARK, width=3)

# ─── CLIENT LAYER ────────────────────────────────────────────────────
CL_X, CL_Y, CL_W, CL_H = 900, 70, 660, 260
box(CL_X, CL_Y, CL_W, CL_H, BLUE_LIGHT, BLUE_BORDER, border_w=2)
center_text("CLIENT LAYER", CL_X + CL_W//2, CL_Y + 10, font=font_lg, fill=BLUE_BORDER)

# Driver App
box(CL_X+20, CL_Y+40, 290, 200, WHITE, BLUE_BORDER)
center_text("EV Driver App", CL_X+165, CL_Y+52, font=font_md, fill=GREEN_DARK)
center_text("Flutter / Dart  •  Mobile + Web", CL_X+165, CL_Y+75, font=font_xs, fill=GREY)
bullet_list(CL_X+40, CL_Y+95, ["Charger Discovery", "Availability Check", "Slot Booking", "Route Planning", "Payments", "User Profile"])

# Business Dashboard
box(CL_X+340, CL_Y+40, 300, 200, WHITE, BLUE_BORDER)
center_text("Business Dashboard", CL_X+490, CL_Y+52, font=font_md, fill=GREEN_DARK)
center_text("Flutter / Web", CL_X+490, CL_Y+75, font=font_xs, fill=GREY)
bullet_list(CL_X+360, CL_Y+95, ["Charger Fleet Mgmt", "Port Availability", "Booking Management", "Revenue Analytics", "Calendar / Schedule"])

# ─── API & BACKEND LAYER ─────────────────────────────────────────────
AB_X, AB_Y, AB_W, AB_H = 40, 380, 520, 240
box(AB_X, AB_Y, AB_W, AB_H, WHITE, GREEN_DARK, border_w=3)
center_text("API & BACKEND", AB_X + AB_W//2, AB_Y + 10, font=font_lg, fill=GREEN_DARK)
center_text("VoltEZ Backend  —  FastAPI / Python", AB_X + AB_W//2, AB_Y + 35, font=font_sm, fill=GREY)
bullet_list(AB_X+25, AB_Y+55, [
    "Auth & Authorization (JWT + Argon2)",
    "Charger & Port Management",
    "Booking & Slot Lifecycle",
    "Business Profile & Pricing Engine",
    "Analytics & Reporting",
    "AI Recommendation Service",
], font=font_sm)

# ─── EXTERNAL & REAL-WORLD DATA ──────────────────────────────────────
ER_X, ER_Y, ER_W, ER_H = 600, 380, 560, 130
box(ER_X, ER_Y, ER_W, ER_H, ORANGE_LIGHT, ORANGE_BORDER, border_w=2)
center_text("EXTERNAL SERVICES", ER_X + ER_W//2, ER_Y + 8, font=font_lg, fill=ORANGE_BORDER)

box(ER_X+15, ER_Y+35, 165, 80, WHITE, ORANGE_BORDER)
center_text("Payment Gateway", ER_X+97, ER_Y+47, font=font_sm, fill="#000")
center_text("Razorpay / Stripe", ER_X+97, ER_Y+67, font=font_xs, fill=GREY)

box(ER_X+195, ER_Y+35, 165, 80, WHITE, ORANGE_BORDER)
center_text("Maps & Location", ER_X+277, ER_Y+47, font=font_sm, fill="#000")
center_text("Google Maps / OSM", ER_X+277, ER_Y+67, font=font_xs, fill=GREY)

box(ER_X+375, ER_Y+35, 170, 80, WHITE, ORANGE_BORDER)
center_text("Charging Hardware", ER_X+460, ER_Y+47, font=font_sm, fill="#000")
center_text("IoT / Port Status", ER_X+460, ER_Y+67, font=font_xs, fill=GREY)

# ─── DATA & SERVICES LAYER ──────────────────────────────────────────
DS_X, DS_Y, DS_W, DS_H = 40, 680, 1120, 290
box(DS_X, DS_Y, DS_W, DS_H, CYAN_LIGHT, CYAN_BORDER, border_w=2)
center_text("DATA & SERVICES LAYER", DS_X + DS_W//2, DS_Y + 10, font=font_lg, fill=CYAN_BORDER)

# Notification Service
box(DS_X+20, DS_Y+40, 260, 100, WHITE, CYAN_BORDER)
center_text("Notification Service", DS_X+150, DS_Y+52, font=font_md, fill="#000")
bullet_list(DS_X+40, DS_Y+75, ["Booking Confirmations", "Availability Alerts", "Push Notifications"])

# AI / ML Engine
box(DS_X+300, DS_Y+40, 280, 100, WHITE, CYAN_BORDER)
center_text("AI / ML Engine", DS_X+440, DS_Y+52, font=font_md, fill="#000")
bullet_list(DS_X+320, DS_Y+75, ["Demand Prediction", "Dynamic Pricing", "Usage Insights"])

# Redis Cache
box(DS_X+600, DS_Y+40, 230, 100, WHITE, CYAN_BORDER)
center_text("Redis Cache", DS_X+715, DS_Y+52, font=font_md, fill="#000")
bullet_list(DS_X+620, DS_Y+75, ["Real-time Availability", "Session State", "Booking Holds"])

# PostgreSQL
box(DS_X+850, DS_Y+40, 240, 100, WHITE, CYAN_BORDER)
center_text("PostgreSQL + PostGIS", DS_X+970, DS_Y+52, font=font_md, fill="#000")
bullet_list(DS_X+870, DS_Y+75, ["Users, Bookings, Chargers", "Geo-spatial Queries", "Analytics Data"])

# ─── ARROWS ───────────────────────────────────────────────────────────

# Client → Backend (REST)
arrow(900, 195, 560, 480, color=GREY, w=2)
center_text("REST API", 730, 310, font=font_xs, fill=GREY)

# Backend → Client (Response)
arrow(560, 440, 900, 160, color=GREY, w=2)
center_text("Responses", 730, 280, font=font_xs, fill=GREY)

# Backend → External (Payment)
arrow(420, 380, 615, 415, color=ORANGE_BORDER, w=2)
center_text("Payment Request", 500, 385, font=font_xs, fill=ORANGE_BORDER)

# Backend → External (Maps)
arrow(350, 380, 780, 415, color=ORANGE_BORDER, w=2)
center_text("Location Query", 550, 395, font=font_xs, fill=ORANGE_BORDER)

# Backend → External (Hardware sync)
arrow(280, 380, 940, 415, color=ORANGE_BORDER, w=2)
center_text("Sync Status", 600, 405, font=font_xs, fill=ORANGE_BORDER)

# Backend → Data Layer
arrow(300, 620, 300, 680, color=CYAN_BORDER, w=2)
center_text("ML Features", 315, 645, font=font_xs, fill=CYAN_BORDER)

arrow(400, 620, 400, 680, color=CYAN_BORDER, w=2)
center_text("Cache/State", 415, 645, font=font_xs, fill=CYAN_BORDER)

arrow(500, 620, 500, 680, color=CYAN_BORDER, w=2)
center_text("Query/Update", 515, 645, font=font_xs, fill=CYAN_BORDER)

# Hardware → Data Layer (dashed)
dash_arrow(1030, 510, 1030, 680, color=ORANGE_BORDER, w=2)
center_text("Port Status", 1045, 595, font=font_xs, fill=ORANGE_BORDER)

# Backend → Notifications
arrow(170, 620, 170, 680, color=CYAN_BORDER, w=2)
center_text("Send Notifs", 175, 645, font=font_xs, fill=CYAN_BORDER)

# ─── BOTTOM LABELS ────────────────────────────────────────────────────
labels = ["REST Requests", "Location Data", "Payment Flows", "Real-time Status", "ML Predictions", "Cache Access"]
colors = [GREY, GREY, ORANGE_BORDER, ORANGE_BORDER, CYAN_BORDER, CYAN_BORDER]
sx = 120
for i, (lab, col) in enumerate(zip(labels, colors)):
    draw.rounded_rectangle([sx, H-30, sx+170, H-8], radius=6, fill=col, outline=None)
    center_text(lab, sx+85, H-28, font=font_xs, fill=WHITE)
    sx += 190

# ─── SAVE ─────────────────────────────────────────────────────────────
out = "/Users/swaraliwarade/Desktop/VoltEZ_Architecture.jpg"
img.save(out, "JPEG", quality=92)
print(f"Saved → {out}")
