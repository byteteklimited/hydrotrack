/// How money physically moved: cash in hand, or through the bank. Shared
/// by Debts and Finance — one channel vocabulary, not a per-feature copy.
enum PaymentChannel { cash, transfer }

extension PaymentChannelLabel on PaymentChannel {
  String get label => switch (this) {
    PaymentChannel.cash => 'Cash',
    PaymentChannel.transfer => 'Transfer',
  };
}
