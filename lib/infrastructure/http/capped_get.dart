import 'dart:typed_data';

import 'package:http/http.dart' as http;

/// Thrown by [cappedGet] when an answer is longer than allowed: the
/// service is not sending what the app asked for, which the adapters tell
/// as a service error.
final class ResponseTooLarge implements Exception {
  const ResponseTooLarge(this.url);

  /// The address whose answer was refused.
  final Uri url;

  @override
  String toString() => 'ResponseTooLarge: the answer of $url is too long';
}

/// GETs [url] with [client] like `client.get`, but reads at most
/// [maxBytes] bytes of the answer: a service sending far more than it
/// should (by mistake, or on purpose) cannot fill the phone's memory.
///
/// Throws [ResponseTooLarge] past [maxBytes], before reading anything when
/// the server announces the length (`Content-Length`), otherwise as soon
/// as the bytes read go past it. Any other error of the client (no
/// network, connection cut) is passed on as `client.get` would.
Future<http.Response> cappedGet(
  http.Client client,
  Uri url, {
  required Map<String, String> headers,
  required int maxBytes,
}) async {
  // `client.get` would read the whole answer before handing it over;
  // `send` hands over the answer's bytes as a stream, as they arrive.
  final streamed = await client.send(
    http.Request('GET', url)..headers.addAll(headers),
  );
  if (streamed.contentLength case final length? when length > maxBytes) {
    // Listening then cancelling at once tells the client the answer is not
    // wanted, so it closes the connection instead of reading the bytes
    // (`drain` would read them all).
    await streamed.stream.listen(null).cancel();
    throw ResponseTooLarge(url);
  }
  final body = BytesBuilder(copy: false);
  // Throwing inside an `await for` stops listening to the stream, so the
  // rest of the answer is never read.
  await for (final chunk in streamed.stream) {
    if (body.length + chunk.length > maxBytes) throw ResponseTooLarge(url);
    body.add(chunk);
  }
  return http.Response.bytes(
    body.takeBytes(),
    streamed.statusCode,
    request: streamed.request,
    headers: streamed.headers,
    isRedirect: streamed.isRedirect,
    persistentConnection: streamed.persistentConnection,
    reasonPhrase: streamed.reasonPhrase,
  );
}
