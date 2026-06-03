<h1 align="center">KÚLA</h1>

<p align="center">
  A native macOS billing &amp; invoicing app for Icelandic businesses.<br>
  Built entirely in Swift with SwiftUI &amp; SwiftData.
</p>

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2014%2B-blue.svg" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.0-orange.svg" alt="Swift 6">
  <img src="https://img.shields.io/badge/license-MIT-green.svg" alt="MIT">
</p>

---

KÚLA is a focused, offline-first invoicing app. Your financial data stays on your Mac
(SwiftData / local store) — no accounts, no cloud, no tracking. The invoice layout follows
the standard Icelandic format, and invoices can be exported as **PDF** or as a
**TS-136 / PEPPOL BIS Billing 3.0** electronic invoice (UBL 2.1 XML).

## Features

- **Multiple companies** — keep several businesses in one app and switch between them.
  Invoices and customers are fully separated per company, each with its own invoice numbering.
- **Icelandic invoice template** — correct header order, VAT (VSK) per line item,
  amounts with/without VAT, kennitala, bank claim number, legal footer (reglugerð nr. 505/2013).
- **Dashboard** — Payday-style overview per company: 12-month sales, collected vs. outstanding,
  collection rate, average payment speed, overdue invoices, and a monthly sales chart.
- **Customers** — per-customer dashboard (invoices, totals, payment speed, year-over-year),
  notes, and import from the macOS **Contacts** app.
- **Export** — PDF, electronic invoice (UBL/TS-136 XML), or batch-export *all* invoices
  (PDF + XML) to a folder at once.
- **Native macOS** — proper menu commands (⌘N, ⌘P, ⌘E …), Page Setup, print, "Open in Preview",
  email via Mail with the PDF attached, Settings scene, light/dark mode.
- **Customisable** — logo, font family &amp; sizes, text colour, paper size (A4 / US Letter),
  custom invoice statuses, per-company defaults.
- **Localised** — user interface in Icelandic.

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 16 or later (Swift 6)

## Building &amp; running

Open the Xcode project and run:

```sh
open KULA.xcodeproj
```

Then select the **KULA** scheme and press **⌘R**.

The same sources also build as a Swift package (used for the test suite):

```sh
swift build      # compile the KULA library
swift test       # run the unit tests
```

> The app entry point (`KULAApp.swift`) is excluded from the SwiftPM library target so the
> tests can link cleanly; the Xcode app target includes it.

## Project structure

```
Sources/KULA/
  KULAApp.swift          App entry point + menu commands
  FocusedActions.swift   Menu-command plumbing (⌘N, ⌘P, export …)
  Models/                Invoice, LineItem, Contact, AppSettings (company), CustomStatus, Money
  Views/                 ContentView, Dashboard, invoice list/detail, customers, settings
  Templates/             IcelandicTemplate (SwiftUI → PDF)
  PDF/                   PDF rendering, printing, Page Setup, Preview, email
  Export/                UBL/TS-136 XML exporter, batch exporter
  Import/                Contacts.app importer
Tests/KULATests/         Invoice math, settings, and UBL export tests
App/                     Assets, entitlements
```

## Notes on correctness

- All monetary amounts use `Decimal` (never `Double`).
- Totals are **derived**, not stored — change a line item, discount or VAT and totals update.
- VAT is calculated **per line item**, so an invoice can mix rates (0 % / 11 % / 24 %).
- Each invoice records its issuing company, so historical invoices never change when you
  edit a company or switch the active one.

## Electronic invoicing (TS-136 / PEPPOL)

KÚLA generates a UBL 2.1 invoice compliant with **PEPPOL BIS Billing 3.0** (the basis of the
Icelandic TS-136 CIUS), with the Icelandic kennitala on EAS scheme `0196`. The XML document is
produced locally; to *transmit* it over the PEPPOL network you still need a PEPPOL access point
(e.g. a service provider) and a participant certificate.

## Tests

```sh
swift test
```

Covers invoice/VAT math, per-company settings resolution, and UBL XML generation.

## License

[MIT](LICENSE) © 2026 Ólafur H. Jónsson

Invoice layout inspired by [Manta](https://github.com/hql287/Manta); KÚLA shares no source code with it.
