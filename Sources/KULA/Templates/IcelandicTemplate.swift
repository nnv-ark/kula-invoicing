import SwiftUI

struct IcelandicTemplate: View {
    let invoice: Invoice
    let settings: AppSettings

    private let hPad: CGFloat = 48

    /// Pappírsstærð í punktum (72 dpi).
    static func pageSize(_ paper: String) -> CGSize {
        switch paper {
        case "letter": CGSize(width: 612, height: 792)
        default:       CGSize(width: 595.28, height: 841.89)   // A4
        }
    }

    private var page: CGSize { Self.pageSize(settings.paperSize) }
    private var textColor: Color { Color(hex: settings.textColorHex) ?? .black }

    private func font(_ size: Double, weight: Font.Weight = .regular) -> Font {
        if settings.fontName.isEmpty {
            .system(size: size, weight: weight)
        } else {
            .custom(settings.fontName, fixedSize: size).weight(weight)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            topHeader
                .padding(.horizontal, hPad)
                .padding(.top, 36)
                .padding(.bottom, 18)

            Divider()

            metaBanner
                .padding(.horizontal, hPad)
                .padding(.vertical, 18)
                .background(Color(white: 0.93))

            itemsTable
                .padding(.horizontal, hPad)
                .padding(.top, 24)

            totalsRow
                .padding(.horizontal, hPad)
                .padding(.top, 12)

            if !invoice.note.isEmpty {
                notesView
                    .padding(.horizontal, hPad)
                    .padding(.top, 28)
            }

            Spacer(minLength: 0)

            Divider()
            footer
                .padding(.horizontal, hPad)
                .padding(.vertical, 14)
        }
        .frame(width: page.width, height: page.height, alignment: .top)
        .background(.white)
        .foregroundStyle(textColor)
        .font(font(settings.baseFontSize))
    }

    // MARK: - Top header

    private var topHeader: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                if let data = settings.logoData, let img = NSImage(data: data) {
                    // Lógó með stuttum texta miðjusettum undir því.
                    VStack(alignment: .center, spacing: 4) {
                        Image(nsImage: img)
                            .resizable().scaledToFit()
                            .frame(maxWidth: 140 * settings.logoScale,
                                   maxHeight: 60 * settings.logoScale)
                        if !settings.companyTagline.isEmpty {
                            Text(settings.companyTagline)
                                .font(.system(size: 8))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(width: 140 * settings.logoScale)
                } else {
                    Text(settings.companyName.isEmpty ? "FYRIRTÆKI" : settings.companyName.uppercased())
                        .font(font(settings.headingFontSize, weight: .black))
                    if !settings.companyTagline.isEmpty {
                        Text(settings.companyTagline)
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                // Röð skv. mynd: nafn → kt. → heimilisfang+sími → netfang → reikningsnr. → VSK-númer
                Text(settings.companyName).font(font(15, weight: .bold))
                if !settings.companyNationalID.isEmpty {
                    Text("kt. \(settings.companyNationalID)")
                }

                let addrLine = [settings.companyAddress.replacingOccurrences(of: "\n", with: ", "),
                                settings.companyPhone.isEmpty ? nil : "Sími: \(settings.companyPhone)"]
                    .compactMap { ($0?.isEmpty == false) ? $0 : nil }
                    .joined(separator: ", ")
                if !addrLine.isEmpty {
                    Text(addrLine).bold().padding(.top, 6)
                }
                if !settings.companyEmail.isEmpty {
                    Text(settings.companyEmail).padding(.top, 6)
                }
                if !settings.bankAccountNumber.isEmpty {
                    Text("Reikningsnr: \(settings.bankAccountNumber)").padding(.top, 6)
                }
                if !settings.companyVATNumber.isEmpty {
                    Text("VSK númer: \(settings.companyVATNumber)")
                }
            }
        }
    }

    // MARK: - Meta banner (recipient + invoice meta)

    private var metaBanner: some View {
        HStack(alignment: .top, spacing: 24) {
            VStack(alignment: .leading, spacing: 3) {
                if let r = invoice.recipient {
                    Text(r.company.isEmpty ? r.name : r.company)
                    Text(r.address)
                    if !r.nationalID.isEmpty { Text("kt. \(r.nationalID)") }
                }
            }
            Spacer(minLength: 80)
            VStack(alignment: .leading, spacing: 3) {
                metaRow("Reikningur nr.", invoice.number, boldLabel: true)
                metaRow("Viðskiptanúmer", invoice.recipient?.nationalID ?? "")
                metaRow("Bókunardagur", date(invoice.bookingDate ?? invoice.issueDate))
                metaRow("Eindagi", date(invoice.dueDate ?? invoice.issueDate))
                metaRow("Innh.máti", invoice.collectionMethod)
            }
            .frame(width: 260)
        }
    }

    private func metaRow(_ label: String, _ value: String, boldLabel: Bool = false) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).fontWeight(boldLabel ? .bold : .regular)
            Spacer()
            Text(value).fontWeight(boldLabel ? .bold : .regular)
        }
    }

    private func date(_ d: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "is_IS")
        f.dateFormat = "d.M.yyyy"
        return f.string(from: d)
    }

    // MARK: - Items table

    private var itemsTable: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom, spacing: 8) {
                col("Lýsing", width: nil, align: .leading).bold()
                col("Magn", width: 50, align: .trailing).bold()
                colTwoLine("Upphæð", "(án VSK)", width: 60).bold()
                colTwoLine("Upphæð", "(með VSK)", width: 60).bold()
                col("VSK", width: 40, align: .trailing).bold()
                colTwoLine("Samtals", "(án VSK)", width: 75).bold()
                colTwoLine("Samtals", "(með VSK)", width: 75).bold()
            }
            .padding(.bottom, 6)

            Divider()

            ForEach(invoice.orderedItems) { item in
                HStack(alignment: .top, spacing: 8) {
                    col(item.itemDescription, width: nil, align: .leading)
                    col(item.quantity.formatted(), width: 50, align: .trailing)
                    col(amount(item.unitPrice), width: 60, align: .trailing)
                    col(amount(item.unitPriceIncTax), width: 60, align: .trailing)
                    col("\(item.taxRate.formatted())%", width: 40, align: .trailing)
                    col(currency(item.subtotal), width: 75, align: .trailing)
                    col(currency(item.subtotalIncTax), width: 75, align: .trailing)
                }
                .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private func col(_ text: String, width: CGFloat?, align: Alignment) -> some View {
        if let w = width {
            Text(text).frame(width: w, alignment: align)
        } else {
            Text(text).frame(maxWidth: .infinity, alignment: align)
        }
    }

    private func colTwoLine(_ a: String, _ b: String, width: CGFloat) -> some View {
        VStack(alignment: .trailing, spacing: 0) {
            Text(a)
            Text(b)
        }
        .frame(width: width, alignment: .trailing)
    }

    // MARK: - Totals

    private var totalsRow: some View {
        HStack(alignment: .top) {
            Spacer()
            VStack(alignment: .trailing, spacing: 5) {
                tRow("Samtals án VSK", currency(invoice.subtotal))
                if invoice.discountValue > 0 {
                    tRow(discountLabel, "-" + currency(invoice.discountValue))
                    tRow("Skattstofn", currency(invoice.taxableBase))
                }
                tRow("VSK", currency(invoice.taxValue))
                tRow("Samtals með VSK", currency(invoice.total), bold: true)
            }
            .frame(width: 260)
        }
    }

    private var discountLabel: String {
        "Afsláttur (\(amount(invoice.discountAmount))%)"
    }

    private func tRow(_ label: String, _ value: String, bold: Bool = false) -> some View {
        HStack {
            Text(label).fontWeight(bold ? .bold : .regular)
            Spacer()
            Text(value).fontWeight(bold ? .bold : .regular)
                .monospacedDigit()
        }
    }

    // MARK: - Notes

    private var notesView: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("Athugasemdir").bold()
            Text(invoice.note)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(alignment: .bottom) {
            Text("Þessi reikningur er rafrænt ytra frumgagn skv. reglugerð nr. 505/2013. Rafrænt ytra frumgagn reiknings telst frumrit hans.")
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 16)
            Text(invoice.number).bold()
                .font(font(14, weight: .bold))
        }
    }

    // MARK: - Formatting

    private func amount(_ d: Decimal) -> String {
        let f = NumberFormatter()
        f.locale = Locale(identifier: "is_IS")
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        return f.string(from: d as NSDecimalNumber) ?? "\(d)"
    }

    private func currency(_ d: Decimal) -> String {
        amount(d) + " kr."
    }
}
