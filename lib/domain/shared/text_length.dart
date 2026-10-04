/// The number of characters in [text], in the sense every length limit of
/// the app uses (notes, « repasser » hints).
///
/// A Dart `String` is a sequence of UTF-16 code units, so `text.length`
/// counts an emoji such as 🚒 as 2. This counts Unicode code points
/// (`text.runes`) instead: 🚒 is 1, like `é` typed as one key. The Firestore
/// security rules must count the same way so the phone and the server agree
/// on each limit (PLAN §8.2); the rules tests check it with emoji (T2.4).
///
/// Some symbols the eye sees as one are several code points (a family emoji,
/// an accent typed as a separate mark): each code point counts.
int characterCount(String text) => text.runes.length;
