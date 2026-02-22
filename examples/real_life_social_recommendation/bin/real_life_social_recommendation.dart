import 'package:taerae/taerae.dart';

void main() {
  final TaeraeGraph social = TaeraeGraph()
    ..upsertNode('jina', labels: const <String>['User'])
    ..upsertNode('mike', labels: const <String>['User'])
    ..upsertNode('sora', labels: const <String>['User'])
    ..upsertNode('leo', labels: const <String>['User'])
    ..upsertNode('nina', labels: const <String>['User'])
    ..upsertNode('h_flutter', labels: const <String>['Interest'])
    ..upsertNode('h_graph', labels: const <String>['Interest'])
    ..upsertNode('h_cooking', labels: const <String>['Interest'])
    ..upsertEdge('f1', 'jina', 'mike', type: 'FOLLOWS')
    ..upsertEdge('f2', 'mike', 'sora', type: 'FOLLOWS')
    ..upsertEdge('f3', 'sora', 'leo', type: 'FOLLOWS')
    ..upsertEdge('f4', 'mike', 'nina', type: 'FOLLOWS')
    ..upsertEdge('i1', 'jina', 'h_flutter', type: 'HAS_INTEREST')
    ..upsertEdge('i2', 'jina', 'h_graph', type: 'HAS_INTEREST')
    ..upsertEdge('i3', 'sora', 'h_flutter', type: 'HAS_INTEREST')
    ..upsertEdge('i4', 'leo', 'h_graph', type: 'HAS_INTEREST')
    ..upsertEdge('i5', 'nina', 'h_cooking', type: 'HAS_INTEREST')
    ..upsertEdge('i6', 'nina', 'h_flutter', type: 'HAS_INTEREST');

  final List<_Recommendation> recommendations = _recommendUsers(
    graph: social,
    userId: 'jina',
  );

  for (final _Recommendation recommendation in recommendations) {
    print(
      'Recommend ${recommendation.userId} '
      '(score=${recommendation.score}, '
      'mutual=${recommendation.mutualConnections}, '
      'sharedInterests=${recommendation.sharedInterests})',
    );
  }
}

List<_Recommendation> _recommendUsers({
  required TaeraeGraph graph,
  required String userId,
}) {
  final Set<String> alreadyFollowing = graph
      .outgoing(userId, type: 'FOLLOWS')
      .map((TaeraeEdge edge) => edge.to)
      .toSet();
  final Set<String> myInterests = graph
      .outgoing(userId, type: 'HAS_INTEREST')
      .map((TaeraeEdge edge) => edge.to)
      .toSet();

  final Map<String, _Recommendation> scoreByUser = <String, _Recommendation>{};

  for (final TaeraeEdge friendEdge in graph.outgoing(userId, type: 'FOLLOWS')) {
    final String friendId = friendEdge.to;
    for (final TaeraeEdge twoHop in graph.outgoing(friendId, type: 'FOLLOWS')) {
      final String candidateId = twoHop.to;
      if (candidateId == userId || alreadyFollowing.contains(candidateId)) {
        continue;
      }
      if (!(graph.nodeById(candidateId)?.labels.contains('User') ?? false)) {
        continue;
      }

      final Set<String> candidateInterests = graph
          .outgoing(candidateId, type: 'HAS_INTEREST')
          .map((TaeraeEdge edge) => edge.to)
          .toSet();
      final int sharedInterests = candidateInterests
          .intersection(myInterests)
          .length;

      final _Recommendation current =
          scoreByUser[candidateId] ??
          _Recommendation(
            userId: candidateId,
            score: 0,
            mutualConnections: 0,
            sharedInterests: sharedInterests,
          );

      scoreByUser[candidateId] = _Recommendation(
        userId: candidateId,
        score: current.score + 2 + sharedInterests,
        mutualConnections: current.mutualConnections + 1,
        sharedInterests: sharedInterests,
      );
    }
  }

  final List<_Recommendation> sorted = scoreByUser.values.toList(growable: true)
    ..sort((_Recommendation a, _Recommendation b) {
      final int scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) {
        return scoreCompare;
      }
      return a.userId.compareTo(b.userId);
    });
  return sorted;
}

class _Recommendation {
  const _Recommendation({
    required this.userId,
    required this.score,
    required this.mutualConnections,
    required this.sharedInterests,
  });

  final String userId;
  final int score;
  final int mutualConnections;
  final int sharedInterests;
}
