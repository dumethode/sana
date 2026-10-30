import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/utils/failure.dart';
import '../models/incident.dart';

enum ListStatus { loading, ready, failure }

class IncidentListState extends Equatable {
  const IncidentListState({this.status = ListStatus.loading, this.items = const [], this.message});

  final ListStatus status;
  final List<Incident> items;
  final String? message;

  /// True when at least one item has a write that has not reached the server.
  bool get hasPendingWrites => items.any((i) => i.hasPendingWrites);

  Incident? byId(String id) {
    for (final i in items) {
      if (i.id == id) return i;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, items, message];
}

sealed class IncidentListEvent {
  const IncidentListEvent();
}

/// Subscribe (or re-subscribe after an error).
final class IncidentListSubscriptionRequested extends IncidentListEvent {
  const IncidentListSubscriptionRequested();
}

/// Keeps one live Firestore stream of incidents and exposes it as state.
///
/// One instance for the campus feed and one for "My reports" are created at
/// the shell level, above the tab pages, so every screen that shows an
/// incident reads the same state: when staff change a status, the feed card,
/// the student's tracker, the staff queue and the stats all update from one
/// snapshot without any manual refresh.
class IncidentListBloc extends Bloc<IncidentListEvent, IncidentListState> {
  IncidentListBloc(this._source) : super(const IncidentListState()) {
    // restartable: a Retry cancels the failed subscription before starting anew.
    on<IncidentListSubscriptionRequested>(_onSubscribe, transformer: restartable());
  }

  final Stream<List<Incident>> Function() _source;

  Future<void> _onSubscribe(IncidentListSubscriptionRequested event, Emitter<IncidentListState> emit) async {
    if (state.status == ListStatus.failure) {
      emit(IncidentListState(items: state.items));
    }
    await emit.forEach<List<Incident>>(
      _source(),
      onData: (items) => IncidentListState(status: ListStatus.ready, items: items),
      onError: (e, _) => IncidentListState(
        status: ListStatus.failure,
        items: state.items,
        message: Failure.from(e).message,
      ),
    );
  }
}
