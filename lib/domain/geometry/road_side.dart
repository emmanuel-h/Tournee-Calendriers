/// A side of a road, walking it the way its line runs: IGN gives each
/// stretch of road the BAN street of each side (PLAN §5.18), so a tap
/// between two streets sharing one road names the one on the finger's side.
enum RoadSide {
  /// On the left hand, walking the line from its first point to its last.
  left,

  /// On the right hand, walking the line from its first point to its last.
  right,
}
