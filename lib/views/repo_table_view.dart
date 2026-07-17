import 'package:flutter/material.dart';

import '../activity_service.dart';
import 'views_common.dart';

/// A dense, sortable table of every repo and its metrics. Tap a column header
/// to sort; tap a row to open the repo.
class RepoTableView extends StatefulWidget {
  const RepoTableView({super.key, required this.data});

  final InsightsData data;

  @override
  State<RepoTableView> createState() => _RepoTableViewState();
}

class _RepoTableViewState extends State<RepoTableView> {
  int _sortColumn = 6; // activity score
  bool _ascending = false;

  int _cmp<T extends Comparable<Object?>>(T a, T b) => a.compareTo(b);

  @override
  Widget build(BuildContext context) {
    final repos = [...widget.data.healthy];
    final now = DateTime.now();

    int compare(RepoActivity a, RepoActivity b) {
      final r = switch (_sortColumn) {
        0 => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()),
        1 => _cmp(a.openPrCount, b.openPrCount),
        2 => _cmp(a.needsReviewCount, b.needsReviewCount),
        3 => _cmp(a.oldestOpenPrAgeDays ?? -1, b.oldestOpenPrAgeDays ?? -1),
        4 => a.ciStatus.compareTo(b.ciStatus),
        5 => _cmp(
          daysSince(a.lastActivity, now: now) ?? 1 << 30,
          daysSince(b.lastActivity, now: now) ?? 1 << 30,
        ),
        _ => _cmp(a.activityScore, b.activityScore),
      };
      return _ascending ? r : -r;
    }

    repos.sort(compare);

    return ViewScaffold(
      title: 'Repo table',
      loadedAt: widget.data.loadedAt,
      child: repos.isEmpty
          ? const ViewEmpty(message: 'No repositories to tabulate.')
          : SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  sortColumnIndex: _sortColumn,
                  sortAscending: _ascending,
                  columnSpacing: 20,
                  columns: [
                    _col('Repo'),
                    _col('Open', numeric: true),
                    _col('Review', numeric: true),
                    _col('Oldest', numeric: true),
                    _col('CI'),
                    _col('Last', numeric: true),
                    _col('Score', numeric: true),
                  ],
                  rows: [
                    for (final a in repos)
                      DataRow(
                        onSelectChanged: (_) => openUrl(a.url),
                        cells: [
                          DataCell(
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 200),
                              child: Text(
                                a.displayName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(Text('${a.openPrCount}')),
                          DataCell(Text('${a.needsReviewCount}')),
                          DataCell(
                            Text(
                              a.oldestOpenPrAgeDays == null
                                  ? '—'
                                  : '${a.oldestOpenPrAgeDays}d',
                            ),
                          ),
                          DataCell(
                            Icon(
                              ciIcon(a.ciStatus),
                              size: 16,
                              color: ciColor(a.ciStatus),
                            ),
                          ),
                          DataCell(
                            Text(
                              daysSince(a.lastActivity, now: now) == null
                                  ? '—'
                                  : '${daysSince(a.lastActivity, now: now)}d',
                            ),
                          ),
                          DataCell(Text(a.activityScore.toStringAsFixed(1))),
                        ],
                      ),
                  ],
                ),
              ),
            ),
    );
  }

  DataColumn _col(String label, {bool numeric = false}) {
    return DataColumn(
      label: Text(label),
      numeric: numeric,
      onSort: (index, ascending) => setState(() {
        _sortColumn = index;
        _ascending = ascending;
      }),
    );
  }
}
