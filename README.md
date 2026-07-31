# VOIDSTACK

Ein neonfarbenes 3D-Würfel-Eliminierungs-Puzzle: Wähle eine Spalte, schiebe die
**markierten** Stapel ins Nichts, bevor sie die vordere Kante erreichen — und
lass die **unmarkierten** Stapel unangetastet vorbeiziehen.

Original-Spielkonzept und komplette Neuentwicklung (Grafik, Sound, Code),
inspiriert vom Genre der Würfel-Eliminierungs-Puzzles der späten 90er
(z. B. *Kurushi* / *Intelligent Qube*). **Keine Verbindung zu, keine Assets
von und keine Zugehörigkeit zu Sony Interactive Entertainment.** Kein
Originalcode, keine Originalgrafik, keine Originalmusik und kein
Original-Branding dieser Titel wurde verwendet.

## Struktur

```
web/    Browser-Version (Three.js, WebGL) — läuft auch als installierbare
        PWA auf iPhone/iPad (Safari → Teilen → "Zum Home-Bildschirm")
ios/    Native iOS-App (SwiftUI + SceneKit), universell für iPhone & iPad
```

Beide Versionen teilen dieselbe Spiellogik (unabhängig in JavaScript bzw.
Swift implementiert) und denselben visuellen/akustischen Stil: Bloom-
Postprocessing, emissive Neon-Materialien, Partikel-Effekte und ein
vollständig **prozedural synthetisierter Sound** (Web Audio API bzw.
AVAudioEngine) — es sind keine externen Audio- oder 3D-Asset-Dateien
enthalten.

## Web-Version

Reines HTML/CSS/JS ohne Build-Schritt, Three.js wird via ES-Module-CDN
geladen.

```bash
cd web
python3 -m http.server 8080
# dann im Browser: http://localhost:8080
```

Steuerung: Pfeiltasten/`A`/`D` zum Wählen, Leertaste zum Schieben, `P`/`Esc`
für Pause. Touch: tippen zum Wählen einer Spalte, nach oben wischen zum
Schieben, oder die Buttons am unteren Rand.

Zum Deployen genügt es, den Inhalt von `web/` auf einen beliebigen statischen
Hoster zu legen (z. B. GitHub Pages). Der Service Worker registriert sich
bewusst **nicht** auf `localhost`, damit lokale Entwicklung nie an gecachtem
Code hängen bleibt.

## iOS-Version (iPhone & iPad, universell)

Das Xcode-Projekt wird aus `ios/project.yml` via
[XcodeGen](https://github.com/yonaskolb/XcodeGen) generiert (das `.xcodeproj`
selbst ist nicht eingecheckt):

```bash
brew install xcodegen   # falls noch nicht vorhanden
cd ios
xcodegen generate
open VoidStack.xcodeproj
```

Build & Run über Xcode (Simulator oder eigenes Gerät mit eigenem
Entwicklerteam in den Signing-Einstellungen). Verifiziert mit:

```bash
xcodebuild -project VoidStack.xcodeproj -scheme VoidStack \
  -destination 'platform=iOS Simulator,name=iPhone 17' build
```

Architektur: `GameEngine.swift` (reine Spiellogik) → `GameController.swift`
(verbindet Logik, `AudioEngine` und `GameSceneCoordinator`) → SceneKit-Szene
mit natives `SCNCamera`-Bloom + SwiftUI-Overlays, die sich per
`horizontalSizeClass` zwischen iPhone- und iPad-Layout anpassen.

## Lizenz

MIT, siehe [LICENSE](LICENSE). Three.js (MIT) wird zur Laufzeit per CDN
eingebunden, ist aber nicht Teil dieses Repositories.
