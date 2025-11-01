import SwiftUI

struct OrderConfirmationView: View {
    let order: Order
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.green)
                    .padding(.top, 40)

                VStack(spacing: 12) {
                    Text("تم إرسال طلبك بنجاح")
                        .font(.title2.weight(.semibold))
                    Text("سيتواصل فريق ديكوري معك لتأكيد الطلب والدفع عند الاستلام.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)

                VStack(spacing: 16) {
                    if let reference = order.payment.reference, !reference.isEmpty {
                        infoRow(title: "المرجع", value: reference)
                    } else {
                        infoRow(title: "رقم الطلب", value: order.id)
                    }

                    infoRow(title: "الإجمالي", value: order.formattedTotal())
                    infoRow(title: "العنوان", value: order.address)

                    if !order.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        infoRow(title: "ملاحظاتك", value: order.notes)
                    }
                }
                .padding()
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                VStack(alignment: .leading, spacing: 12) {
                    Text("ملخص العناصر")
                        .font(.headline)
                    ForEach(order.items) { item in
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.displayName)
                                    .font(.subheadline.weight(.semibold))
                                if let color = item.color, !color.isEmpty {
                                    Text("اللون: \(color)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                if let measure = item.measure, !measure.isEmpty {
                                    Text("المقاس: \(measure)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 4) {
                                Text("x\(item.quantity)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                Text(order.currencyFormatter.string(from: NSNumber(value: item.totalPrice)) ?? "")
                                    .font(.footnote)
                            }
                        }
                        .padding(.vertical, 8)
                        if item.id != order.items.last?.id {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal)

                Button(action: dismiss.callAsFunction) {
                    Text("العودة للتسوق")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .foregroundColor(.white)
                }
                .padding(.horizontal)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("تأكيد الطلب")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func infoRow(title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.body.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    NavigationStack {
        OrderConfirmationView(order: Order.samples().first ?? Order(id: "demo"))
    }
}
