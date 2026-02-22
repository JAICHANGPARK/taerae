# Taerae PRD Backup (2026-02-22)

## 1. 문서 메타

- 문서명: `Taerae PRD Backup`
- 작성일: 2026-02-22
- 목적: 현재 구현 상태를 제품/개발 기준으로 백업하고, 이후 릴리즈 및 확장 작업의 기준선으로 사용
- 범위: `taerae_core`, `flutter_taerae`, 예제 프로젝트, 문서 체계

## 2. 제품 정의

### 2.1 제품명
- `Taerae (타래)`

### 2.2 한 줄 정의
- 외부 GraphDB 서버 없이 앱 내부에서 동작하는 경량 임베디드 GraphDB (Dart/Flutter 중심)

### 2.3 해결하려는 문제
- 모바일/데스크톱/온디바이스 환경에서 GraphDB를 쓰려면 보통 외부 서버(예: Neo4j) 의존이 필요함
- 오프라인/온디바이스 AI/GraphRAG 시나리오에서는 로컬 우선 그래프 엔진이 필요함

### 2.4 핵심 가치
- Local-first
- Embedded-first
- Flutter 친화적 상태관리
- GraphRAG 확장 가능 구조

### 2.5 차별점 (기존 GraphDB 대비)
- 별도 GraphDB 서버 없이 앱 내부에서 그래프 기능 사용 가능
- 오프라인 환경에서도 그래프 탐색/조회 로직 유지 가능
- Flutter UI 상태와 바로 연결되는 컨트롤러 패턴 제공
- WAL + snapshot 기반 내구성 전략을 앱 특성에 맞게 조정 가능
- 온디바이스 AI/GraphRAG 확장 포인트를 초기 구조에 포함

### 2.6 사용자 어필 포인트 (Awesome Points)
- `No Neo4j required`
- `Import and use`
- `Offline-ready graph queries`
- `Flutter-native graph state management`
- `GraphRAG-ready architecture`
- `Lower infra and operations burden`

## 3. 목표와 비목표

### 3.1 목표 (현재 스코프)
- Dart 코어 그래프 엔진 제공
- 파일 기반 영속성(WAL + snapshot) 제공
- Flutter에서 바로 쓰기 좋은 컨트롤러 제공
- GraphRAG 확장 인터페이스 제공
- 실전 예제 프로젝트 다수 제공
- pub.dev 배포 준비 가능한 문서/메타데이터 기반 구축

### 3.2 비목표 (현재 시점)
- 분산 클러스터/복제/샤딩
- Cypher 호환 쿼리 언어 엔진
- 대규모 멀티노드 트랜잭션 매니저

## 4. 아키텍처 개요

### 4.1 패키지 구조
- `packages/taerae_core`: 순수 Dart 그래프 엔진/영속성/GraphRAG
- `packages/flutter_taerae`: Flutter 패키지 + `ChangeNotifier` 컨트롤러 + 코어 re-export
- `examples/`: 독립 실행 예제 모음

### 4.2 레이어 모델
- UI Layer (Flutter Widgets)
- Controller Layer (`TaeraeGraphController`)
- Core Graph Layer (`TaeraeGraph`, `TaeraeNode`, `TaeraeEdge`)
- Persistence Layer (`TaeraePersistentGraph`, log/snapshot)
- Retrieval Layer (`TaeraeGraphRag`, embedder/index/chunker/filter/reranker)

## 5. 구현 현황 (완료)

### 5.1 Core Graph 엔진
- 노드/엣지 불변 모델
- 노드/엣지 upsert/remove
- 레이블/프로퍼티 인덱스 조회
- outgoing/incoming/neighbors 탐색
- BFS shortest path
- copy/clear/toJson/fromJson

### 5.2 Persistence
- append-only NDJSON log
- snapshot 저장/복원
- `TaeraePersistentGraph` 통합 래퍼
- 자동 체크포인트(`autoCheckpointEvery`)
- 내구성 옵션
- `TaeraeLogFlushPolicy`: `immediate`, `everyNOperations`, `onCheckpoint`
- `TaeraeWriteAtomicityPolicy`: `writeAhead`, `inMemoryFirst`
- atomic snapshot write 옵션 지원

### 5.3 GraphRAG 확장
- `TaeraeTextEmbedder` 인터페이스
- `TaeraeVectorIndex` 인터페이스
- `TaeraeInMemoryVectorIndex` 구현
- `TaeraeGraphRag` 검색 파이프라인
- 텍스트 청킹(`TaeraeTextChunker`, `TaeraeFixedSizeTextChunker`)
- 메타데이터 필터(`TaeraeGraphRagFilter`)
- 리랭커 훅(`TaeraeGraphReranker`)

### 5.4 Flutter 패키지
- `TaeraeGraphController` 제공 (`ChangeNotifier`)
- 컨트롤러 기반 CRUD/탐색/경로/JSON import-export
- `TaeraeFlutter.getPlatformVersion()` 유지
- `taerae_core` API re-export

### 5.5 실전 예제 프로젝트
- `examples/basic_graph_queries`
- `examples/persistent_graph_store`
- `examples/graphrag_playground`
- `examples/real_life_city_commute`
- `examples/real_life_delivery_ops`
- `examples/real_life_personal_notes_rag`
- `examples/real_life_social_recommendation`

## 6. API 제공 범위 요약

### 6.1 Flutter 전용
- `TaeraeFlutter`
- `TaeraeGraphController`

### 6.2 Re-export된 Core
- Graph 모델/엔진: `TaeraeNode`, `TaeraeEdge`, `TaeraeGraph`
- Persistence: `TaeraePersistentGraph`, `TaeraeDurabilityOptions`, `TaeraeGraphLog`, `TaeraeGraphSnapshotStore` 등
- GraphRAG: `TaeraeGraphRag`, `TaeraeTextEmbedder`, `TaeraeVectorIndex`, `TaeraeGraphRagFilter`, `TaeraeGraphReranker` 등

### 6.3 상세 레퍼런스 문서
- `packages/flutter_taerae/API_REFERENCE.md`

## 7. 문서 체계

- 루트 문서: `README.md`
- 문서 인덱스: `DEVELOPER_DOCS.md`
- 코어 상세 가이드: `packages/taerae_core/DEVELOPER_GUIDE.md`
- 플러그인 상세 가이드: `packages/flutter_taerae/DEVELOPER_GUIDE.md`
- 플러그인 API 레퍼런스: `packages/flutter_taerae/API_REFERENCE.md`
- 예제 인덱스: `examples/README.md`

## 8. 품질 검증 상태

### 8.1 정적 분석/테스트
- `taerae_core`: `dart analyze`, `dart test` 통과
- `flutter_taerae`: `flutter analyze`, `flutter test` 통과

### 8.2 예제 실행 검증
- 실전 예제 포함 다수 `dart run` 실행 검증 완료

## 9. 배포 전략 (pub.dev)

1. `taerae_core` 먼저 배포
2. `flutter_taerae`에서 core 의존성 버전 고정/반영
3. `flutter_taerae` 배포

## 10. 향후 로드맵 (제안)

### 10.1 단기
- pub.dev 실제 배포 파이프라인 정리
- 버전 정책/호환성 정책 문서화
- CI에서 example smoke test 자동화

### 10.2 중기
- 온디바이스 저장소 백엔드 옵션 확대
- GraphRAG 고급 검색/리랭킹 전략 확장
- 성능 벤치마크 및 튜닝 가이드 확장

### 10.3 장기
- 온디바이스 AI 통합 시나리오 강화
- GraphRAG 실서비스 템플릿 제공

## 11. 리스크 및 대응

- 리스크: 파일 손상/비정상 종료 시 데이터 정합성 이슈
- 대응: `writeAhead` + `atomicSnapshotWrite` + 주기적 `checkpoint` 권장

- 리스크: 대규모 그래프에서 메모리 사용량 증가
- 대응: 운영 가이드에 인덱스 사용/체크포인트/조회 범위 제한 포함

- 리스크: 임베딩 차원 불일치로 GraphRAG 실패
- 대응: 인덱스 래퍼에서 차원 검증, 테스트 케이스 유지

## 12. 결정 기록 (요약)

- 서버 의존 없는 embedded 방향 유지
- Flutter 친화 상태관리를 위해 컨트롤러 패턴 채택
- 영속성은 WAL + snapshot 조합으로 단순하고 강건하게 구성
- GraphRAG는 인터페이스 중심으로 확장성 확보

## 13. 현재 기준선(Baseline)

- 날짜 기준선: 2026-02-22
- 문서 기준선: 본 파일 + `DEVELOPER_DOCS.md`
- 코드 기준선: `taerae/` 현재 워크스페이스 상태

## 14. 연계 문서

- MVP 체크리스트: `MVP_CHECKLIST_2026-02-22.md`
- 릴리즈 노트 초안: `RELEASE_NOTES_DRAFT_v0.1.0.md`
