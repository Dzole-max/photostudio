import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/l10n.dart';
import '../../design/design.dart';
import '../../domain/model/album.dart';
import '../../router/app_router.dart';
import 'creation_controller.dart';

enum StoryField { names, date, place, title, moment, tone }

class StoryQuestion {
  const StoryQuestion(this.field, this.prompt, {this.hint});

  final StoryField field;
  final String prompt;
  final String? hint;
}

List<StoryQuestion> questionsFor(Occasion o, AppLocalizations l) => switch (o) {
  Occasion.wedding => [
    StoryQuestion(
      StoryField.names,
      l.storyNamesWedding,
      hint: l.storyNamesWeddingHint,
    ),
    StoryQuestion(StoryField.date, l.storyWhenWedding),
    StoryQuestion(StoryField.place, l.storyWhere, hint: l.storyWhereHint),
    StoryQuestion(
      StoryField.moment,
      l.storyMomentWedding,
      hint: l.storyMomentHint,
    ),
    StoryQuestion(StoryField.tone, l.storyTone),
  ],
  Occasion.travel => [
    StoryQuestion(
      StoryField.names,
      l.storyWhoTravelled,
      hint: l.storyWhoTravelledHint,
    ),
    StoryQuestion(StoryField.title, l.storyTripName),
    StoryQuestion(
      StoryField.moment,
      l.storyMomentTravel,
      hint: l.storyMomentHint,
    ),
    StoryQuestion(StoryField.tone, l.storyTone),
  ],
  Occasion.baby => [
    StoryQuestion(StoryField.names, l.storyBabyName),
    StoryQuestion(StoryField.date, l.storyKeyDate),
    StoryQuestion(
      StoryField.moment,
      l.storyMomentTravel,
      hint: l.storyMomentHint,
    ),
    StoryQuestion(StoryField.tone, l.storyTone),
  ],
  Occasion.birthday => [
    StoryQuestion(StoryField.names, l.storyBirthdayName),
    StoryQuestion(StoryField.date, l.storyKeyDate),
    StoryQuestion(
      StoryField.moment,
      l.storyMomentTravel,
      hint: l.storyMomentHint,
    ),
    StoryQuestion(StoryField.tone, l.storyTone),
  ],
  Occasion.family || Occasion.other => [
    StoryQuestion(StoryField.names, l.storyWhoseBook),
    StoryQuestion(StoryField.title, l.storyBookTitle),
    StoryQuestion(
      StoryField.moment,
      l.storyMomentTravel,
      hint: l.storyMomentHint,
    ),
    StoryQuestion(StoryField.tone, l.storyTone),
  ],
};

String toneLabel(AppLocalizations l, Tone t) => switch (t) {
  Tone.warm => l.toneWarm,
  Tone.poetic => l.tonePoetic,
  Tone.playful => l.tonePlayful,
  Tone.minimal => l.toneMinimal,
};

String toneExample(AppLocalizations l, Tone t) => switch (t) {
  Tone.warm => l.toneExampleWarm,
  Tone.poetic => l.toneExamplePoetic,
  Tone.playful => l.toneExamplePlayful,
  Tone.minimal => l.toneExampleMinimal,
};

class StoryScreen extends ConsumerStatefulWidget {
  const StoryScreen({required this.step, super.key});

  final int step;

  @override
  ConsumerState<StoryScreen> createState() => _StoryScreenState();
}

class _StoryScreenState extends ConsumerState<StoryScreen> {
  late final TextEditingController _text;

  StoryAnswers get _story => ref.read(creationControllerProvider).story;

  @override
  void initState() {
    super.initState();
    _text = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final q = _question();
    if (q != null && _text.text.isEmpty) _text.text = _valueOf(q.field) ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  StoryQuestion? _question() {
    final occasion =
        ref.read(creationControllerProvider).occasion ?? Occasion.other;
    final qs = questionsFor(occasion, context.l10n);
    return widget.step < qs.length ? qs[widget.step] : null;
  }

  String? _valueOf(StoryField f) => switch (f) {
    StoryField.names => _story.names,
    StoryField.place => _story.place,
    StoryField.title => _story.title,
    StoryField.moment => _story.moment,
    _ => null,
  };

  void _save(StoryField f) {
    final v = _text.text.trim();
    final value = v.isEmpty ? null : v;
    final s = _story;
    final updated = switch (f) {
      StoryField.names => s.copyWith(names: value),
      StoryField.place => s.copyWith(place: value),
      StoryField.title => s.copyWith(title: value),
      StoryField.moment => s.copyWith(moment: value),
      _ => s,
    };
    ref.read(creationControllerProvider.notifier).updateStory(updated);
  }

  void _next(int total) {
    final q = _question();
    if (q != null) _save(q.field);
    if (widget.step + 1 >= total) {
      context.push(Routes.createCover);
    } else {
      context.push(Routes.createStory(widget.step + 1));
    }
  }

  void _skip(int total) {
    if (widget.step + 1 >= total) {
      context.push(Routes.createCover);
    } else {
      context.push(Routes.createStory(widget.step + 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final t = Theme.of(context).textTheme;
    final c = MemoriaColors.of(context);
    final state = ref.watch(creationControllerProvider);
    final occasion = state.occasion ?? Occasion.other;
    final qs = questionsFor(occasion, l);
    final q = widget.step < qs.length ? qs[widget.step] : qs.last;
    final last = widget.step + 1 >= qs.length;
    final locale = Localizations.localeOf(context).toLanguageTag();

    Widget input;
    switch (q.field) {
      case StoryField.date:
        final date = state.story.eventDate;
        input = MemoriaCard(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(1900),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (picked != null) {
              ref
                  .read(creationControllerProvider.notifier)
                  .updateStory(
                    state.story.copyWith(
                      eventDate: DateTime.utc(
                        picked.year,
                        picked.month,
                        picked.day,
                      ),
                    ),
                  );
            }
          },
          child: Row(
            children: [
              Icon(Icons.event_outlined, color: c.textSecondary),
              const SizedBox(width: Space.sm),
              Expanded(
                child: Text(
                  date == null
                      ? l.storyPickDate
                      : DateFormat.yMMMMd(locale).format(date),
                  style: t.titleMedium,
                ),
              ),
              Icon(Icons.edit_calendar_outlined, color: c.textSecondary),
            ],
          ),
        );
      case StoryField.tone:
        input = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final tone in Tone.values) ...[
              MemoriaCard(
                onTap: () => ref
                    .read(creationControllerProvider.notifier)
                    .updateStory(state.story.copyWith(tone: tone)),
                color: state.story.tone == tone ? c.surfaceRaised : null,
                raised: state.story.tone == tone,
                semanticLabel: toneLabel(l, tone),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(toneLabel(l, tone), style: t.titleSmall),
                          const SizedBox(height: Space.xxs),
                          Text(
                            toneExample(l, tone),
                            style: t.bodySmall?.copyWith(
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      state.story.tone == tone
                          ? Icons.radio_button_checked_rounded
                          : Icons.radio_button_unchecked_rounded,
                      color: state.story.tone == tone
                          ? c.textPrimary
                          : c.textSecondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Space.xs),
            ],
          ],
        );
      default:
        input = TextField(
          controller: _text,
          autofocus: true,
          style: t.titleMedium,
          minLines: q.field == StoryField.moment ? 3 : 1,
          maxLines: q.field == StoryField.moment ? 5 : 1,
          maxLength: q.field == StoryField.moment ? 200 : 80,
          textCapitalization: TextCapitalization.sentences,
          textInputAction: q.field == StoryField.moment
              ? TextInputAction.newline
              : TextInputAction.next,
          decoration: InputDecoration(hintText: q.hint),
          onSubmitted: (_) => _next(qs.length),
        );
    }

    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          liveRegion: true,
          child: Text(
            l.storyStep(widget.step + 1, qs.length),
            style: t.labelMedium,
          ),
        ),
        actions: [
          if (!last)
            TextButton(
              onPressed: () => _skip(qs.length),
              child: Text(l.commonSkip),
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(Space.lg),
                children: [
                  Text(q.prompt, style: t.displaySmall),
                  const SizedBox(height: Space.xs),
                  Text(l.storyOptional, style: t.bodySmall),
                  const SizedBox(height: Space.lg),
                  input,
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.lg,
                0,
                Space.lg,
                Space.md,
              ),
              child: PrimaryButton(
                label: last ? l.storyDesign : l.commonContinue,
                icon: last ? Icons.auto_stories_outlined : null,
                onPressed: () => _next(qs.length),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
