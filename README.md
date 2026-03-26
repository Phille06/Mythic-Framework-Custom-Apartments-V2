# Mythic Apartments Walkin

A comprehensive apartment system for the Mythic Framework, featuring interior support, elevator navigation, police raiding, and automatic apartment management.

> **Based on the work of:**
> - [ISKinGeR/mythic-apartments](https://github.com/ISKinGeR/mythic-apartments)
> - [Capestick/mythic-apartments](https://github.com/Capestick/mythic-apartments)
> - [xDev05x/Mythic-Framework-Custom-Apartments](https://github.com/xDev05x/Mythic-Framework-Custom-Apartments)

---

## Features

### 🏠 Interior System
- Full interior support with seamless entry/exit transitions
- Multiple apartment tiers with upgradeable stash storage
- Wardrobe and shower interactions inside apartments
- Per-apartment furniture spawning tied to building floors

### 🛗 Elevator System
- Multi-floor elevator navigation with a clean list menu
- Camera shake and screen fade animations for immersion
- Floor furniture is pre-loaded during the elevator transition to eliminate pop-in
- Tracks current floor state across all relevant systems

### 👮 Police Raiding
- Police officers can initiate apartment raids
- Doors automatically unlock during an active raid
- Raid state is synced in real-time across all clients via GlobalState
- Doors automatically re-lock when the apartment owner returns

### 🎁 Auto-Assignment
- New characters are automatically assigned a starter apartment on first spawn
- Door access is configured immediately upon assignment
- Assignment confirmation email is sent to the player's in-game phone
- Reception desk NPCs allow players to request or look up their apartment

### 🗑️ Automatic Cleanup
- Apartments are automatically released after **30 days of inactivity**
- Checks the character's `LastPlayed` timestamp on server start
- Released apartments are immediately returned to the available pool
- Prevents the apartment pool from being exhausted by inactive players

### 📦 Stash Upgrades
- Players can upgrade their apartment stash up to Tier 3
- Upgrade cost is shown upfront with a confirmation dialog before any charge
- Upgrade cost is deducted from the player's bank account

### 🗺️ Supported MLOs
The following MLOs are supported and configured out of the box:
- **Kiya** — Kiya Apartment MLO -- **Not TESTED**
- **Wining** — Wining Apartment MLO

---
