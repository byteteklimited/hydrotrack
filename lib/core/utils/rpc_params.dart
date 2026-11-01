/// A server function's parameters from a payload: `p_tenant_id` plus each
/// key with the `p_` prefix. Offline records keep the bare payload (see
/// `apply_device_operation`), so online and offline send the same values.
Map<String, dynamic> rpcParams(String tenantId, Map<String, dynamic> payload) {
  return {
    'p_tenant_id': tenantId,
    for (final entry in payload.entries) 'p_${entry.key}': entry.value,
  };
}

/// `YYYY-MM-DD`, the way the server's `date` parameters expect it.
String dateParam(DateTime date) => date.toIso8601String().split('T').first;
