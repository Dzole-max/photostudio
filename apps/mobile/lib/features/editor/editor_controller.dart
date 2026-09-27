import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../data/albums/album_repository.dart';
import '../../data/domain_kit.dart';
import '../../domain/layout/album_ops.dart';
import '../../domain/model/album.dart';
import '../../domain/preflight/preflight.dart';

part 'editor_controller.g.dart';

/// What the user has tapped on the spread.
sealed class EditorSelection {
  const EditorSelection(this.pageIndex);

  /// Inner page index, or -1 for the front cover.
  final int pageIndex;
}

class FrameSelection extends EditorSelection {
  const FrameSelection(super.pageIndex, this.frameIndex);

  final int frameIndex;
}

class EditorTextSelection extends EditorSelection {
  const EditorTextSelection(super.pageIndex, this.textId);

  final String textId;
}

class PageSelection extends EditorSelection {
  const PageSelection(super.pageIndex);
}

class EditorState {
  const EditorState({
    required this.album,
    required this.report,
    this.undo = const [],
    this.redo = const [],
    this.selection,
    this.swapFrom,
    this.saving = false,
  });

  final Album album;
  final PreflightReport report;
  final List<Album> undo;
  final List<Album> redo;
  final EditorSelection? selection;

  /// First frame picked in "Swap" mode.
  final FrameSelection? swapFrom;
  final bool saving;

  bool get canUndo => undo.isNotEmpty;
  bool get canRedo => redo.isNotEmpty;

  int get issueCount =>
      report.count(Severity.blocker) + report.count(Severity.warning);

  EditorState copyWith({
    Album? album,
    PreflightReport? report,
    List<Album>? undo,
    List<Album>? redo,
    EditorSelection? selection,
    bool clearSelection = false,
    FrameSelection? swapFrom,
    bool clearSwap = false,
    bool? saving,
  }) {
    return EditorState(
      album: album ?? this.album,
      report: report ?? this.report,
      undo: undo ?? this.undo,
      redo: redo ?? this.redo,
      selection: clearSelection ? null : (selection ?? this.selection),
      swapFrom: clearSwap ? null : (swapFrom ?? this.swapFrom),
      saving: saving ?? this.saving,
    );
  }
}

/// Spreads as a real book shows them: the first inner page alone on the
/// right, then pairs (left = odd index, right = even index).
List<(int?, int?)> spreadsOf(int pageCount) {
  final out = <(int?, int?)>[(null, pageCount > 0 ? 0 : null)];
  for (var left = 1; left < pageCount; left += 2) {
    out.add((left, left + 1 < pageCount ? left + 1 : null));
  }
  return out;
}

int spreadOfPage(int pageIndex) => pageIndex == 0 ? 0 : (pageIndex + 1) ~/ 2;

/// Undo history depth (section 8.6).
const int kUndoDepth = 30;

@riverpod
class EditorController extends _$EditorController {
  Timer? _saveTimer;
  late AlbumOps _ops;

  @override
  Future<EditorState> build(String albumId) async {
    // Riverpod forbids reading state in onDispose: keep the latest album.
    Album? latest;
    final repo = ref.read(albumRepositoryProvider);
    listenSelf((_, next) => latest = next.value?.album ?? latest);
    ref.onDispose(() {
      final pending = _saveTimer?.isActive ?? false;
      _saveTimer?.cancel();
      if (pending && latest != null) unawaited(repo.save(latest!));
    });
    final kit = await ref.watch(domainKitProvider.future);
    _ops = kit.ops;
    final album = await ref.read(albumRepositoryProvider).load(albumId);
    if (album == null) throw StateError('album $albumId not found');
    return EditorState(album: album, report: runPreflight(album, kit.fonts));
  }

  AlbumOps get ops => _ops;

  EditorState? get _s => state.value;

  /// Applies an edit, records undo, re-checks print, schedules autosave.
  void apply(
    Album Function(AlbumOps ops, Album album) edit, {
    bool keepSelection = false,
  }) {
    final s = _s;
    if (s == null) return;
    final next = edit(_ops, s.album);
    if (identical(next, s.album)) return;
    final undo = [...s.undo, s.album];
    if (undo.length > kUndoDepth) undo.removeAt(0);
    state = AsyncData(
      s.copyWith(
        album: next,
        undo: undo,
        redo: const [],
        report: runPreflight(next, _ops.fonts),
        clearSelection: !keepSelection,
        clearSwap: true,
      ),
    );
    _scheduleSave();
  }

  void undo() {
    final s = _s;
    if (s == null || s.undo.isEmpty) return;
    final prev = s.undo.last;
    state = AsyncData(
      s.copyWith(
        album: prev,
        undo: s.undo.sublist(0, s.undo.length - 1),
        redo: [...s.redo, s.album],
        report: runPreflight(prev, _ops.fonts),
        clearSelection: true,
      ),
    );
    _scheduleSave();
  }

  void redo() {
    final s = _s;
    if (s == null || s.redo.isEmpty) return;
    final next = s.redo.last;
    state = AsyncData(
      s.copyWith(
        album: next,
        redo: s.redo.sublist(0, s.redo.length - 1),
        undo: [...s.undo, s.album],
        report: runPreflight(next, _ops.fonts),
        clearSelection: true,
      ),
    );
    _scheduleSave();
  }

  void select(EditorSelection? selection) {
    final s = _s;
    if (s == null) return;
    // Second tap in swap mode completes the swap.
    final from = s.swapFrom;
    if (from != null &&
        selection is FrameSelection &&
        selection.pageIndex >= 0) {
      if (from.pageIndex != selection.pageIndex ||
          from.frameIndex != selection.frameIndex) {
        apply(
          (ops, a) => ops.swapPhotos(
            a,
            (from.pageIndex, from.frameIndex),
            (selection.pageIndex, selection.frameIndex),
          ),
        );
        return;
      }
    }
    state = AsyncData(
      s.copyWith(
        selection: selection,
        clearSelection: selection == null,
        clearSwap: true,
      ),
    );
  }

  void startSwap(FrameSelection from) {
    final s = _s;
    if (s == null) return;
    state = AsyncData(s.copyWith(swapFrom: from, clearSelection: true));
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      final s = _s;
      if (s == null) return;
      state = AsyncData(s.copyWith(saving: true));
      await ref.read(albumRepositoryProvider).save(s.album);
      final after = _s;
      if (after != null) state = AsyncData(after.copyWith(saving: false));
    });
  }

  /// Saves immediately (leaving the editor, going to checkout).
  Future<void> flush() async {
    _saveTimer?.cancel();
    final s = _s;
    if (s != null) await ref.read(albumRepositoryProvider).save(s.album);
  }
}
