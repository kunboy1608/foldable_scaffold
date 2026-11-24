import Flutter
import UIKit

/// Sends the reserved regions of the Flutter view (the fold of iPhone Duo, the
/// cameras, the Dynamic Island) and the edge of the system's vertical bars to
/// Dart. The protocol is described by `ChannelFoldablePlatformSource` in Dart.
///
/// The code calls APIs of the iOS 27.1 SDK, so building this plugin needs an
/// Xcode that has it. On an iOS older than 27.1 the calls are skipped
/// (`#available`) and the plugin answers with no regions and no vertical bar
/// edge.
///
/// Changes are found by watching the bounds of the view and by a light display
/// link that compares the state, both only while Dart listens to the events.
/// Nothing is swizzled, and no `FlutterViewController` is subclassed.
public final class FoldableScaffoldPlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private static let protocolVersion = 1

  private weak var registrar: FlutterPluginRegistrar?
  private var eventSink: FlutterEventSink?
  private var lastSentState: [String: Any]?

  private var displayLink: CADisplayLink?
  private var boundsObservation: NSKeyValueObservation?
  private weak var observedView: UIView?
  private var lifecycleObservers: [NSObjectProtocol] = []

  init(registrar: FlutterPluginRegistrar) {
    self.registrar = registrar
    super.init()
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = FoldableScaffoldPlugin(registrar: registrar)
    let methodChannel = FlutterMethodChannel(
      name: "foldable_scaffold/platform", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: methodChannel)
    let eventChannel = FlutterEventChannel(
      name: "foldable_scaffold/platform/events", binaryMessenger: registrar.messenger())
    eventChannel.setStreamHandler(instance)
  }

  public func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    stopWatching()
    eventSink = nil
  }

  // MARK: Method channel

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getState":
      result(makeState())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Event channel

  public func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    lastSentState = nil
    startWatching()
    sendIfChanged()
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopWatching()
    eventSink = nil
    lastSentState = nil
    return nil
  }

  // MARK: Watching

  private func startWatching() {
    guard displayLink == nil else { return }
    let link = CADisplayLink(target: DisplayLinkTarget(self), selector: #selector(DisplayLinkTarget.tick))
    // A comparison of two small dictionaries, so a low rate is enough. This
    // number is a guess that has not been measured on a device.
    link.preferredFramesPerSecond = 10
    link.add(to: .main, forMode: .common)
    displayLink = link

    // Do not poll while the app is in the background.
    let center = NotificationCenter.default
    lifecycleObservers = [
      center.addObserver(
        forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main
      ) { [weak self] _ in self?.displayLink?.isPaused = true },
      center.addObserver(
        forName: UIApplication.willEnterForegroundNotification, object: nil, queue: .main
      ) { [weak self] _ in
        self?.displayLink?.isPaused = false
        self?.sendIfChanged()
      },
    ]
    observeBounds(of: flutterView())
  }

  private func stopWatching() {
    displayLink?.invalidate()
    displayLink = nil
    boundsObservation = nil
    observedView = nil
    for observer in lifecycleObservers {
      NotificationCenter.default.removeObserver(observer)
    }
    lifecycleObservers = []
  }

  fileprivate func tick() {
    // The view controller can show up after the plugin started, or be replaced.
    observeBounds(of: flutterView())
    sendIfChanged()
  }

  /// A change of size is reported at once instead of at the next tick.
  private func observeBounds(of view: UIView?) {
    guard view !== observedView else { return }
    observedView = view
    boundsObservation = view?.layer.observe(\.bounds) { [weak self] _, _ in
      // Not in the middle of a layout pass.
      DispatchQueue.main.async { self?.sendIfChanged() }
    }
  }

  private func sendIfChanged() {
    guard let sink = eventSink else { return }
    let state = makeState()
    if let last = lastSentState, (last as NSDictionary).isEqual(to: state) { return }
    lastSentState = state
    sink(state)
  }

  // MARK: State

  private func flutterView() -> UIView? {
    return registrar?.viewController?.view
  }

  private func makeState() -> [String: Any] {
    let view = flutterView()
    var state: [String: Any] = [
      "version": Self.protocolVersion,
      "width": Double(view?.bounds.width ?? 0),
      "height": Double(view?.bounds.height ?? 0),
      "divisions": [[String: Any]](),
      "occlusions": [[String: Any]](),
      "verticalBarEdge": "unspecified",
    ]
    if #available(iOS 27.1, *), let view = view {
      state["divisions"] = Self.regions(.division, in: view)
      state["occlusions"] = Self.regions(.occlusion, in: view)
      state["verticalBarEdge"] = Self.verticalBarEdge(of: view)
    }
    return state
  }

  /// The regions of a kind, active or not, in the coordinates of `view`
  /// (points, margins included).
  @available(iOS 27.1, *)
  private static func regions(
    _ kind: UIView.ReservedRegion.Kind, in view: UIView
  ) -> [[String: Any]] {
    return view.reservedRegions(kind: kind, options: .includeInactive).map { region in
      let frame = region.frame
      let margins = region.margins
      return [
        "left": Double(frame.minX),
        "top": Double(frame.minY),
        "right": Double(frame.maxX),
        "bottom": Double(frame.maxY),
        "isActive": region.isActive,
        "margins": [
          "left": Double(margins.left),
          "top": Double(margins.top),
          "right": Double(margins.right),
          "bottom": Double(margins.bottom),
        ],
      ]
    }
  }

  @available(iOS 27.1, *)
  private static func verticalBarEdge(of view: UIView) -> String {
    switch view.traitCollection.verticalBarEdge {
    case .leading: return "leading"
    case .trailing: return "trailing"
    case .unspecified: return "unspecified"
    @unknown default: return "unspecified"
    }
  }
}

/// Holds the plugin weakly, as a display link retains its target.
private final class DisplayLinkTarget: NSObject {
  private weak var plugin: FoldableScaffoldPlugin?

  init(_ plugin: FoldableScaffoldPlugin) {
    self.plugin = plugin
  }

  @objc func tick() {
    plugin?.tick()
  }
}
