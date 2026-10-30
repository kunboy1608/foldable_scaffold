// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:math' as math;

import 'package:foldable_router/foldable_router.dart';
import 'package:foldable_scaffold/foldable_scaffold.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import 'foldable_dev_tools_controller.dart';

/// Exposes a [FoldableDevToolsController] to the widgets below, like
/// `FoldablePaneLayoutObserver`.
class FoldableDevToolsScope
    extends InheritedNotifier<FoldableDevToolsController> {
  const FoldableDevToolsScope({
    required FoldableDevToolsController controller,
    required super.child,
    super.key,
  }) : super(notifier: controller);

  /// The controller of the closest [FoldableDevTools], if any.
  static FoldableDevToolsController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<FoldableDevToolsScope>()
        ?.notifier;
  }
}

/// An in-app overlay for developing foldable layouts.
///
/// Wrap the app *inside* `MaterialApp.builder`, so the overlay can use the
/// app's theme:
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) => FoldableDevTools(
///     router: router, // optional: logs push/pop/go
///     child: child!,
///   ),
/// )
/// ```
///
/// The overlay adds a small button in the corner of the screen that opens a
/// panel where you can:
///
/// * pretend the window is a phone, a closed or open foldable, a tablet or a
///   desktop, or drag a custom width and height;
/// * draw a hinge over the simulated screen and move it;
/// * slow every pane and page animation down;
/// * read the current pane layout (with `FoldablePaneLayoutObserver`) and the
///   navigation log.
///
/// It does nothing in release builds: only the [child] is shown.
class FoldableDevTools extends StatefulWidget {
  const FoldableDevTools({
    required this.child,
    super.key,
    this.controller,
    this.router,
    this.enabled = true,
    this.showButton = true,
  });

  /// The app.
  final Widget child;

  /// State of the overlay. One is created (and disposed) when omitted.
  final FoldableDevToolsController? controller;

  /// Router to log navigations from. Optional.
  final FoldableRouterBase? router;

  /// Whether the overlay is available at all. Defaults to true; it is also
  /// disabled in release builds.
  final bool enabled;

  /// Whether the small button that opens the panel is shown.
  final bool showButton;

  @override
  State<FoldableDevTools> createState() => _FoldableDevToolsState();
}

class _FoldableDevToolsState extends State<FoldableDevTools> {
  late final FoldableDevToolsController _controller =
      widget.controller ?? FoldableDevToolsController();

  bool get _ownsController => widget.controller == null;

  @override
  void initState() {
    super.initState();
    widget.router?.addObserver(_controller);
  }

  @override
  void didUpdateWidget(FoldableDevTools oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router != widget.router) {
      oldWidget.router?.removeObserver(_controller);
      widget.router?.addObserver(_controller);
    }
  }

  @override
  void dispose() {
    widget.router?.removeObserver(_controller);
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Release safe: the overlay is a development tool.
    if (!kDebugMode || !widget.enabled) return widget.child;

    return FoldableDevToolsScope(
      controller: _controller,
      child: FoldableMotion(
        scale: (duration) => _controller.slowMotion
            ? duration * _controller.slowMotionFactor
            : duration,
        child: ListenableBuilder(
          listenable: _controller,
          builder: (context, _) {
            return Stack(
              children: [
                Positioned.fill(
                  child: _SimulatedViewport(
                    controller: _controller,
                    child: widget.child,
                  ),
                ),
                // Material widgets such as Slider and Tooltip need an
                // Overlay. The app below already has the navigator's one, but
                // this overlay sits above the navigator, so it brings its own.
                Positioned.fill(
                  child: _DevToolsChrome(
                    controller: _controller,
                    showButton: widget.showButton,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Reports the pane layout of the [FoldableScaffold] it is placed in to the
/// closest [FoldableDevTools].
///
/// Put it anywhere inside the scaffold, for example as the first child of the
/// body. It draws nothing.
class FoldablePaneLayoutObserver extends StatelessWidget {
  const FoldablePaneLayoutObserver({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = FoldableDevToolsScope.maybeOf(context);
    final layout = FoldablePaneLayout.maybeOf(context);
    if (controller == null || layout == null) return const SizedBox.shrink();

    final size = MediaQuery.sizeOf(context);
    final info = FoldablePaneInfo(
      primaryVisible: layout.primaryVisible,
      secondaryVisible: layout.secondaryVisible,
      canSplit: FoldableScaffoldScope.maybeOf(context)?.canSplit ?? false,
      width: size.width,
      height: size.height,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.mounted) controller.reportPane(info);
    });
    return const SizedBox.shrink();
  }
}

/// The dev tools button and panel, in their own [Overlay].
///
/// `MaterialApp.builder` is outside the navigator's overlay, but Material
/// widgets like [Slider] and [Tooltip] need one. Keeping the overlay to the
/// chrome leaves the app's popups in the navigator's overlay, and inside the
/// simulated viewport.
class _DevToolsChrome extends StatefulWidget {
  const _DevToolsChrome({required this.controller, required this.showButton});

  final FoldableDevToolsController controller;
  final bool showButton;

  @override
  State<_DevToolsChrome> createState() => _DevToolsChromeState();
}

class _DevToolsChromeState extends State<_DevToolsChrome> {
  late final OverlayEntry _entry = OverlayEntry(builder: _buildChrome);

  @override
  void didUpdateWidget(_DevToolsChrome oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  Widget _buildChrome(BuildContext context) {
    final controller = widget.controller;
    return Stack(
      children: [
        if (widget.showButton)
          Positioned(
            right: 12,
            bottom: 12,
            child: _OpenButton(controller: controller),
          ),
        if (controller.isOpen)
          Positioned(
            top: 0,
            bottom: 0,
            right: 0,
            child: _Panel(controller: controller),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(initialEntries: [_entry]);
  }
}

class _SimulatedViewport extends StatelessWidget {
  const _SimulatedViewport({required this.controller, required this.child});

  final FoldableDevToolsController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final viewport = controller.viewport;
    if (viewport == null) return child;

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(
          math.min(viewport.size.width, constraints.maxWidth),
          math.min(viewport.size.height, constraints.maxHeight),
        );
        return Center(
          child: DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
            ),
            child: ClipRect(
              child: SizedBox(
                width: size.width,
                height: size.height,
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(size: size),
                  child: Stack(
                    children: [
                      Positioned.fill(child: child),
                      if (controller.showHinge)
                        Positioned(
                          left:
                              size.width * controller.hingePosition -
                              controller.hingeThickness / 2,
                          top: 0,
                          bottom: 0,
                          width: controller.hingeThickness,
                          child: IgnorePointer(
                            child: ColoredBox(
                              color: Colors.black.withValues(alpha: 0.35),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OpenButton extends StatelessWidget {
  const _OpenButton({required this.controller});

  final FoldableDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      heroTag: null,
      tooltip: 'Foldable dev tools',
      onPressed: () => controller.isOpen = !controller.isOpen,
      child: const Icon(Icons.bug_report),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.controller});

  final FoldableDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      color: theme.colorScheme.surfaceContainerLowest,
      child: SafeArea(
        left: false,
        child: SizedBox(
          width: 300,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Foldable dev tools',
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close),
                      onPressed: () => controller.isOpen = false,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _Section(
                      title: 'Viewport',
                      child: _ViewportControls(controller: controller),
                    ),
                    _Section(
                      title: 'Hinge',
                      child: _HingeControls(controller: controller),
                    ),
                    _Section(
                      title: 'Motion',
                      child: SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Slow motion'),
                        value: controller.slowMotion,
                        onChanged: (value) => controller.slowMotion = value,
                      ),
                    ),
                    _Section(
                      title: 'Panes',
                      child: _PaneReport(controller: controller),
                    ),
                    _Section(
                      title: 'Navigation',
                      trailing: TextButton(
                        onPressed: controller.clearEvents,
                        child: const Text('Clear'),
                      ),
                      child: _NavigationLog(controller: controller),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}

class _ViewportControls extends StatelessWidget {
  const _ViewportControls({required this.controller});

  final FoldableDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    final viewport = controller.viewport;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final preset in FoldableViewport.presets)
              ChoiceChip(
                label: Text(preset.name),
                selected: viewport?.name == preset.name,
                onSelected: (_) => controller.viewport =
                    viewport?.name == preset.name ? null : preset,
              ),
            ChoiceChip(
              label: const Text('Fit window'),
              selected: viewport == null,
              onSelected: (_) => controller.viewport = null,
            ),
          ],
        ),
        if (viewport != null) ...[
          const SizedBox(height: 12),
          Text(
            '${viewport.size.width.round()} × '
            '${viewport.size.height.round()}',
          ),
          _NumberSlider(
            label: 'Width',
            value: viewport.size.width,
            min: 280,
            max: 1600,
            onChanged: (value) =>
                controller.setViewportSize(Size(value, viewport.size.height)),
          ),
          _NumberSlider(
            label: 'Height',
            value: viewport.size.height,
            min: 400,
            max: 1400,
            onChanged: (value) =>
                controller.setViewportSize(Size(viewport.size.width, value)),
          ),
        ],
      ],
    );
  }
}

class _HingeControls extends StatelessWidget {
  const _HingeControls({required this.controller});

  final FoldableDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Show hinge'),
          value: controller.showHinge,
          onChanged: controller.viewport == null
              ? null
              : (value) => controller.showHinge = value,
        ),
        if (controller.showHinge)
          _NumberSlider(
            label: 'Position',
            value: controller.hingePosition * 100,
            min: 0,
            max: 100,
            suffix: '%',
            onChanged: (value) => controller.hingePosition = value / 100,
          ),
      ],
    );
  }
}

class _PaneReport extends StatelessWidget {
  const _PaneReport({required this.controller});

  final FoldableDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    final pane = controller.pane;
    if (pane == null) {
      return const Text(
        'Add FoldablePaneLayoutObserver inside the scaffold to see its panes.',
      );
    }
    final mode = switch ((pane.primaryVisible, pane.secondaryVisible)) {
      (true, true) => 'Split',
      (true, false) => 'Single, body',
      (false, true) => 'Single, secondary',
      (false, false) => 'None',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mode: $mode'),
        Text('Body: ${pane.primaryVisible ? 'shown' : 'hidden'}'),
        Text('Secondary: ${pane.secondaryVisible ? 'shown' : 'hidden'}'),
        Text('Can split: ${pane.canSplit ? 'yes' : 'no'}'),
        Text('Size: ${pane.width.round()} × ${pane.height.round()}'),
      ],
    );
  }
}

class _NavigationLog extends StatelessWidget {
  const _NavigationLog({required this.controller});

  final FoldableDevToolsController controller;

  @override
  Widget build(BuildContext context) {
    final events = controller.events.reversed.take(8).toList();
    if (events.isEmpty) return const Text('No navigation yet.');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final event in events)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              '${event.kind.name} ${event.uri} '
              '(branch ${event.branch}, ${event.depth} pages)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}

class _NumberSlider extends StatelessWidget {
  const _NumberSlider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.suffix = '',
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String suffix;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 64, child: Text(label)),
        Expanded(
          child: Slider(
            value: value.clamp(min, max),
            min: min,
            max: max,
            onChanged: onChanged,
          ),
        ),
        SizedBox(
          width: 48,
          child: Text('${value.round()}$suffix', textAlign: TextAlign.end),
        ),
      ],
    );
  }
}
