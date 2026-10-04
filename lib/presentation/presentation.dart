/// Presentation layer: Riverpod `Notifier`s and the immutable view states they
/// expose to `ui/`.
///
/// Notifiers call use cases only: no Flutter widget and no infrastructure
/// import, so they are tested through a `ProviderContainer` with the ports
/// overridden by fakes.
library;
