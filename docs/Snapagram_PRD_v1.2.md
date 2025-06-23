# Snapagram – Product Requirements Document (PRD)

**Version:** 1.2  
**Owner:** Bob Banana (Solo Developer)  
**Last Updated:** 23 Jun 2025 (nav)  

---

## 1. Purpose & Vision
Snapagram is an Android‑only, camera‑first social‑messaging app that lets friends share photos and videos with fine‑grained control over snap lifetime. Users can post **public stories** or **friends‑only stories** that disappear after 24 hours.

---

## 2. Goals & Non‑Goals
|                   | Included in MVP | Out of Scope for MVP |
|-------------------|-----------------|----------------------|
| Direct photo/video snaps with TTL | ✔ | — |
| Group chat (≤10 users)           | ✔ | Groups >10 |
| Public & Friends‑Only Stories    | ✔ | Story comments |
| AR filters & face‑tracking stickers| ✔ | Advanced AR marketplace |
| End‑to‑end encryption for private content | ✔ | E2EE on *public* stories |
| Screenshot detection & logging   | ✔ | Perfect screenshot prevention |
| Moderation tools                 | ✖ | Manual/AI review before posting |
| Monetization / ads               | ✖ | Future release |

---

## 3. Personas
* **Core Friend** – college student sharing daily moments  
* **Story Seeker** – loves browsing infinite story feed  
* **Privacy‑First User** – posts friends‑only encrypted stories

---

## 4. Success Metrics
| Metric | Target |
|--------|--------|
| Monthly Active Users (beta) | 200 |
| Crash‑free sessions | ≥ 98 % |
| Cold‑start time | ≤ 3 s |
| Avg. story views (public) | ≥ 30 per story |
| Like engagement rate | ≥ 20 % of viewers |
| Bundle size | ≤ 40 MB |

---

## 5. Feature Scope (MVP)
## 5.1 Navigation & Core Screens

### Bottom Tab Bar (left ➜ right)

| Position | Tab | Primary Content | Icon Suggestion |
|----------|-----|-----------------|-----------------|
| 1 | **Explore** | Public stories feed (ALL + Friends' public posts) | `🧭` or Compass |
| 2 | **Friends** | Friends‑only stories feed | `👥` or Two‑user silhouette |
| 3 | **Post** <br><sub>(Raised‑center, 1.2× size)</sub> | Opens camera composer (photo/video capture & filter UI) | `📷` (filled) |
| 4 | **Chats** | Direct & group messages list | `💬` speech‑bubble |
| 5 | **Account** | Profile, settings, story deletion | `🙍` user‑circle |

* The **Post** tab is a floating‑action style button: centered, elevated 4 dp above the bar, 60 dp diameter, brand Accent‑Blue background, white camera icon.

* Tabs 1‑2 use **infinite scroll** stories UI. Tapping a story opens full‑screen viewer with swipe‑down dismiss.

* The bar hides on story viewer & camera screens, reappears on Chats & Account.



| ID | Feature | Key Details |
|----|---------|-------------|
| F1 | **Authentication** | Email/password & Google sign‑in |
| F2 | **Camera & Capture** | Launch‑to‑camera; photo + ≤ 60 s video |
| F3 | **Filters** | Brightness, Contrast, Saturation, Temp/Warmth, Vignette, Gaussian Blur, Crop/Rotate, Text Overlay, Sepia, B&W High‑Contrast, Pastelify LUT, Face‑tracking stickers |
| F4 | **Messaging** | Direct & group (≤ 10); per‑chat default TTL; per‑message override; screenshot logs |
| F5 | **Stories** | **Public** (unencrypted) & **Friends‑Only** (E2EE) stories; 24 h expiration; heart‑likes; share‑link copy; infinite scroll feed |
| F6 | **E2EE** | libsodium for chats & friends‑only stories; Google‑token encrypted key backup |
| F7 | **TTL Enforcement** | Pub/Sub ➜ Cloud Tasks for second‑level deletions; 24 h auto‑purge for stories |
| F8 | **Friends** | Username search/add |
| F9 | **Push Notifications** | Incoming snaps & requests only (no story alerts) |

---

## 6. Non‑Functional Requirements
* **Performance:** cold start ≤ 3 s; 16 ms frame budget  
* **Security:** App Check, Play‑Integrity, no Firebase debug creds  
* **Scalability:** Cloud Tasks ≤ 100 TPS (beta)  
* **Compliance:** GDPR export & delete endpoints  
* **Accessibility:** WCAG AA color contrast

---

## 7. Technical Architecture Updates

### 7.1 Stories Data Flow
```mermaid
graph TD
  subgraph Client
    A[Camera + Filters] --> B[Encrypt if Friends‑Only]
    B --> C[Upload Media to Storage]
    C --> D[Write Story Doc to /stories]
    D -->|Pub/Sub| E
  end
  subgraph Cloud
    E[Pub/Sub "expiresAt"] --> F[Cloud Task schedule]
    F --> G[Cloud Function delete story]
  end
  H[Story Feed Listener] <-- C
```

### 7.2 Encryption Note
* **Public stories**: stored plaintext in Storage & Firestore.  
* **Friends‑only stories**: encrypted with sender’s *story‑group* key (derived from friend list); complexity ≈ group‑chat encryption. Adds ~2 KB metadata per viewer list.

---

## 8. Milestones & Timeline (Dates TBD)

| Milestone | Goal | Deliverables |
|-----------|------|--------------|
| **M0** | Environment ready | Repo, Firebase, CI |
| **M1** | Auth + Camera | F1, F2 |
| **M2** | Private Messaging | F4, F6, F7 |
| **M3** | Group chat | Extend to ≤ 10 |
| **M4** | Filters + AR stickers | F3 performance pass |
| **M5** | **Stories Release** | F5 integrated; feed UI |
| **M6** | Closed‑beta Play Store | Metrics dashboard |

---

## 9. Task Breakdown Additions

### 9.8 Stories Module
- **9.8.1** Add "Stories" tab layout (bottom‑nav placeholder)
- **9.8.2** Story composer screen reuse capture & filters
- **9.8.3** Post‑flow: flag "Public" vs "Friends Only"
- **9.8.4** Encrypt media if friends‑only
- **9.8.5** Upload media → Storage; write `/stories/{storyId}` doc  
  ```js
  { uid, type, isPublic, hearts: 0, views: 0, shares: 0,
    expiresAt, mediaURL, encryptedKey? }
  ```
- **9.8.6** Publish Pub/Sub `expiresAt` message
- **9.8.7** Cloud Task target to delete story & media
- **9.8.8** Implement infinite‑scroll feed (paged Firestore query)
- **9.8.9** Heart button optimistic update; increment via transaction
- **9.8.10** Share‑link copy → dynamic link (firebase.app.link)
- **9.8.11** Add metrics counters (view once per uid)

### Updated Numbers
(re‑number existing tasks after insertion)

---

## 10. Risks & Mitigations
| Risk | Mitigation |
|------|------------|
| Unmoderated public stories may host abusive content | Add "Report Story" button in v1.1 |
| Friends‑only E2EE stories complexity | Use same group‑chat encryption helper; start with ≤ 1 k friends |
| Cloud Tasks cost spike from stories | Batch schedule deletions at min(24 h, now+1 h) intervals |

---

## 11. Future Enhancements
* Story comments  
* Story push‑notifications & mute per friend  
* Moderation queue with ML flagging

---

## 12. Appendix A – Pastel Palette
*(unchanged)*

---

<small>© 2025 Snapagram – internal use only</small>
