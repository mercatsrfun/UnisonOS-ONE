<!--
- SPDX-FileCopyrightText: 2026 Redmer
- SPDX-License-Identifier: GPL-2.0-or-later
-->

# UnisonOS ONE Shell
A high-fidelity, 1:1 Figma-accurate shell implementation for Plasma Mobile. Argon focuses on modern "liquid" UI interactions, custom GPU shaders, and physics-based motion.

* **Platform:** KDE Plasma Mobile (Qt6 / QML)
* **Design Foundation:** 1:1 Figma Accuracy

---

### Key Features
* Liquid morph effects
* Security & Privacy
* Pre-made apps for all your needs
* Consistent design system
* Animation "engine"

### Lockscreen DEMO


https://github.com/user-attachments/assets/ae80ced9-efae-4bb6-b08a-7a5d95a7cd37


### Locations of added content
* `shell/contents/lockscreen/NowBarPill.qml` - Nowbar QML
* `shell/contents/lockscreen/coloros_metaball.frag` - Supposed animation engine (its just responsible for liquid effects + most animations)

### Locations of where content was changed
* `shell/contents/lockscreen/lockscreen.qml` - ...I forgot? but i think i wired NowBarPill.qml into this?
* `shell/contents/lockscreen/lockscreencontent.qml` - I think it was this?
* `shell/contents/lockscreen/clock.qml` - Oh hey this is where i added the clock style you currently see in the demo
* `i added the wallpaper... somewhere` - What it says
* `shell/contents/lockscreen/Keypad.qml` - keypad
* `shell/contents/lockscreen/passwordbar.qml` - Passcode





