# 랄프 운용층 — UVM 전환 루프 설계

상태: **설계 v0.1** (래퍼·프롬프트 실물은 미구현, 11장 미결 사항 결정 후 구현).

`UVM_Conversion_Manual.md`가 "무엇을 어떻게 변환하는가"(작업 내용층)라면,
이 문서는 "누가 언제 실행하고 무엇으로 강제하는가"(운용층)를 다룬다.
약한 LLM(GLM4.7 등)을 Claude Code 하네스에 물려 Ralph 루프로
pure TB → UVM 변환을 자율 수행시키는 것이 목표다.
매뉴얼 본문은 이 설계로 인해 변경되지 않는다.

Ralph 기법 출처: https://ghuntley.com/ralph/ — 순수형은
`while :; do cat PROMPT.md | claude-code ; done`.
진행 상태는 LLM 컨텍스트가 아니라 파일과 git에 축적되고, 매 반복은 fresh context로 시작한다.

---

## 1. 설계 목표와 신뢰 모델

1. **오케스트레이션은 모델 밖에 둔다.** 계획은 매뉴얼의 Phase 레시피가,
   반복 제어는 루프 래퍼가, 기억은 파일이 담당한다. 모델은 "현재 상태에서
   최소 단위 작업 하나"만 수행한다.
2. **에이전트의 주장은 신뢰하지 않는다.** "완료했다"는 상태 선언은 주장일 뿐이며,
   최종 판정은 래퍼가 시뮬레이션을 재실행하고 로그 마커를 **에이전트가 만든 게이트
   스크립트와 무관하게** 직접 세어 확증한다.
3. **기억은 파일, 감사는 git.** 세션 간 인계는 `conversion_notes.md`(사람용 서사)와
   `ralph/state.json`(기계 판독 상태)으로 하고, 모든 반복은 커밋을 남긴다.

매뉴얼 절대 규칙과의 대응: 규칙 5("막히면 보고하고 멈춘다")는 루프에서
`blocked` 상태 선언 → 래퍼 HALT → 사람 호출로 구현된다. 금지 목록 4번
("검사 완화 금지")은 선언이 아니라 7장의 기계적 방어로 구현된다.

---

## 2. 구성 요소와 배치

변환 대상 스테이지를 `<target>/`이라 할 때 (매뉴얼 3장 파일 구조에 추가):

```text
<target>/
├── ralph/
│   ├── PROMPT.md              # 정적 루프 프롬프트 (운영자 관리, 보호 대상)
│   ├── state.json             # 기계 판독 상태 (3장 규격)
│   ├── expected_counts.json   # Phase 0 산출물 — 기대 카운트 (동결 대상, 7장)
│   └── logs/
│       └── iter_NNN.log       # 반복별 에이전트 출력
├── conversion_notes.md        # 사람용 인계 문서 (매뉴얼 5장 그대로)
├── sim/ tb/ uvc/ ...          # 매뉴얼 3장 템플릿
└── (원본 TB — 위치는 운영자가 PROMPT.md에 기입, 읽기 전용)

0_ai/0_global/tools/
└── ralph_uvm.ps1              # 루프 래퍼 (범용, -TargetDir 인자로 대상 지정)
```

| 구성물 | 쓰는 자 | 읽는 자 | 역할 |
|---|---|---|---|
| PROMPT.md | 사람만 | 에이전트(매 반복) | 반복 1회분의 절차·금지. 랄프의 "정적 프롬프트" |
| state.json | 에이전트(일부 필드), 래퍼 | 둘 다 | 현재 phase/status. 루프 분기의 유일한 근거 |
| expected_counts.json | 에이전트(Phase 0에서 1회) | 래퍼 | 최종 확증의 기준값. 동결 후 사람만 수정 가능 |
| conversion_notes.md | 에이전트 | 다음 반복의 에이전트, 사람 | 서사적 인계 — "이번에 한 일 / 다음 할 일" |
| ralph_uvm.ps1 | 사람만 | — | 루프 실행, 무결성 검사, 확증, HALT |

---

## 3. 상태 규격 — state.json

```json
{
    "phase": "3",
    "status": "in_progress",
    "blocked_reason": null,
    "last_gate": {
        "iteration": 12,
        "pass": false,
        "detail": "[DRV] 4/15 — item_done 누락 의심"
    },
    "iteration": 12
}
```

- `phase`: `"0" | "0.5" | "1" | "2" | "3" | "4" | "5"` — 매뉴얼 5장의 Phase 번호.
- `status`: `in_progress | gate_passed | blocked | done`.
- 필드 소유권: 에이전트는 `phase`, `status`, `blocked_reason`, `last_gate`만 수정한다.
  `iteration`은 래퍼 전용이다.
- 전이 규칙:
  - `in_progress → gate_passed`: 해당 반복에서 게이트를 실제 실행한 로그가 있을 때만 정당.
  - `phase N → 다음`: status가 `gate_passed`인 상태에서 **다음 반복의 에이전트가** 전이시킨다
    (전이와 작업을 같은 반복에 섞지 않는다).
  - `→ done`: `phase == "5"` 이고 Phase 5 게이트 통과 시에만.
  - `→ blocked`: 언제든 가능. 추측 우회보다 항상 옳은 선택지다.

---

## 4. 반복(iteration)의 정의

**한 반복 = 최소 단위 작업 1개 + 게이트 시도 1회 + 상태·노트 갱신 + 커밋 + 종료.**

- 단위는 "Phase 완료"가 아니라 "Phase 전진"이다. 약한 모델은 Phase 하나에
  여러 반복이 걸리는 것이 정상이며, 루프가 그것을 흡수한다.
- 단위 작업의 크기: 파일 1~2개 작성·이식, 에러 원인 하나의 수정, 게이트 재시도.
- **매 반복 게이트 시도 의무** — xsim 시뮬은 수 초~수십 초로 싸므로, 매 반복
  backpressure를 건다. 게이트 결과가 `last_gate`에 남아 다음 반복의 fresh context가
  "지금 뭐가 깨져 있나"를 즉시 안다.

Phase별 게이트(매뉴얼 5·6장)와 래퍼의 독립 확증:

| Phase | 에이전트가 실행하는 게이트 | 래퍼 독립 확증 (5장 알고리즘의 ②·③) |
|---|---|---|
| 0 | 원본 시뮬 PASS 재현, 노트 5항목, expected_counts.json 작성 | 스키마 검사 후 expected_counts.json **동결** |
| 0.5 / 1 | baseline과 동일 결과 | (v0.1에서는 생략) |
| 2 | 스켈레톤 시뮬 `UVM_ERROR : 0` | sim 로그에서 zero-error 요약 직접 grep |
| 3 | `[SEQ]`=`[DRV]`=케이스1 트랜잭션 수 | 마커 직접 카운트 vs expected_counts |
| 4 | 4개 마커 일치 + `[SB] RESULT` | 마커 직접 카운트 vs expected_counts |
| 5 | `run_xsim.ps1` 완주 | **시뮬 재실행 + 전 마커 독립 카운트** (최종 확증) |

---

## 5. 루프 래퍼 알고리즘 — ralph_uvm.ps1

```text
param: -TargetDir, -Backend (claude|glm), -MaxIter 40, -StallLimit 3, -MaxTurns 80

시작 전: git 작업 트리 클린 확인, state.json 없으면 초기값 생성 (phase=1 또는 0, 9장)

for i in 1..MaxIter:
    ① 무결성 검사: 보호 목록(7장)에 대해 git diff --name-only HEAD
       → 변경 발견 시 git checkout으로 원복 + HALT(protected-modified)
    ② 상태 분기: state.json 파싱
       - blocked → HALT(agent-blocked)
       - done    → 최종 확증: run_xsim.ps1 재실행 후, 래퍼가 sim_xsim.log의
                   마커를 expected_counts.json 기준으로 직접 카운트
                   → 통과: git tag ralph-done + 종료(성공)
                   → 실패: status를 in_progress로 되돌리고 노트에 사유 기록,
                     연속 2회 실패 시 HALT(done-claim-failed)
       - gate_passed (phase 3~4) → sim/out/sim_xsim.log 신선도 확인(mtime) 후
                   마커 독립 카운트, 불일치 시 status 원복 + 노트 기록
    ③ 에이전트 1회 실행:
       Get-Content ralph/PROMPT.md -Raw
         | claude -p --dangerously-skip-permissions --max-turns MaxTurns
         | Tee-Object ralph/logs/iter_i.log
       (Backend=glm이면 실행 전 ANTHROPIC_BASE_URL/ANTHROPIC_AUTH_TOKEN 스위칭)
    ④ 커밋 보장: 작업 트리가 dirty면 git add -A + commit "ralph(i): WIP autocommit"
       (작업 유실 방지 + 반복 단위 감사 추적)
    ⑤ 정체 감지: 최근 StallLimit회 연속 (새 커밋 없음 AND state 불변)
       → HALT(stalled)

MaxIter 소진 → HALT(budget-exhausted)
```

HALT는 실패가 아니라 **사람 호출**이다. 사유별 대응은 9장.

| HALT 사유 | 의미 |
|---|---|
| protected-modified | 에이전트가 보호 파일을 건드림 — 금지 위반, 프롬프트에 표지판 추가 필요 |
| agent-blocked | 에이전트 스스로 막힘 선언 — 매뉴얼 규칙 5의 정상 동작 |
| done-claim-failed | "완료" 주장이 독립 확증에서 연속 탈락 — 게이트 우회 시도 의심 |
| stalled | 진전 없는 공회전 — 프롬프트나 상태 파일이 오염됐을 가능성 |
| budget-exhausted | 반복 예산 소진 — 작업 크기 재평가 필요 |

---

## 6. PROMPT.md 템플릿 v0

운영자는 상단 기입 블록만 채운다. 본문은 대상과 무관하게 동일하다.

```markdown
# 임무: pure TB → UVM 변환 — 반복 1회분

<!-- 운영자 기입 블록 -->
- DUT: <dut 이름>
- 변환 작업 디렉토리: <target>/
- 원본 TB: <원본 TB 경로> (읽기 전용)
- 매뉴얼: 0_ai/0_global/manuals/UVM_Conversion_Manual.md
- 정답 예제: 260329_uart/m1_uart_tx/m15_uvm_minimal/
<!-- /운영자 기입 블록 -->

너는 루프 안에서 반복 실행되는 에이전트다. 이전 반복의 기억은 없다.
모든 맥락은 아래 파일에 있고, 이번 실행은 아래 절차만 수행하고 종료한다.

## 절차 (순서 고정)
1. `ralph/state.json`을 읽어 현재 phase와 status를 확인한다.
2. `conversion_notes.md`를 읽어 직전 반복이 남긴 "다음 할 일"을 확인한다.
3. 매뉴얼의 0장(계약), 4장(관용구), 7장(금지), 그리고 현재 Phase 절을 읽는다.
4. status 분기:
   - gate_passed → phase를 다음 Phase로 올리고 status를 in_progress로 바꾼 뒤 5로.
   - in_progress → 바로 5로.
5. 현재 Phase를 전진시키는 **최소 단위 작업 하나만** 수행한다.
   크기 기준: 파일 1~2개 작성·이식, 또는 에러 원인 하나 수정, 또는 게이트 재시도.
6. 현재 Phase의 게이트를 실행한다(매뉴얼 5장·6장). 결과를 state.json의 last_gate에
   기록한다. 전부 통과 시 status를 gate_passed로 바꾼다.
   Phase 5 게이트 통과 시에만 status를 done으로 바꾼다.
7. conversion_notes.md 끝에 3~5줄 추가: 이번에 한 일 / 게이트 결과 / 다음 반복이
   이어서 할 일.
8. 커밋한다: `ralph: phase <N> <한 일 요약>` — 그리고 **즉시 종료한다.
   다음 작업을 시작하지 않는다.**

## 막혔을 때
같은 원인으로 게이트가 반복 실패하고 코드 수정으로 해결하지 못하겠으면:
state.json의 status를 blocked로, blocked_reason에 (막힌 지점 / 시도한 것 /
에러 로그 위치)를 적고 종료한다.
추측으로 우회하는 것보다 blocked 선언이 항상 옳다 (매뉴얼 규칙 5).

## 금지 — 래퍼가 감시하며, 위반 시 루프가 강제 중단된다
- 보호 파일 수정 금지: 매뉴얼, 이 PROMPT.md, 원본 TB 디렉토리, baseline.log,
  동결된 expected_counts.json, 다른 스테이지의 파일.
- 게이트의 검사 로직·기대 카운트·로그 마커 문자열을 고쳐서 통과시키는 것 금지.
  게이트가 실패하면 고칠 것은 검사가 아니라 코드다.
- placeholder·스텁·"일단 컴파일만" 구현 금지. 타이밍/프로토콜/판정 코드는
  원본에서 복사한다 (매뉴얼 규칙 4).
- "구현이 없다"고 단정하기 전에 반드시 검색(Grep)으로 확인한다.
- 한 반복에서 두 Phase 진행 금지. state.json의 iteration 필드 수정 금지.
```

운용 원칙: 이 템플릿은 출발점이고, HALT가 날 때마다 사람이 표지판(signpost)
문장을 추가하며 진화한다 (9장). 표지판은 "~하지 마라"보다
"~하기 전에 반드시 ~하라" 형태가 약한 모델에 잘 먹힌다.

---

## 7. 보호 목록과 게이트 변조 방어

**보호 목록** — 래퍼가 매 반복 시작 시 git diff로 검사, 변경 발견 시 원복 + HALT:

- `0_ai/0_global/manuals/**` (매뉴얼·규약)
- `<target>/ralph/PROMPT.md`
- 원본 TB 경로 (운영자 기입)
- `<target>/sim/baseline.log`
- `<target>/ralph/expected_counts.json` — **동결 후부터** (아래)
- 대상 스테이지 밖의 모든 경로 (다른 스테이지 오염 방지)

**expected_counts.json** — "기대 카운트의 로그 역산 금지"(매뉴얼 금지 4)의 기계적 구현:

```json
{
    "dut": "uart_tx",
    "cases": [
        { "name": "basic",  "transactions": 5 },
        { "name": "corner", "transactions": 5 },
        { "name": "random", "transactions": 5 }
    ],
    "total_transactions": 15
}
```

- Phase 0에서 에이전트가 **원본 TB 분석만으로** 작성한다 (UVM 코드가 존재하기 전 —
  따라서 역산이 원천 불가능한 시점의 산출물이다).
- Phase 0 게이트 통과 시 래퍼가 스키마를 검사하고 동결한다(보호 목록 편입).
  이후 수정은 사람만 할 수 있다.
- 동결값이 실제로 틀렸다면(원본 오독) Phase 3~5 게이트가 지속 실패 →
  `blocked` → HALT로 사람에게 도달한다. 에이전트가 스스로 고치는 경로는 없다.

**run_xsim.ps1 특칙** — 이 파일은 에이전트가 Phase 5에서 작성하는 산출물이라
사전 보호가 불가능하다. 방어는 이중이다:

1. **최종 판정 무관화**: 래퍼의 done 확증은 run_xsim.ps1의 검사부를 신뢰하지 않는다.
   시뮬 실행에만 스크립트를 쓰고, 마커 카운트는 래퍼가 `sim_xsim.log`에서
   매뉴얼 6장 마커 규약(고정 문자열)으로 직접 세어 expected_counts.json과 대조한다.
   → 에이전트가 검사를 지우거나 완화해도 최종 판정에 영향을 줄 수 없다.
2. **사람 리뷰**: DoD 검토 시 run_xsim.ps1을 m15 원본과 대조한다. m15 스크립트는
   "기대값 상수부(`$Expected*`, 23~29행) + 고정 검사부(57행~)" 구조이므로,
   상수부 외의 차이는 전부 설명 가능해야 한다.

---

## 8. 종료·정체·예산

- **종료 권한은 래퍼에만 있다.** 에이전트의 `done`은 주장이고, 래퍼의 독립 확증
  (시뮬 재실행 + 마커 직접 카운트)을 통과해야 `ralph-done` 태그와 함께 루프가 끝난다.
- 기본 예산: `MaxIter 40` (반복 총량), `StallLimit 3` (연속 무진전),
  `MaxTurns 80` (반복 내 에이전트 턴 수), done 주장 연속 실패 2회.
- 예산 값은 첫 파일럿에서 보정한다. 원칙: 예산 소진은 실패가 아니라
  "작업 크기나 프롬프트에 문제가 있다"는 신호다.

---

## 9. 사람의 개입 지점

**킥오프 (루프 시작 전):**

1. PROMPT.md 운영자 기입 블록 작성, backend 환경 준비, git 클린 확인.
2. **Phase 0 담당 결정** — 권장: 사람 또는 강한 모델이 Phase 0(행위 추출,
   expected_counts 작성)을 수행하고, 약한 모델 루프는 Phase 1부터 돌린다.
   근거: 행위 추출은 레시피화가 안 되는 판단 집약 단계로, 약한 모델이 여기서
   틀리면 이후 모든 게이트의 기준값이 오염된다. 반대로 Phase 1~5는
   "복사 원본이 존재하는 패턴 작업"이라 약한 모델+게이트 조합의 적성 구간이다.

**HALT 대응 — 표지판(signpost) 사이클:**

1. `ralph/logs/iter_NNN.log`와 HALT 사유로 원인을 특정한다.
2. 같은 실수가 재발하지 않도록 PROMPT.md에 표지판 문장을 추가한다 (사람만 수정).
3. 필요 시 state.json/노트를 손보고 루프를 재기동한다.
4. 표지판이 매뉴얼 수준의 일반성을 가지면 매뉴얼 "흔한 실수" 항목으로 승격을
   검토한다 — 이것이 파일럿을 통한 매뉴얼 개선 피드백 루프다.

**완료 후:** DoD 체크리스트 검토, run_xsim.ps1 리뷰(7장), 원본 TB 보존/삭제 결정
(매뉴얼 DoD의 "사람에게 질문" 항목).

---

## 10. 매뉴얼과의 접점

매뉴얼 본문은 변경하지 않는다. 유일한 후보 변경은 10장(운영자 메모)에
이 문서로의 링크 한 줄을 추가하는 것 — 11장 미결로 남긴다.

이 운용층은 매뉴얼에 이미 있는 것을 새로 만들지 않는다: Phase 정의·게이트
내용·마커 규약·금지 사항은 전부 매뉴얼을 가리키고, 이 문서는 그것을
루프에서 강제하는 장치만 정의한다.

---

## 11. 미결 사항 — 결정 후 구현 착수

| # | 항목 | 선택지 | 권장 |
|---|---|---|---|
| 1 | Phase 0 담당 | A. 사람+강한 모델 / B. 약한 모델 루프에 포함 | A (9장 근거) |
| 2 | 실행 격리 | A. 레포 안에서 그대로 + git 보호 / B. git worktree 분리 | A (v1 — 스테이지 디렉토리가 이미 격리 단위) |
| 3 | 매뉴얼 10장에 링크 1줄 추가 | 예 / 아니오 | 예 |
| 4 | 예산 기본값 | MaxIter 40 / StallLimit 3 / MaxTurns 80 | 파일럿에서 보정 |
| 5 | GLM 실행 환경 | 래퍼 -Backend 파라미터로 env 스위칭 | 실제 URL/키 확보 후 확정 |
| 6 | 첫 파일럿 대상 블록 | uart_tx 외 신규 블록 선정 필요 | 사용자 결정 |

구현 순서(결정 후): ralph_uvm.ps1 → PROMPT.md 실물 → 파일럿 1회 →
표지판·예산 보정 → 매뉴얼 피드백 반영.
