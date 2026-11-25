/// One of the two slots a two-pane layout gives its content, or the single
/// area a layout without a split gives it.
///
/// Provider: none — this is pure vocabulary.
/// Consumer: `foldable_scaffold` (around each pane), `foldable_router`
/// (around each page, via `FoldablePaneScope`), and app pages that ask
/// "which slot am I in?" through `FoldablePaneScope`.
enum FoldablePane {
  /// The content is not assigned to a slot: it fills the whole pane area
  /// (a one-pane layout, a full-screen page above a shell, a dialog).
  single,

  /// The first slot: the body of a `FoldableScaffold`, the page below the top
  /// one in a two-pane shell tab.
  primary,

  /// The second slot: the secondary body of a `FoldableScaffold`, the top page
  /// of a two-pane shell tab.
  secondary;

  /// Whether this value names one of the two slots of a split layout.
  ///
  /// `single` returns `false`; `primary` and `secondary` return `true`.
  bool get isSlot => this != FoldablePane.single;
}
