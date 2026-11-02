part of 'critical_alarm_screen.dart';

extension _AcknowledgedLayouts on AcknowledgedScreen {
  /// A phone on its side, or a tablet: the face beside the words.
  Widget _wideLayout(
    BuildContext context, {
    required AlarmAcknowledgedLook look,
    required Widget bottomBar,
    required FaceState faceState,
    required String ackedSub,
    required String startedLabel,
    required String ackedLabel,
    required bool hintInList,
    required bool isClosed,
    required bool pinsHint,
  }) {
    // The row sits in the middle of the room above the pinned buttons,
    // and scrolls when it is taller than that room. It is laid out at
    // its own height: a sliver that fills what is left of the screen
    // asks its child how tall it would like to be, and the title and
    // the rows of the card cannot answer that (each is built by a
    // LayoutBuilder), so the whole body went undrawn.
    final wideMedia = MediaQuery.of(context);
    final wideScale = wideMedia.textScaler.scale(16) / 16;
    // A guess at the pinned block. A wrong one only moves the row off
    // the middle or lets the page scroll a little: the scaffold
    // measures the real block for the room it leaves under the list.
    final wideRoom = math
        .max(
          0,
          wideMedia.size.height -
              wideMedia.padding.vertical -
              ringingBarHeightFor(
                textScale: wideScale,
                pinnedButtons: isClosed ? 1 : 2,
              ) -
              (!isClosed && pinsHint ? 24 * wideScale + Spacing.s3 : 0) -
              ringingBarClearance,
        )
        .toDouble();
    return AppScreenScaffold(
      hasTabBar: false,
      slivers: [
        SliverToBoxAdapter(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: wideRoom),
            child: Row(
              children: [
                Hero(
                  tag: 'alarm-face-${state.incident?.id}',
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(
                    state: faceState,
                    // On a phone on its side the face gives way to the
                    // room there is.
                    size: math.min(
                      math.min<double>(260, look.maxFace),
                      math.max(AcknowledgedScreen._minFace, wideRoom),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
                Expanded(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _title(look, TextAlign.left),
                        // The topic's tap box is 48 high, not 44: 2 less on
                        // each side of it.
                        const SizedBox(height: Spacing.s2 - 2),
                        _topic(context),
                        const SizedBox(height: Spacing.s2 - 2),
                        _sub(look, TextAlign.left, ackedSub),
                        const SizedBox(height: Spacing.s4),
                        _detailSheet(startedLabel, ackedLabel),
                        if (hintInList) ...[
                          const SizedBox(height: Spacing.s4),
                          _sub(
                            look,
                            TextAlign.left,
                            _deskTimerHint(context),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      bottomBar: bottomBar,
      barBacking: colors.canvas,
    );
  }

  /// An upright phone: the face over the words, the card under them.
  Widget _portraitLayout(
    BuildContext context, {
    required AlarmAcknowledgedLook look,
    required Widget bottomBar,
    required FaceState faceState,
    required double textScale,
    required String ackedSub,
    required String startedLabel,
    required String ackedLabel,
    required bool hintInList,
  }) {
    // The face takes what the rest leaves. Everything else on the screen
    // has a size of its own (title, pill, line, the three-row card, the
    // hint and the two buttons, about [_restHeight] at the default text
    // size, of which [_restTextHeight] is text that grows with the text
    // size), so on a short phone the face shrinks until the whole card
    // sits above the pinned buttons with nothing hidden at rest. At a large
    // text size the list scrolls, and the room the scaffold leaves under
    // it is the height of the backing, so the card always scrolls clear.
    final media = MediaQuery.of(context);
    // The room decides the face. A look may only cap it.
    final faceSize = math.min(
      (media.size.height -
              media.padding.vertical -
              AcknowledgedScreen._restHeight -
              AcknowledgedScreen._restTextHeight * math.max(0, textScale - 1))
          .clamp(AcknowledgedScreen._minFace, 224.0),
      look.maxFace,
    );

    return AppScreenScaffold(
      hasTabBar: false,
      // The list scrolls under the pinned hint and buttons at a large text
      // size or on a short phone. A solid backing in the canvas colour
      // keeps the card from showing through them.
      barBacking: colors.canvas,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, Spacing.s5, 20, 0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Hero(
                  tag: 'alarm-face-${state.incident?.id}',
                  flightShuttleBuilder: faceFlightShuttleBuilder,
                  child: FaceWidget(
                    state: faceState,
                    size: faceSize,
                  ),
                ),
                const SizedBox(height: Spacing.s4),
                _title(look, TextAlign.center),
                // The topic's tap box is 48 high, not 44: 2 less on each side
                // of it.
                const SizedBox(height: Spacing.s2 - 2),
                _topic(context),
                const SizedBox(height: Spacing.s2 - 2),
                _sub(look, TextAlign.center, ackedSub),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, Spacing.s4, 16, 0),
            child: _detailSheet(startedLabel, ackedLabel),
          ),
        ),
        if (hintInList)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, Spacing.s4, 20, 0),
              child: _sub(look, TextAlign.center, _deskTimerHint(context)),
            ),
          ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// A half-open foldable. The face, title, topic and ring time hold still
  /// in the start pane (book) or the top half (tabletop). The card and the
  /// pinned buttons go in the other pane, so nothing sits on the fold.
  Widget _folded(
    BuildContext context,
    AppFold fold,
    AlarmAcknowledgedLook look,
    Widget bottomBar, {
    required String ackedSub,
    required String startedLabel,
    required String ackedLabel,
    required bool hintInList,
    required bool isClosed,
  }) {
    final face = Hero(
      tag: 'alarm-face-${state.incident?.id}',
      flightShuttleBuilder: faceFlightShuttleBuilder,
      child: FaceWidget(
        state: state.faceState,
        size: math.min(fold.isBook ? 200 : 120, look.maxFace),
      ),
    );
    Widget lines(TextAlign align) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align == TextAlign.center
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        _title(look, align),
        const SizedBox(height: Spacing.s2 - 2),
        _topic(context),
        const SizedBox(height: Spacing.s2 - 2),
        _sub(look, align, ackedSub),
      ],
    );
    final card = _detailSheet(startedLabel, ackedLabel);
    final hint = _sub(look, TextAlign.center, _deskTimerHint(context));

    if (fold.isTabletop) {
      // A 350 half is too short for the card under the buttons, so the top
      // half holds the face, the lines and the card side by side, and the
      // bottom half holds the hint and the buttons.
      return AppScreenScaffold(
        hasTabBar: false,
        barBacking: colors.canvas,
        foldStage: SafeArea(
          bottom: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: Spacing.s3,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  face,
                  const SizedBox(width: Spacing.s5),
                  Flexible(child: lines(TextAlign.left)),
                  const SizedBox(width: Spacing.s6),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 360),
                      child: card,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        slivers: [
          if (hintInList)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, Spacing.s4, 20, 0),
                child: hint,
              ),
            ),
        ],
        bottomBar: bottomBar,
      );
    }

    // Book: the face and the lines in the start pane. The card and the hint
    // under it sit at the foot of the end pane, right over the buttons. When
    // the two are taller than the room they scroll above the pinned buttons,
    // so the hint is never hidden under them at rest.
    return AppScreenScaffold(
      hasTabBar: false,
      barBacking: colors.canvas,
      foldStage: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                face,
                const SizedBox(height: Spacing.s4),
                lines(TextAlign.center),
              ],
            ),
          ),
        ),
      ),
      slivers: [
        // Built in the end pane, so the room is the pane's: what the pinned
        // buttons leave. The capture run checks nothing scrolls at rest.
        SliverToBoxAdapter(
          child: Builder(
            builder: (context) {
              final media = MediaQuery.of(context);
              final scale = media.textScaler.scale(16) / 16;
              final room = math
                  .max(
                    0,
                    media.size.height -
                        media.padding.vertical -
                        ringingBarHeightFor(
                          textScale: scale,
                          pinnedButtons: isClosed ? 1 : 2,
                        ) -
                        ringingBarClearance -
                        16,
                  )
                  .toDouble();
              return ConstrainedBox(
                constraints: BoxConstraints(minHeight: room),
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        card,
                        if (hintInList)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              4,
                              Spacing.s4,
                              4,
                              0,
                            ),
                            child: hint,
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
      bottomBar: bottomBar,
    );
  }

  /// The test alarm's acknowledged screen: a ripple of happy faces as the
  /// picture, then the welcome title, a line and the way on,
  /// with confetti over all of it. The ripple takes whatever height the text
  /// and button leave. When the words are taller than the room, the ripple
  /// goes and the words scroll above the pinned button.
  Widget _demoBody(
    BuildContext context,
    bool isWide,
    Widget bottomBar, {
    required AckedExits exits,
    required String title,
    required Widget detail,
    required List<FaceState> restFaces,
  }) {
    final ripple = ExcludeSemantics(
      child: IgnorePointer(
        child: FaceRipple(
          faces: happyRippleFaces,
          restFace: FaceState.content,
          restFaces: restFaces,
          randomFaces: true,
        ),
      ),
    );
    Widget copy(TextAlign align, CrossAxisAlignment cross) => ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: cross,
        children: [
          // The type steps down until the longest word fits, so a large text
          // size on a narrow phone never breaks "works" in two.
          AppFittedTitle(
            title,
            textAlign: align,
            minFontSize: setupTitleMinFontSize,
            style: AppTypography.display(colors.onCanvas),
          ),
          const SizedBox(height: Spacing.s4),
          detail,
        ],
      ),
    );
    final bottomGap = MediaQuery.paddingOf(context).bottom + 24;
    final fold = AppFold.of(context);
    final scaffold = !fold.isNone
        // A half-open foldable: the ripple fills the start pane or the top
        // half, the words and the way on go in the other, off the fold.
        ? AppScreenScaffold(
            hasTabBar: false,
            physics: const NeverScrollableScrollPhysics(),
            // The column below carries its own room at the foot, so the list
            // adds none and the pane does not scroll at rest.
            bodyClearsBottomBar: true,
            foldStage: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(Spacing.s5),
                child: ripple,
              ),
            ),
            slivers: [
              SliverFillRemaining(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(24, Spacing.s4, 24, bottomGap),
                  child: _AckedDemoColumn(
                    ripple: const SizedBox.shrink(),
                    copy: _ScrollingCopy(
                      fadeColor: colors.canvas,
                      child: copy(TextAlign.center, CrossAxisAlignment.center),
                    ),
                    bar: bottomBar,
                  ),
                ),
              ),
            ],
          )
        : AppScreenScaffold(
            hasTabBar: false,
            // The column below is sized to the screen, so the list has no
            // room to scroll and no reason to bounce.
            physics: const NeverScrollableScrollPhysics(),
            slivers: [
              SliverFillRemaining(
                child: isWide
                    ? Padding(
                        padding: EdgeInsets.fromLTRB(24, 16, 24, bottomGap),
                        child: Row(
                          children: [
                            Expanded(child: ripple),
                            const SizedBox(width: 40),
                            Expanded(
                              child: Center(
                                child: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 320,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        copy(
                                          TextAlign.left,
                                          CrossAxisAlignment.start,
                                        ),
                                        const SizedBox(height: Spacing.s5),
                                        bottomBar,
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : Padding(
                        padding: EdgeInsets.fromLTRB(
                          24,
                          Spacing.s4,
                          24,
                          bottomGap,
                        ),
                        // The ripple takes what the words and the button
                        // leave. The words scroll when they are taller than
                        // that, and the button stays pinned under them.
                        child: _AckedDemoColumn(
                          ripple: ripple,
                          copy: _ScrollingCopy(
                            fadeColor: colors.canvas,
                            child: copy(
                              TextAlign.center,
                              CrossAxisAlignment.center,
                            ),
                          ),
                          bar: bottomBar,
                        ),
                      ),
              ),
            ],
          );
    return Stack(
      children: [
        scaffold,
        Positioned.fill(
          child: _AckConfettiGate(
            exits: exits,
            colors: colors,
            setupProved: switch (state.setupEvidence) {
              final evidence? => setupTestRang(
                state.setupTest,
                evidence: evidence,
              ),
              null => false,
            },
          ),
        ),
      ],
    );
  }
}
