# Taerae Paper Benchmark Report

## Run Metadata

- Started (UTC): 2026-02-22T11:09:04.381459Z
- Finished (UTC): 2026-02-22T11:10:10.214675Z
- Duration: 65.83s
- Dart: Dart SDK version: 3.11.0 (stable) (Mon Feb 9 00:38:07 2026 -0800) on "macos_arm64"
- Platform: macos (Version 15.7.4 (Build 24G517))
- CPU logical cores: 10

## Config

- Presets: generic, social, delivery, notes_rag
- Sizes: 1000, 5000, 10000
- Warmup runs: 1
- Measured runs: 3
- Base seed: 42

## Artifacts

- JSON: `benchmark/results/arxiv_report_20260222_full/results.json`
- CSV: `benchmark/results/arxiv_report_20260222_full/summary.csv`

## Summary (mean ops/s)

| Preset | Nodes | Metric | Mean ops/s | p50 ops/s | p95 ops/s |
| --- | ---: | --- | ---: | ---: | ---: |
| delivery | 1000 | nodeById | 2056398 | 2042484 | 2088276 |
| delivery | 1000 | nodesByLabel | 83158 | 83049 | 83465 |
| delivery | 1000 | nodesWhereProperty | 281014 | 280466 | 284588 |
| delivery | 1000 | outgoing(ROUTE) | 2655279 | 2644104 | 2718733 |
| delivery | 1000 | pendingPackages | 302958 | 300481 | 308945 |
| delivery | 1000 | shortestPath(ROUTE) | 14916 | 14827 | 15100 |
| delivery | 1000 | upsertEdge | 483899 | 478594 | 494934 |
| delivery | 1000 | upsertNode | 66754 | 66168 | 67871 |
| delivery | 5000 | nodeById | 6746734 | 6635700 | 7138391 |
| delivery | 5000 | nodesByLabel | 17604 | 17535 | 17867 |
| delivery | 5000 | nodesWhereProperty | 53436 | 52055 | 56441 |
| delivery | 5000 | outgoing(ROUTE) | 2861640 | 2865330 | 2908911 |
| delivery | 5000 | pendingPackages | 55828 | 54478 | 58193 |
| delivery | 5000 | shortestPath(ROUTE) | 2858 | 2953 | 3108 |
| delivery | 5000 | upsertEdge | 1143105 | 1134769 | 1190781 |
| delivery | 5000 | upsertNode | 442191 | 446588 | 447271 |
| delivery | 10000 | nodeById | 11339977 | 11428571 | 11463958 |
| delivery | 10000 | nodesByLabel | 8590 | 8588 | 8639 |
| delivery | 10000 | nodesWhereProperty | 28064 | 28093 | 28545 |
| delivery | 10000 | outgoing(ROUTE) | 2482165 | 2306273 | 2832535 |
| delivery | 10000 | pendingPackages | 26981 | 27928 | 29029 |
| delivery | 10000 | shortestPath(ROUTE) | 1392 | 1469 | 1519 |
| delivery | 10000 | upsertEdge | 1706863 | 1704158 | 1718839 |
| delivery | 10000 | upsertNode | 824565 | 843028 | 850913 |
| generic | 1000 | nodeById | 3725981 | 3743916 | 3802963 |
| generic | 1000 | nodesByLabel | 310694 | 313018 | 313425 |
| generic | 1000 | nodesWhereProperty | 3153636 | 3144654 | 3169796 |
| generic | 1000 | outgoing | 2777657 | 2799552 | 2858752 |
| generic | 1000 | shortestPathBfs | 6385 | 6375 | 6435 |
| generic | 1000 | upsertEdge | 476024 | 481522 | 491885 |
| generic | 1000 | upsertNode | 46188 | 47281 | 47551 |
| generic | 5000 | nodeById | 9047390 | 9082652 | 9090083 |
| generic | 5000 | nodesByLabel | 63572 | 63732 | 63887 |
| generic | 5000 | nodesWhereProperty | 1502995 | 1506478 | 1521345 |
| generic | 5000 | outgoing | 2669097 | 2613696 | 2785205 |
| generic | 5000 | shortestPathBfs | 1269 | 1271 | 1273 |
| generic | 5000 | upsertEdge | 1117305 | 1113400 | 1141914 |
| generic | 5000 | upsertNode | 255749 | 262288 | 262425 |
| generic | 10000 | nodeById | 14079242 | 13966480 | 14612507 |
| generic | 10000 | nodesByLabel | 31886 | 32292 | 32944 |
| generic | 10000 | nodesWhereProperty | 847468 | 848104 | 854963 |
| generic | 10000 | outgoing | 2216949 | 2328289 | 2408844 |
| generic | 10000 | shortestPathBfs | 586 | 592 | 596 |
| generic | 10000 | upsertEdge | 1129287 | 1152937 | 1166573 |
| generic | 10000 | upsertNode | 351948 | 353769 | 366332 |
| notes_rag | 1000 | neighbors(RELATED) | 976422 | 1025851 | 1057188 |
| notes_rag | 1000 | nodeById | 2053841 | 2029221 | 2096065 |
| notes_rag | 1000 | nodesByLabel | 61169 | 63232 | 63300 |
| notes_rag | 1000 | nodesWhereProperty | 1285405 | 1295672 | 1295823 |
| notes_rag | 1000 | outgoing(RELATED) | 2686781 | 2700513 | 2750757 |
| notes_rag | 1000 | shortestPath(RELATED) | 8037 | 8224 | 8416 |
| notes_rag | 1000 | upsertEdge | 527294 | 567897 | 586110 |
| notes_rag | 1000 | upsertNode | 62882 | 62212 | 66374 |
| notes_rag | 1000 | urgentFilter | 569741 | 574713 | 583480 |
| notes_rag | 5000 | neighbors(RELATED) | 1075829 | 1121076 | 1139739 |
| notes_rag | 5000 | nodeById | 6012800 | 6195787 | 6459942 |
| notes_rag | 5000 | nodesByLabel | 12126 | 12364 | 12452 |
| notes_rag | 5000 | nodesWhereProperty | 305102 | 308814 | 311754 |
| notes_rag | 5000 | outgoing(RELATED) | 2770787 | 2595380 | 3279673 |
| notes_rag | 5000 | shortestPath(RELATED) | 1692 | 1691 | 1751 |
| notes_rag | 5000 | upsertEdge | 1165578 | 1187151 | 1275266 |
| notes_rag | 5000 | upsertNode | 376718 | 381913 | 418066 |
| notes_rag | 5000 | urgentFilter | 110747 | 112931 | 113694 |
| notes_rag | 10000 | neighbors(RELATED) | 874830 | 823181 | 984303 |
| notes_rag | 10000 | nodeById | 11060564 | 10989011 | 11268393 |
| notes_rag | 10000 | nodesByLabel | 6015 | 5997 | 6080 |
| notes_rag | 10000 | nodesWhereProperty | 151016 | 151904 | 154872 |
| notes_rag | 10000 | outgoing(RELATED) | 2227344 | 2271179 | 2570868 |
| notes_rag | 10000 | shortestPath(RELATED) | 760 | 786 | 821 |
| notes_rag | 10000 | upsertEdge | 1636150 | 1825209 | 1838813 |
| notes_rag | 10000 | upsertNode | 673477 | 667111 | 707554 |
| notes_rag | 10000 | urgentFilter | 53216 | 52989 | 54042 |
| social | 1000 | nodeById | 2060239 | 2110150 | 2144420 |
| social | 1000 | nodesByLabel | 78756 | 78946 | 79019 |
| social | 1000 | nodesWhereProperty | 2916583 | 2961208 | 2961997 |
| social | 1000 | outgoing(FOLLOWS) | 1684524 | 1675884 | 1717442 |
| social | 1000 | shortestPath(FOLLOWS) | 4148 | 4170 | 4171 |
| social | 1000 | twoHopRecommend | 73989 | 74599 | 74699 |
| social | 1000 | upsertEdge | 651526 | 669856 | 682741 |
| social | 1000 | upsertNode | 69599 | 69469 | 70167 |
| social | 5000 | nodeById | 6522060 | 6644518 | 6672462 |
| social | 5000 | nodesByLabel | 15621 | 16399 | 16519 |
| social | 5000 | nodesWhereProperty | 1357437 | 1360174 | 1363513 |
| social | 5000 | outgoing(FOLLOWS) | 1256965 | 1360915 | 1379529 |
| social | 5000 | shortestPath(FOLLOWS) | 674 | 688 | 703 |
| social | 5000 | twoHopRecommend | 67911 | 66885 | 70645 |
| social | 5000 | upsertEdge | 1479535 | 1493047 | 1534773 |
| social | 5000 | upsertNode | 567632 | 569995 | 579648 |
| social | 10000 | nodeById | 11274345 | 11299435 | 12132389 |
| social | 10000 | nodesByLabel | 7711 | 7742 | 7804 |
| social | 10000 | nodesWhereProperty | 767539 | 764468 | 792381 |
| social | 10000 | outgoing(FOLLOWS) | 1031631 | 1041124 | 1056090 |
| social | 10000 | shortestPath(FOLLOWS) | 322 | 319 | 333 |
| social | 10000 | twoHopRecommend | 69571 | 69517 | 70203 |
| social | 10000 | upsertEdge | 1343570 | 1328424 | 1391148 |
| social | 10000 | upsertNode | 845209 | 864006 | 939724 |
