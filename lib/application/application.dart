/// Application layer: use cases (one class, one `call` method) and the
/// outbound ports they need (`Clock`, `AddressDirectory`, `OfflineMapStore`, …).
///
/// Depends on the domain only. A use case loads an aggregate through a port,
/// calls the aggregate root and saves the resulting change through the port.
library;
