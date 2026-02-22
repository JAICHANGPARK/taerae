# Taerae MVP Checklist (2026-02-22)

## 1. 제품/범위 확정

- [x] 제품명/브랜딩 확정: `Taerae`
- [x] 문제정의 확정: 외부 GraphDB 없이 로컬 임베디드 그래프 사용
- [x] MVP 스코프 확정: core + flutter + persistence + graphrag base + examples
- [ ] v0.1.0 출시 범위 freeze 공지

## 2. 코어 엔진 (`taerae_core`)

- [x] 불변 모델 구현: `TaeraeNode`, `TaeraeEdge`
- [x] 그래프 엔진 구현: `TaeraeGraph`
- [x] CRUD 구현: node/edge upsert/remove
- [x] 탐색 구현: outgoing/incoming/neighbors
- [x] 경로탐색 구현: BFS shortest path
- [x] JSON 직렬화/복원 구현
- [x] 단위 테스트 작성 및 통과
- [ ] 퍼블릭 API 안정성 최종 리뷰

## 3. 영속성 (`taerae_core`)

- [x] append-only log 구현 (`TaeraeGraphLog`)
- [x] snapshot store 구현 (`TaeraeGraphSnapshotStore`)
- [x] 통합 래퍼 구현 (`TaeraePersistentGraph`)
- [x] durability 옵션 구현
  - [x] `TaeraeLogFlushPolicy`
  - [x] `TaeraeWriteAtomicityPolicy`
  - [x] atomic snapshot write
- [x] 복구/체크포인트 테스트 통과
- [ ] 장애 주입(강제 종료) 시나리오 수동 검증

## 4. GraphRAG 확장 (`taerae_core`)

- [x] 임베더 인터페이스 구현: `TaeraeTextEmbedder`
- [x] 벡터 인덱스 인터페이스/기본 구현: `TaeraeVectorIndex`, `TaeraeInMemoryVectorIndex`
- [x] GraphRAG 구현: `TaeraeGraphRag`
- [x] 고급 기능 구현
  - [x] chunker (`TaeraeTextChunker`)
  - [x] metadata filter (`TaeraeGraphRagFilter`)
  - [x] reranker hook (`TaeraeGraphReranker`)
- [x] 관련 테스트 통과
- [ ] 실제 임베딩 모델 연동 샘플 추가

## 5. Flutter 패키지 (`flutter_taerae`)

- [x] `TaeraeGraphController` 구현 (`ChangeNotifier`)
- [x] 컨트롤러 CRUD/조회/JSON API 구현
- [x] `TaeraeFlutter.getPlatformVersion()` 유지
- [x] core API re-export
- [x] 플러그인 단위 테스트 통과
- [ ] Web 환경에서 persistence 사용 제한 가이드 강화

## 6. 예제 프로젝트

- [x] 기본 예제
  - [x] `basic_graph_queries`
  - [x] `persistent_graph_store`
  - [x] `graphrag_playground`
- [x] 실생활 예제
  - [x] `real_life_city_commute`
  - [x] `real_life_delivery_ops`
  - [x] `real_life_personal_notes_rag`
  - [x] `real_life_social_recommendation`
- [x] 예제 실행 검증
- [ ] 예제별 스크린샷/출력 샘플 문서화

## 7. 문서화

- [x] PRD 백업 작성: `PRD_BACKUP_2026-02-22.md`
- [x] 문서 인덱스 작성: `DEVELOPER_DOCS.md`
- [x] 코어 개발 가이드 작성: `packages/taerae_core/DEVELOPER_GUIDE.md`
- [x] 플러터 개발 가이드 작성: `packages/flutter_taerae/DEVELOPER_GUIDE.md`
- [x] 플러그인 API 레퍼런스 작성: `packages/flutter_taerae/API_REFERENCE.md`
- [ ] 퍼블릭 배포용 짧은 튜토리얼(5분) 추가

## 8. 품질 게이트

- [x] `taerae_core`: `dart analyze` 통과
- [x] `taerae_core`: `dart test` 통과
- [x] `flutter_taerae`: `flutter analyze` 통과
- [x] `flutter_taerae`: `flutter test` 통과
- [ ] CI 워크플로우 자동화 (analyze/test/examples smoke)

## 9. 릴리즈 준비

- [x] v0.1.0 릴리즈 노트 초안 작성
- [ ] pubspec 메타데이터 최종 점검 (repository/homepage/license/topics)
- [ ] `taerae_core` publish dry-run (`dart pub publish --dry-run`)
- [ ] `flutter_taerae` publish dry-run (`flutter pub publish --dry-run`)
- [ ] 태그/릴리즈 노트 확정
- [ ] 배포 순서 실행 (`core` -> `flutter`)

## 10. 출시 후 초기 백로그

- [ ] 저장소 백엔드 확장 (옵션형)
- [ ] GraphRAG 고급 리랭킹 전략 샘플
- [ ] 성능 벤치마크 문서/자동 리포트
- [ ] SDK/API 안정화 정책(semver + deprecation rule)
