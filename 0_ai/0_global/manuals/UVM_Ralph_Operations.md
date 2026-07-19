# 랄프 운용층 — UVM 전환 루프 안전 설계

> [!CAUTION]
> **DRAFT / DO NOT RUN — 설계 검토용 문서다.**
>
> 이 저장소에는 이 설계를 충족하는 검증된 래퍼나 프롬프트가 없다. 아래 알고리즘과
> 예시는 의사 코드이며 그대로 복사해 실행하면 안 된다. 11장의 안전 시험, 일회용 환경
> 파일럿, 사람의 승인을 모두 통과하기 전에는 무인 실행에 사용하지 않는다.

상태: **안전 설계 v0.2 — 미구현·미검증**.

`UVM_Conversion_Manual.md`가 “무엇을 어떻게 변환하는가”를 설명하는 작업 내용층이라면,
이 문서는 반복 실행을 어떤 경계 안에 가두고 어떻게 독립 검증할지를 설명하는 운용층이다.
목표는 비용·성능 특성이 서로 다른 코딩 에이전트가 pure TB → UVM 변환의 작은 단계를
반복 수행하게 하되, 에이전트나 에이전트가 만든 스크립트를 신뢰 경계 밖에 두는 것이다.

## 범위·출처·비제휴 고지

- Ralph 반복 기법의 출처는 Geoffrey Huntley의 [Ralph 글](https://ghuntley.com/ralph/)이다.
  원문의 단순 반복 개념만 참고하며, 이 문서의 격리·검증·Git 정책은 이 저장소를 위한
  별도 안전 설계다. 원문도 기존 코드베이스 적용에 강한 주의를 표하므로, 여기서는
  일회용 격리를 필수 조건으로 둔다.
- 이 문서는 교육·실험 목적의 저장소별 지침이다. Accellera, IEEE, AMD, Anthropic,
  Zhipu AI 또는 Geoffrey Huntley의 공식 문서·인증·보증이 아니며 어느 주체와도 제휴하지
  않는다. UVM, Vivado, XSim, Claude 및 각 모델·제품명은 대상을 식별하기 위한 명칭이다.
- 원본 TB와 이식 대상 코드는 운영자가 소유하거나 수정·재배포 권한을 가진 것만 사용한다.
  제3자 코드가 있으면 원래의 저작권, 라이선스, NOTICE와 출처를 보존한다. UVM reference
  implementation이나 도구 공급자의 파일을 이 저장소에 복사할 때는 해당 배포 조건을
  별도로 확인한다.
- API 키, 라이선스 파일, 사내 소스와 transcript는 공개 가능한 산출물이 아니다. 공개
  저장소에 반영하기 전에 사람의 출처·라이선스·비밀정보 검토를 거친다.
- 외부 모델 API를 사용하면 prompt와 source 일부가 공급자에게 전송될 수 있다. 전송 권한,
  공급자 측 보존·학습 사용 여부, 처리 지역, 조직의 DPA와 데이터 분류 정책을 run 전에
  확인한다. 승인되지 않은 source는 보내지 말고 승인된 로컬·전용 backend를 사용하거나
  run을 중단한다. 이 요구는 9장의 로컬 로그 보존 기간과 별개다.

---

## 1. 신뢰 모델과 절대 원칙

1. **호스트와 장기 보관 저장소를 에이전트에게 노출하지 않는다.** 에이전트는 승인된
   isolated container, VM 또는 동등한 sandbox runtime 안의 일회용 clone에서만 실행한다.
   별도 branch나 worktree는 변경 분리 수단일 뿐 보안 경계가 아니다.
2. **에이전트의 주장과 산출물은 모두 비신뢰 입력이다.** `done`, 자체 테스트 결과,
   에이전트가 만든 `run_xsim.ps1`, 로그와 마커는 최종 판정의 근거가 될 수 없다.
3. **제어 영역은 에이전트 쓰기 범위 밖에 둔다.** 래퍼, 정적 프롬프트, immutable
   baseline, 보호 파일 hash, 승인된 기대값, 신뢰 verifier와 감사 로그는 에이전트에게
   쓰기 권한을 주지 않는다.
4. **커밋은 래퍼만 만든다.** 에이전트는 Git 명령으로 commit, tag, merge, push, branch
   조작 또는 `.git` 수정을 하지 않는다. 래퍼도 승인된 경로만 명시적으로 stage한다.
5. **위반은 자동 복구하지 않고 즉시 HALT한다.** 보호 파일 변경을 `checkout` 등으로
   되돌리면 증거와 사용자의 동시 작업을 잃을 수 있다. 일회용 환경을 보존해 사람이
   검토한 뒤 폐기하거나, 승인된 경로만 별도로 복구한다.
6. **최종 권한은 사람에게 있다.** 신뢰 verifier 통과는 병합 후보가 되었다는 뜻일 뿐이다.
   tag, merge, 공개 push는 diff·출처·라이선스·비밀정보를 검토한 사람이 승인한다.

### 1.1 권한 우회 금지

호스트나 일반 개발 shell에서 `--dangerously-skip-permissions`를 사용하지 않는다. 이 옵션은
도구 사용 승인을 우회하므로 저장소·자격 증명·네트워크가 노출된 환경에서는 금지한다.
Claude Code를 사용할 때는 공식 [권한 모드 문서](https://code.claude.com/docs/en/permission-modes)와
[개발 컨테이너 지침](https://code.claude.com/docs/en/devcontainer)을 기준으로 승인된 sandbox와
최소 권한을 구성한다.

권한 우회가 파일럿에서 불가피하다고 판단되더라도 다음 조건을 **모두** 만족하지 않으면
실행하지 않는다.

- 비-root 일회용 container/VM이며 종료 후 전체 폐기가 가능하다.
- 필요한 작업 디렉토리만 mount하고 호스트 홈, SSH 키, Git 자격 증명, cloud 자격 증명,
  Docker socket과 다른 저장소는 mount하지 않는다.
- `.git`과 제어 영역은 에이전트 프로세스에서 쓰기 불가능하다.
- network egress는 승인된 모델 API와 필요한 라이선스 endpoint만 allowlist한다.
- 일회성·최소 권한·짧은 만료의 자격 증명을 사용하고 실행 직후 폐기한다.
- 조직 보안 담당자와 운영자가 위험을 검토하고 해당 실행을 명시적으로 승인한다.

이 조건은 권한 우회를 안전하게 만든다는 보장이 아니다. 이 설계의 기본값은 권한 우회를
사용하지 않는 것이다.

---

## 2. 격리 구조와 구성 요소

한 run마다 새 식별자와 일회용 clone을 만든다. 권장 논리 구조는 다음과 같다.

```text
<isolated-runtime>/                    # 승인된 container / VM / sandbox
├── repo/                              # 일회용 clean clone, 전용 ralph/<run-id> branch
│   └── <target>/                      # 에이전트의 제한된 작업 영역
│       ├── ralph/
│       │   ├── state.json             # 에이전트 상태 주장
│       │   └── expected_counts.candidate.json
│       ├── conversion_notes.md        # 다음 반복에 전달할 작업 기록
│       ├── sim/ tb/ uvc/ ...          # 운영자가 정한 쓰기 허용 후보
│       └── out/                        # 생성물; commit 금지, run 종료 시 폐기
└── control/                           # 에이전트 쓰기 금지, 가능하면 mount 자체를 분리
    ├── PROMPT.md                      # 사람이 승인한 정적 프롬프트
    ├── baseline.json                  # kickoff commit, 보호 경로·hash·파일형 정보
    ├── expected_counts.json           # 사람 승인 후 동결된 기대값
    ├── wrapper_state.json             # 반복 번호, 시간·비용, 검증 결과
    ├── verifier/                      # 고정 compile/elaborate/simulate 명세와 parser
    └── logs/                          # 접근 제한·redaction·보존 기한 적용, Git 밖
```

원본 TB는 별도 read-only mount로 제공하는 것이 원칙이다. 그것이 불가능하면 보호 경로로
등록하고 OS 권한과 sandbox 정책으로 쓰기를 차단한다. 프롬프트에 “읽기 전용”이라고 적는
것만으로는 보호가 아니다.

| 구성물 | 쓰기 권한 | 역할 |
|---|---|---|
| 작업 소스·`conversion_notes.md` | 에이전트, 승인 경로 안에서만 | 한 반복의 코드 변경과 인계 |
| `state.json` | 에이전트 | 현재 Phase와 게이트에 대한 **주장** |
| `wrapper_state.json` | 래퍼만 | 반복·예산·신뢰 검증의 실제 기록 |
| PROMPT·baseline·보호 hash | 사람/래퍼만 | 고정 지시와 무결성 기준 |
| 승인된 `expected_counts.json` | 사람/래퍼만 | 독립 verifier의 기준값 |
| verifier | 사람만 | 고정 소스 manifest와 검증 로직 |
| control logs | 래퍼만 | redaction된 감사 자료; 저장소에 commit하지 않음 |

---

## 3. 킥오프 전 안전 조건

래퍼는 아래 조건 중 하나라도 만족하지 않으면 fail closed로 종료한다.

1. **일회용성:** 승인된 격리 runtime 안의 새 clone이고, 전용 `ralph/<run-id>` branch다.
   `main`, `master`, release branch, 사용자의 기존 worktree에서는 실행하지 않는다.
2. **단일 실행:** 저장소와 target의 canonical path를 포함한 run lock을 획득한다. 동일
   clone·target에 다른 래퍼나 사용자가 작업 중이면 시작하지 않는다.
3. **경로 경계:** repository root와 target을 canonicalize한 뒤 target이 root 내부인지
   확인한다. symlink, junction, reparse point, hardlink/file identity alias와 path traversal로
   허용 영역 밖 또는 보호 파일에 쓰는 경로를 거부한다.
4. **깨끗한 시작:** tracked, staged, untracked 파일을 모두 포함한 상태가 clean인지 확인한다.
   무시 파일도 별도 inventory에 기록해 예상하지 못한 자격 증명이나 로그가 없는지 검사한다.
5. **immutable baseline:** 시작 commit SHA, branch, tracked file 목록, 보호 경로의 content
   hash·파일형·권한, 시작 시 untracked 목록과 immutable Git 보안 설정을
   `control/baseline.json`에 기록한다. 이 파일은 에이전트가 볼 필요가 없고 쓸 수 없어야
   한다. wrapper가 만든 마지막 commit SHA는 별도 control state로 이어서 기록한다.
6. **명시적 allowlist:** 운영자가 `allowed_write_paths`와 더 좁은
   `allowed_commit_paths`를 상대 경로로 확정한다. 반드시
   `allowed_commit_paths ⊆ allowed_write_paths`이고 두 집합 모두 보호 경로와 서로소여야 한다.
   wildcard는 최소화하며 repository root 전체를 허용하면 시작하지 않는다.
7. **보호 목록:** 에이전트의 `.git/**` 접근 전체, 제어 영역, 매뉴얼, 원본 TB, baseline log,
   승인된 기대값, 다른 스테이지와 target 밖의 모든 경로를 보호한다. wrapper의 정상 commit에
   필요한 Git 변경과 immutable Git 설정은 7장처럼 구분한다.
8. **신뢰 verifier:** 에이전트 쓰기 범위 밖의 고정 compile/include/dependency closure,
   top, tool option, 독립 oracle, parser와 timeout이 준비되어 있어야 한다. 비신뢰 HDL은 별도의
   최소 권한 verifier sandbox에서 실행한다. 이 조건이 없으면 무인 루프를 시작하지 않는다.
9. **자격 증명:** 개인 Git/SSH/cloud 자격 증명은 격리 환경에 제공하지 않는다. 모델 API는
   이 run 전용의 최소 권한 token을 process scope로만 주고 prompt·명령행·파일에 쓰지 않는다.
10. **출처 확인:** 원본과 예제가 사용·수정·공개 가능한지 운영자가 확인하고, 보존해야 할
    라이선스·NOTICE를 보호 목록에 넣는다.

전용 branch에는 upstream push 권한을 두지 않는다. 래퍼에는 로컬 commit 권한만 주며
원격 push, tag, merge는 구현하지 않는다.

---

## 4. 상태와 반복의 정의

`<target>/ralph/state.json`은 에이전트의 작업 인계용이며 보안 판단에 사용하지 않는다.

```json
{
    "phase": "3",
    "status": "in_progress",
    "blocked_reason": null,
    "last_gate_claim": {
        "pass": false,
        "detail": "[DRV] 4/15 — item_done 누락 의심"
    }
}
```

- `phase`: `"0" | "0.5" | "1" | "2" | "3" | "4" | "5"`.
- `status`: `in_progress | gate_claimed | blocked | done_claimed`.
- `gate_claimed`와 `done_claimed`는 신뢰 결과가 아니라 래퍼에게 검증을 요청하는 상태다.
- 반복 번호, 검증 통과 여부, baseline commit, 시간·비용은 에이전트가 쓸 수 없는
  `control/wrapper_state.json`에만 둔다.

**한 반복 = 상태 읽기 + 최소 단위 작업 하나 + 에이전트 자체 게이트 시도 + 노트 갱신 +
래퍼 검사·신뢰 검증 + 래퍼 commit 또는 HALT.**

- 단위는 “Phase 완료”가 아니라 “Phase 전진”이다. 파일 1~2개 이식, 에러 원인 하나 수정,
  또는 게이트 재시도 정도로 제한한다.
- 에이전트 자체 게이트는 빠른 feedback일 뿐이다. 통과를 주장하면 래퍼가 별도 verifier를
  새 output 디렉토리에서 실행한다.
- 한 반복에서 두 Phase를 진행하지 않는다.
- Phase 전이는 직전 Phase의 신뢰 verifier 통과 기록이 `wrapper_state.json`에 있을 때만
  래퍼가 승인한다.

### Phase별 검증 의도

| Phase | 작업 의도 | 신뢰 verifier의 확인 |
|---|---|---|
| 0 | 원본 행위와 기대 transaction 수 추출 | 사람이 원본과 대조·승인한 뒤 기대값 hash 동결 |
| 0.5 / 1 | baseline 및 파일 구조 준비 | 원본 baseline 재현과 고정 manifest 검사 |
| 2 | 빈 UVM 구조와 zero-transaction smoke test | 고정 compile 목록, 정상 종료, zero-error·zero-transaction |
| 3 | sequence-driver 경로 이식 | 승인 기대값과 `[SEQ]`, `[DRV]` 수 비교 |
| 4 | monitor-scoreboard 경로 이식 | 모든 고정 marker와 `[SB] RESULT` 비교 |
| 5 | 전체 회귀 후보 완성 | 깨끗한 output에서 전체 compile/elaborate/simulate 재실행 |

Phase 2의 빈 skeleton은 매뉴얼이 의도한 구조 검증 단계다. 따라서 일반적인 placeholder·stub
금지 규칙의 **유일한 명시적 예외**다. 이 단계에서는 transaction을 발생시키거나 기능을
완성한 척하지 않고, Phase 2 범위를 state와 노트에 표시한다. Phase 3 이후에는 임시 반환값,
검사 우회, 빈 구현으로 통과시키는 행위를 다시 금지한다.

---

## 5. 안전한 래퍼 알고리즘

아래는 구현 요구사항을 설명하는 의사 코드다. 실제 PowerShell이 아니며 실행해서는 안 된다.

```text
parameters:
    TargetDir, SandboxRuntime, Backend
    MaxIterations, MaxTurnsPerIteration
    IterationTimeout, ToolTimeout, TotalRuntime
    MaxTokensOrSpend, StallLimit, LogRetention

preflight:
    assert approved isolated runtime; reject host/direct execution
    acquire exclusive run lock
    assert disposable clean clone and dedicated ralph/<run-id> branch
    resolve repo/target paths; reject link, file-identity and reparse-point escapes
    capture immutable kickoff commit, protected hashes and Git security settings
    initialize wrapper_state.last_commit = kickoff commit outside agent scope
    validate write/commit allowlist subset and disjoint protected paths
    validate trusted verifier, independent oracle and separate verifier sandbox
    validate scoped credentials, egress policy, time and cost budgets

for each iteration within every budget:
    verify lock, branch and HEAD == wrapper_state.last_commit
    verify a single-parent wrapper commit chain from the kickoff commit
    verify protected hashes, file types and immutable Git settings
    inventory tracked + staged + untracked changes before execution
    snapshot the complete Git metadata directory for the agent execution window

    start one agent process in sandbox with default permission controls
        provide approved prompt and read-only references
        do not expose control directory, .git, host credentials or unrelated paths
        capture output to external restricted log with secret redaction
        enforce iteration timeout; on timeout kill the complete process tree

    inventory all tracked + staged + untracked changes after execution
    canonicalize every changed path and inspect links/reparse points/hardlink identities
    if any path is outside allowed_write_paths: HALT and preserve evidence
    if any protected hash/file type changed: HALT and preserve evidence
    if any Git metadata changed during the agent window: HALT
    if secret/license/provenance scan fails: HALT

    start a separate one-shot verifier sandbox with no credentials and denied egress
        mount agent source read-only, verifier/control inputs read-only, fresh output writable
        use fixed source/include/dependency closure, top, tool options and parser
        reject unapproved include, foreign interface, system command and file/network access
        invoke xvlog/xelab/xsim directly with tool timeout and process-tree cleanup
        accept only tool exit codes and verifier-owned fresh logs
        never invoke agent-authored run_xsim.ps1 for the verdict
        never consume an agent-authored log as verification evidence
        require a verifier-owned oracle over observable DUT behavior; otherwise HALT

    validate state transition against trusted result
    select only explicit allowed_commit_paths; exclude outputs and logs
    review the exact staged diff mechanically; fail if the set differs
    wrapper creates one local commit with run id, phase and verifier result
    assert the new commit tree equals the reviewed index
    assert the new HEAD has wrapper_state.last_commit as its only parent
    assert no other ref or immutable Git setting changed
    update wrapper_state.last_commit outside agent scope

    if blocked, stalled, claim mismatch or budget exhausted: HALT

after a Phase 5 trusted pass:
    mark human-review-required; release lock; stop
    do not tag, merge, push or delete evidence automatically
```

### 5.1 변경 검사와 commit 규칙

- 비교 기준은 매 반복의 현재 `HEAD`만이 아니라 kickoff 때 기록한 immutable baseline도
  포함한다. 보호 파일은 baseline hash와 매 반복 전 snapshot 양쪽에 대해 검사한다.
- `git diff`만 사용하지 않는다. staged, unstaged, untracked와 파일형 변경을 모두 열거한다.
  ignore 규칙은 보안 경계가 아니므로 ignored 파일도 비밀정보·출력 inventory 대상으로 본다.
- 광역 stage를 금지한다. `git add -A`, `git add .`, repository root wildcard는 사용하지 않고,
  래퍼가 검증한 정확한 상대 pathspec만 stage한다.
- stage 후 실제 index 목록과 `allowed_commit_paths`를 다시 대조하고, 일치하지 않으면 commit하지
  않는다. 생성 로그, simulator output, token/config, control 파일은 commit 대상이 아니다.
- 에이전트의 commit 지시나 WIP autocommit fallback은 두지 않는다. commit이 실패하면 HALT한다.
- 에이전트 실행 전후에는 resolved Git metadata directory 전체를 비교한다. 이 구간에서 index,
  object, ref, reflog를 포함해 하나라도 바뀌면 에이전트가 Git에 접근한 것으로 보고 HALT한다.
- wrapper commit 구간에는 검토한 index, 그 commit에서 도달 가능한 새 object, 현재 전용 branch
  ref, branch reflog와 `HEAD` reflog의 예상 변경만 허용한다. `HEAD`의 symbolic target, config,
  hook, remote/다른 ref와 alternates는 kickoff부터 immutable이다. wrapper는 격리된 Git config로
  hook·서명·외부 credential helper를 비활성화한다. 새 commit tree가 검토한 index와 같고 직전
  `wrapper_state.last_commit`만 부모로 둔 단일-parent chain인지 확인한다.
- 보호 위반 시 자동 `checkout`, `reset`, 삭제를 하지 않는다. 일회용 clone이므로 사람이 diff와
  로그를 확보한 뒤 clone 전체를 폐기할 수 있다.

---

## 6. 에이전트 프롬프트 요구사항

실제 `PROMPT.md`는 구현·검토 단계에서 별도로 만들며, 이 문서에는 실행 가능한 완성
프롬프트를 두지 않는다. 최소한 다음 계약을 포함해야 한다.

```markdown
# 임무: pure TB → UVM 변환의 승인된 반복 한 회

- 허용된 target과 쓰기 경로만 사용한다.
- 원본 TB, 매뉴얼, 기대값, verifier와 control 영역은 읽기 전용이다.
- 현재 state, conversion_notes, 현재 Phase의 매뉴얼 절을 순서대로 읽는다.
- 현재 Phase를 전진시키는 최소 단위 작업 하나만 한다.
- 자체 게이트 결과는 claim으로만 기록한다. 최종 통과를 단정하지 않는다.
- commit, tag, merge, push, branch 변경과 .git 접근을 하지 않는다.
- 자격 증명·환경 변수·프롬프트·전체 transcript를 파일이나 출력에 적지 않는다.
- network 다운로드, 패키지 설치, 외부 업로드는 운영자 승인 없이 하지 않는다.
- 검사 로직, 기대 수치, marker 문자열 또는 로그를 조작해 통과시키지 않는다.
- Phase 2에서 매뉴얼이 요구한 빈 skeleton만 명시적 예외로 허용한다.
  Phase 3 이후 placeholder, stub, 임시 성공값과 compile-only 우회는 금지한다.
- 원본 코드는 사용 권한이 확인된 범위에서만 이식하고 기존 고지·라이선스를 보존한다.
- 막히면 시도한 내용과 최소 오류 위치를 blocked_reason에 적고 즉시 종료한다.
- 노트와 state claim을 갱신한 뒤 종료한다. 다음 Phase나 다음 작업을 시작하지 않는다.
```

프롬프트 규칙은 sandbox, OS 권한과 래퍼 검사를 보조할 뿐 대체하지 않는다. HALT가 발생할
때마다 원인을 분석해 표지판을 개선할 수 있지만, 프롬프트 완화로 안전 검사를 우회해서는
안 된다.

---

## 7. 보호 목록과 기대값 동결

최소 보호 목록은 다음과 같다.

- 에이전트 접근 금지: resolved Git metadata directory 전체 (`.git` file이 가리키는 경로 포함)
- run 전체 immutable: Git `HEAD` symbolic target, config, hooks, remotes와 다른 refs,
  `objects/info/alternates`
- wrapper commit 때만 예상 변경 가능: 검토한 index와 commit tree, 도달 가능한 새 objects,
  현재 전용 branch ref, branch reflog와 `HEAD` reflog
- `control/**` 전체: wrapper, prompt, baseline, hash, verifier, logs, wrapper state
- `0_ai/0_global/manuals/**`와 프로젝트 정책·라이선스 파일
- 원본 TB와 baseline log
- 승인·동결된 `expected_counts.json`
- 다른 스테이지와 target 밖의 모든 파일
- API·Git·SSH·cloud·도구 라이선스 관련 자격 증명

보호는 세 겹으로 적용한다.

1. 에이전트 sandbox에는 Git metadata를 mount하지 않고 OS/sandbox 정책으로 접근을 거부한다.
   다른 보호 경로도 필요하지 않으면 mount하지 않으며, 참조가 필요할 때만 read-only로 제공한다.
2. wrapper가 canonical path allowlist와 symlink/junction/reparse point/hardlink file identity를
   실행 전후 검사한다.
3. 일반 보호 파일과 immutable Git 설정은 baseline의 content hash·파일형·권한과 비교한다.
   wrapper 전용 Git 변경은 agent 실행 구간 snapshot 및 단일-parent commit chain으로 별도
   검증한다. 정상 commit으로 바뀌는 objects/index/ref/reflog를 immutable hash와 혼동하지 않는다.

### 7.1 기대값 승인 절차

Phase 0에서 만든 값은 처음에는 `expected_counts.candidate.json`이다. 에이전트가 작성했다면
그 값은 신뢰하지 않는다. 운영자 또는 지정된 독립 검토자가 원본 TB의 stimulus·종료 조건과
직접 대조하고 다음을 수행한다.

1. 스키마, 케이스 목록, transaction 수와 marker 계약을 검토한다.
2. 출처가 원본 TB 분석인지 확인하고 생성 로그에서 역산한 값이 아님을 확인한다.
3. 승인본을 control 영역의 `expected_counts.json`으로 복사한다.
4. hash와 승인자·승인 시각·원본 baseline SHA를 `baseline.json`에 기록한다.

승인 후 값이 틀린 것으로 보이면 에이전트가 고치지 않는다. `blocked`로 HALT한 뒤 사람이
원본을 재검토하고 새 승인 기록을 만든다.

---

## 8. 신뢰 verifier

최종 verifier는 에이전트 작업물과 별개의 사람이 관리하며 에이전트 쓰기 범위 밖에 둔다.
그러나 verifier가 실행하는 SystemVerilog도 비신뢰 입력이므로 verifier 프로세스 자체를 별도
일회용 sandbox에서 실행한다. 다음 조건을 모두 만족해야 한다.

- verifier sandbox에는 자격 증명을 주지 않고 egress를 차단한다. agent source는 read-only,
  verifier와 필요한 control 입력은 read-only, 새 output만 writable로 mount한다. CPU·memory·disk·
  process·wall-clock 한도를 적용하고 종료 후 sandbox를 폐기한다.
- 고정된 상대 source manifest, 전체 include/dependency closure, top과
  compile/elaborate/simulate option을 사용한다. manifest 밖 include, DPI/VPI/PLI·foreign library,
  `$system`, 임의 file/network I/O는 명시적으로 검토·allowlist하지 않은 한 거부한다.
- 매 실행마다 예측 불가능한 새 output 디렉토리를 만들고 기존 로그·snapshot을 재사용하지
  않는다.
- `xvlog`, `xelab`, `xsim`을 직접 호출하고 각 exit code, timeout, 생성물 위치를 확인한다.
- 에이전트가 작성·수정한 `run_xsim.ps1`, Makefile, Tcl 또는 simulator log를 최종 판정에
  사용하지 않는다. 이런 파일은 납품 편의 산출물로서 별도 사람 리뷰 대상일 뿐이다.
- verifier가 소유한 새 로그만 고정 parser로 읽고, 승인된 기대값과 정확히 비교한다.
- marker 문자열의 단순 존재뿐 아니라 test 종료, fatal/error 수, transaction 수, case별
  순서와 필요한 timeout 조건을 함께 확인한다.
- 에이전트가 출력한 marker만을 기능 증거로 삼지 않는다. verifier가 소유한
  stimulus·observer·reference checker로 DUT interface trace와 최종 결과를 직접 확인하는
  독립 oracle은 무인 합격의 필수 조건이다. 변환 대상 TB 자체를 검증하는 경우에는 보호된
  원본 baseline의 관찰 가능 행위와 비교하고, 에이전트 소스의 고정 문자열 출력만으로 통과할
  수 없게 한다. 적절한 oracle을 만들 수 없으면 fail closed로 HALT하고 자동 완료 처리하지 않는다.
- verifier 자체 hash가 baseline과 다르거나 source manifest 밖 파일이 compile에 들어가면
  즉시 실패한다.
- simulator와 모든 자식 프로세스에 timeout을 적용하고 실패·시간 초과 시 process tree를
  종료한다.

에이전트의 `done_claimed`와 신뢰 verifier 통과가 일치하지 않으면 `done-claim-failed`로
HALT한다. verifier 통과만으로 자동 tag나 공개 push를 수행하지 않는다.

---

## 9. 로그·비밀정보·네트워크 정책

### 9.1 비밀정보

- API token을 source, prompt, state, notes, command argument 또는 저장소 config에 기록하지
  않는다. 가능하면 runtime secret 기능을 사용하고, 불가피한 process environment는 해당
  자식 프로세스에만 주입한 뒤 즉시 제거한다.
- 가능하면 backend client나 credential broker를 agent tool process 밖에 두어 shell 명령이
  token을 읽지 못하게 한다. CLI 구조상 분리가 불가능하면 token 노출 가능성을 전제로
  single-run 최소 권한 token, provider-only egress, redaction과 실행 직후 폐기를 모두 적용한다.
- backend 설정은 공급자의 공식 문서를 사용한다. 예를 들어 GLM backend는
  [Z.AI의 Claude Code 설정 문서](https://docs.z.ai/devpack/tool/claude)를 참조하되 URL이나
  key를 이 매뉴얼 또는 repository에 하드코딩하지 않는다.
- 호스트의 credential store, SSH agent, Git credential helper, browser session, cloud metadata
  endpoint를 격리 runtime에 전달하지 않는다.
- 변경 파일과 stage 후보에 secret scanner를 적용한다. 발견 시 commit하지 않고 token을
  폐기·교체한 뒤 사람에게 보고한다.

### 9.2 로그

- 원본 transcript에는 source와 비밀정보가 포함될 수 있다고 가정한다. 로그는 repository
  밖의 접근 제한된 control 저장소에만 둔다.
- persistence 전에 알려진 token, 인증 header, 환경 값과 사용자 경로를 redaction한다.
  redaction은 완전한 보호가 아니므로 로그 접근 권한도 최소화한다.
- Git stage와 공개 artifact에 `control/logs`, agent transcript, simulator 임시 출력이 들어가지
  않도록 구조와 allowlist 양쪽에서 차단한다.
- 보존 기간을 run 전에 정한다. 기본 권고는 검토 완료 후 7일 이내 폐기이며, 사고 조사나
  조직 정책상 더 필요하면 승인자·목적·만료일을 기록한다.
- HALT 증거를 보존할 때도 필요한 diff, exit code와 redaction된 발췌만 남기고 전체 환경 dump를
  수집하지 않는다.

### 9.3 네트워크

기본 egress는 deny다. 모델 API와 simulator license server 등 실제 필요한 destination만
도메인·port 기준으로 allowlist한다. 에이전트의 임의 web fetch, package install, paste/upload,
Git remote 접근은 별도 사람 승인 없이는 금지한다.

모델 API allowlist는 source 전송 자체에 대한 승인이 아니다. 운영자는 전송할 코드의 데이터
분류와 권리를 확인하고 공급자의 계약·privacy 설정에서 server-side 보존 기간, training 사용,
처리 지역과 DPA 요구를 승인해야 한다. 공급자 측 사본은 이 저장소의 7일 로그 폐기 정책으로
삭제되지 않는다. 요구사항을 확인하거나 강제할 수 없으면 해당 외부 backend로 run하지 않는다.

---

## 10. 종료·예산·사람 개입

### 10.1 강제 예산

run 시작 전에 다음 값을 모두 정한다.

- 전체 반복 수와 연속 무진전 한도
- 반복별 agent turn 한도
- 반복별 wall-clock timeout과 전체 run timeout
- compile/elaborate/simulate 각각의 timeout
- 측정 가능한 경우 token·금액 한도; 공급자가 강제 한도를 제공하지 않으면 wrapper가 사용량을
  보수적으로 집계하고 상한에 도달하기 전에 중단한다.

timeout 시 부모 프로세스만 종료해서는 안 된다. wrapper가 agent와 simulator의 전체 process
tree 종료를 확인하고, 실패하면 격리 runtime 자체를 중지한다. 비용이나 시간을 신뢰성 있게
제한할 수 없는 backend는 무인 run에 사용하지 않는다.

### 10.2 HALT 사유

| HALT 사유 | 의미와 다음 조치 |
|---|---|
| isolation-invalid | host·branch·mount·egress 조건 위반; 실행하지 않고 환경 재구성 |
| protected-modified | 보호 hash·파일형·경로 위반; 자동 복구 없이 증거 검토 |
| out-of-allowlist | 새 파일을 포함한 변경이 허용 범위 밖; 원인 검토 후 clone 폐기 |
| secret-or-license-risk | token 또는 출처·라이선스 위험; commit 금지, 필요 시 token 폐기 |
| agent-blocked | 에이전트가 막힘을 선언; 사람이 오류와 다음 단계를 결정 |
| gate-claim-failed | 자체 통과 주장이 신뢰 verifier에서 실패; 검사 우회 여부 검토 |
| stalled | 진전 없는 반복; 작업 크기·프롬프트·상태 재평가 |
| timed-out | process tree 종료 확인 후 작업 크기와 tool hang 조사 |
| budget-exhausted | 자동 증액 금지; 사람이 추가 비용·시간을 승인할 때만 새 run |
| lock-lost | 동시 작업 가능성; 즉시 중단하고 repository 상태 조사 |

HALT 후 자동 재시작하지 않는다. 운영자가 원인, diff, redaction 로그와 baseline 무결성을
검토하고 새 run을 승인해야 한다.

### 10.3 완료 승인

Phase 5 신뢰 verifier 통과 뒤에도 wrapper는 `human-review-required`로 멈춘다. 사람은 다음을
확인한다.

1. kickoff baseline부터의 전체 diff와 commit별 변경 범위
2. 원본 TB 보존, 매뉴얼 계약, UVM 구조와 회귀 결과
3. 에이전트 작성 실행 스크립트의 내용과 안전성
4. 제3자 코드의 출처·라이선스·NOTICE 및 상표 비제휴 표현
5. secret scan, local path, transcript·생성물 미포함
6. verifier 기록과 예상 transaction·marker 일치

승인한 사람이 별도 절차로 merge/tag/push한다. 자동화에는 원격 push 권한을 주지 않는다.

---

## 11. 구현 전 필수 검증과 DRAFT 해제 조건

구현 순서는 **위협 모델 검토 → disposable fixture → wrapper → verifier → prompt → 실패 주입
시험 → 제한된 파일럿 → 사람 승인**이다. 실제 프로젝트를 첫 시험 대상으로 삼지 않는다.

최소 실패 주입 시험:

1. 보호 tracked 파일 수정, 삭제, 권한 변경
2. 보호 경로 아래 새 untracked 파일 생성
3. allowlist 밖 파일 생성과 기존 파일 수정
4. symlink/junction/reparse point 또는 hardlink/file identity alias를 통한 경계 밖 쓰기
5. 에이전트의 commit, ref, hook 또는 `.git` 조작 시도
6. 정상 wrapper commit과 agent Git 조작을 구분하고 single-parent chain 이탈 탐지
7. 실제 transaction 없이 기대 marker만 `$display`하는 비신뢰 SV
8. 에이전트가 만든 가짜 PASS 로그와 marker 주입
9. `run_xsim.ps1`이 compile을 생략하거나 다른 file list를 사용하는 경우
10. manifest 밖 include, `$system`, DPI/VPI/PLI 또는 file I/O를 통한 verifier sandbox 탈출 시도
11. 오래된 simulator snapshot·로그 재사용 시도
12. token·인증 header·로컬 경로가 source 또는 transcript에 출력되는 경우
13. agent, verifier 및 simulator 자식 프로세스 hang과 timeout 후 process-tree 잔존
14. 두 wrapper의 동시 실행과 실행 중 lock 상실
15. baseline commit·보호 hash·expected count 변조
16. stage 후보에 허용되지 않은 파일이나 생성물이 섞이는 경우
17. Phase 2 skeleton이 정상 허용되고 Phase 3 이후 stub은 거부되는지 확인
18. 총 시간·turn·token·금액 예산 소진과 fail-closed 동작

각 시험은 “위험 동작이 일어나지 않았다”뿐 아니라 올바른 HALT 사유, 무커밋, 증거 보존,
자식 프로세스 종료까지 확인한다. 시험 결과와 wrapper/verifier version hash를 사람이 검토하고,
일회용 비기밀 fixture 파일럿을 통과한 뒤에만 문서 상태 변경을 제안할 수 있다.

**DRAFT / DO NOT RUN 표시는 구현 파일이 생겼다는 이유만으로 제거하지 않는다.** 위 시험과
제한된 파일럿, 보안·라이선스 검토, 운영자 승인이 모두 기록된 후 별도 리뷰에서 제거한다.

---

## 12. 교육적 사용 범위

이 초안은 반복형 에이전트 운용에서 다음 원칙을 토론하고 설계 검토하는 자료로 사용할 수
있다.

- 모델 context 대신 명시적 state와 notes로 인계하기
- 작은 작업과 빠른 feedback으로 backpressure 만들기
- prompt 규칙과 실제 접근 통제를 구분하기
- agent-produced evidence와 trusted verification을 분리하기
- immutable baseline, allowlist, 예산과 사람 승인으로 자동화의 경계 정하기

현재 허용되는 사용은 문서 리뷰, threat modeling과 비실행 의사 코드 검토까지다. 실제 agent나
simulator를 이 설계로 반복 실행하는 것은 11장의 DRAFT 해제 조건을 충족할 때까지 금지한다.
