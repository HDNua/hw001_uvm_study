# Pure TB → UVM 변환 매뉴얼

> [!IMPORTANT]
> **적용 범위·비제휴 고지:** 이 문서는 `hw001` 저장소의 교육·실험용 운영 가이드이며
> UVM 표준, 시뮬레이터, 또는 여기서 언급하는 AI 도구 제공사의 공식 문서가 아니다.
> 어떤 기관·벤더와도 제휴·인증·추천 관계를 의미하지 않는다.

이 저장소에서 사람과 AI 에이전트가 pure SystemVerilog testbench를 UVM testbench로
구조 변환할 때 쓰는 **repo-specific 규칙서**다. 기준 프로필은 UART TX, 단일 clock/reset,
단일 active agent, in-order expected/actual 비교, AMD Vivado/XSim 2025.2이다.
다중 interface·passive agent·out-of-order 응답·CDC·register model·다른 시뮬레이터에는
아키텍처와 게이트를 별도로 설계해야 하며, 이 문서를 범용 UVM 표준으로 취급하지 않는다.

이 레포의 `260329_uart/m1_uart_tx/` m01~m15가 이 매뉴얼의 살아있는 예제다.
특히 **m15_uvm_minimal은 이 프로필의 구조·코드 참조 예제**다. 관용구는 m15에서
시작하되, 대상 DUT의 승인된 contract와 원본 TB의 행위에 맞게 검토한다.
m15의 PASS나 이 매뉴얼 준수가 DUT·TB의 완전한 정확성을 자동으로 보증하지는 않는다.

---

## 0. 이 문서를 읽는 에이전트와의 계약

너의 임무: 기존 pure TB의 **관측 가능한 검증 행위를 보존**하면서 구조만 UVM으로 바꾸고,
원본의 결함·미검사 영역·사양 모순은 `verification_deficit_report.md`에 분리해 남기는 것.
변환 중 새로운 검증 기능을 섞거나 타이밍 프로토콜을 조용히 개선하지 않는다.
필요한 개선은 구조 변환 완료 후 별도 변경·검증 단위로 수행한다.

절대 규칙:

1. **계획을 새로 세우지 않는다.** 5장의 레시피를 Phase 0부터 순서대로 수행한다.
2. **한 Phase에서 한 종류의 변경만 한다.** 여러 Phase의 작업을 한 번에 하지 않는다.
3. **검증 게이트를 통과하기 전에는 다음 Phase로 넘어가지 않는다.**
   게이트는 "컴파일 성공"이 아니라 "시뮬레이션 실행 + 로그 정량 확인"이다.
4. **타이밍/프로토콜 코드를 추측해 창작하지 않는다.** ready 대기, 비트 샘플링 시점 같은
   코드는 원본 TB와 승인된 DUT contract에서 근거를 추출해 이식한다.
   원본은 **변환 baseline**이지 자동으로 정답인 oracle이 아니다. 사양과의 모순이나
   기존 검증 공백은 deficit report에 기록하고 사람의 판정 전에 임의로 고치지 않는다.
5. **막히면 추측으로 우회하지 않는다.** 막힌 지점, 시도한 것, 상세 로그의 로컬 위치를
   보고하고 멈춘다. 공개 노트에는 비밀값·사용자명·절대경로·내부 URL을 복사하지 않는다.
6. **로그 마커 문자열을 임의로 바꾸지 않는다.** 검증 스크립트가 문자열을 정확히 센다.
7. **원본 실패의 severity를 낮추지 않는다.** 즉시 중단해야 하는 `$fatal`·구성 실패는
   `` `uvm_fatal ``로, 해당 트랜잭션/케이스 실패는 `` `uvm_error ``로 의도를 보존한다.
8. **마커 개수를 동등성 증명으로 삼지 않는다.** 개수는 누락·항(hang)·연결 오류를 찾는
   진단 증거이며, 데이터·타이밍·오류 검출력은 독립 oracle·차등 트레이스·부정 시험으로
   별도 확인한다.

---

## 1. 기준 프로필의 목표 아키텍처

아래는 **UART TX 단일 active agent·in-order profile**의 참조 구조다.
입·출력 에이전트가 여러 개이거나 응답이 out-of-order이면 transaction ID,
predictor/reference model, matching 정책, passive agent 구성을 DUT contract에 맞게 추가한다.

```text
uart_tx_test (uvm_test)
└── uart_tx_env (uvm_env)
    ├── uart_tx_agent (uvm_agent)
    │   ├── uart_tx_sequencer ◄── uart_tx_sequence (uvm_sequence)
    │   ├── uart_tx_driver    ──► DUT (virtual interface로 구동)
    │   └── uart_tx_monitor   ◄── DUT (virtual interface로 관측)
    └── uart_tx_scoreboard (uvm_scoreboard)
        ├── expected_imp ◄── env.expected_ap ◄── sequence가 publish
        └── actual_imp   ◄── monitor.ap
```

| 역할 | 하는 일 | 하지 않는 일 |
|---|---|---|
| seq_item | 트랜잭션 1건의 데이터 포장 | 타이밍, 비교 |
| sequence | stimulus 생성, expected 분배 | DUT 핀 접근 |
| sequencer | sequence ↔ driver 중개 | 데이터 생성/소비 |
| driver | item을 받아 DUT 핀 구동 | 판정, expected 생성 |
| monitor | DUT 핀 관측, actual item publish | 판정, stimulus |
| scoreboard | expected/actual 비교, 집계 | 데이터 생성, 핀 접근 |
| agent | sequencer/driver/monitor 생성·연결 | 데이터 경로 관여 |
| env | agent/scoreboard 생성, analysis 연결 | 케이스 시나리오 |
| test | 케이스 시나리오, sequence 기동, 종료 | 핀 접근 |

---

## 2. 변환 사전 — pure 구조물을 무엇으로 바꾸는가

| pure TB 구조물 | UVM 치환 | 참조 예제 파일 (m15 프로필) | 내부 동작 이해용 중간 단계 |
|---|---|---|---|
| `initial` 블록의 직접 핀 구동 | `uvm_driver`의 `run_phase` + `drive_item()` | `uvc/uart_tx/uart_tx_driver.sv` | m02(task 분리) |
| 구동/관측 순차 실행 | component별 `run_phase` 자동 병렬 실행 | — (phase가 대신함) | m03(fork/join) |
| 관측 코드 안의 pass/fail 판정 | `uvm_scoreboard` + analysis imp | `uvc/uart_tx/uart_tx_scoreboard.sv` | m04(scoreboard 분리) |
| 공유 변수 + event 전달 | analysis port/imp의 `write()` 호출 | `uart_tx_monitor.sv`, `uart_tx_scoreboard.sv` | m05(queue), m11(mailbox), m14(수제 analysis port) |
| payload 배열 직접 참조 | `uvm_sequence`의 `body()` + `start_item/finish_item` | `uvc/uart_tx/uart_tx_sequence.sv` | m06~m07(sequence/expected 분리) |
| 평탄한 TB 구조 | `uvm_test`/`uvm_env`/`uvm_agent` 계층 | `uart_tx_test.sv`, `uart_tx_env.sv`, `uart_tx_agent.sv` | m08(역할 task 계층) |
| DUT 포트 직접 접근 | `interface` + `virtual interface` + `uvm_config_db` | `uvc/uart_tx/uart_tx_if.sv`, `tb/top/tb_top_v15.sv` | m09(interface 도입) |
| raw 데이터(byte 등) 전달 | `uvm_sequence_item` 클래스 | `uvc/uart_tx/uart_tx_seq_item.sv` | m09(item wrapper), m11(typed mailbox) |
| TB 파일 하나에 전부 | package + `` `include `` UVC 파일 구조 | `uvc/uart_tx/uart_tx_pkg.sv` | m10(파일 분리) |
| `new()` 직접 생성, 핸들 주입 | factory `type_id::create` + `build_phase` | 모든 m15 component | m12(class + constructor) |
| driver가 sequencer 직접 참조 | 내장 `seq_item_port`의 `get_next_item/item_done` | `uart_tx_driver.sv` | m13(수제 seq_item_port) |
| monitor가 scoreboard 직접 호출 | `uvm_analysis_port` → `uvm_analysis_imp` | `uart_tx_monitor.sv`, `uart_tx_env.sv` | m14(수제 analysis port) |
| `$display` | `` `uvm_info(ID, msg, UVM_LOW) `` | 모든 m15 파일 | — |
| `$fatal`/`$error` 판정 | severity 보존: 중단 필요 → `` `uvm_fatal ``, 케이스 실패 → `` `uvm_error `` | `uart_tx_scoreboard.sv`, 각 component `build_phase` | — |
| `$finish` 종료 | `run_test()` + `phase.raise_objection/drop_objection` | `uart_tx_test.sv`, `tb_top_v15.sv` | — |

원칙 — **커리큘럼은 경로가 아니라 자료실이다.** m01~m15 사다리를 변환 경로로 따라가지 않는다.
m11의 mailbox나 m13~m14의 수제 port bridge 같은 중간 산출물은 UVM 내부 동작을
가르치기 위해서만 존재하는 코드이며, 변환 작업에서 이를 작성하는 것은 곧 버릴 코드를
만드는 것이다. 실전 변환에서는 pure TB에서 **곧바로 UVM 구조(m15 형태)로** 간다.
변환 작업에서 커리큘럼의 역할은 두 가지뿐이다:
m15는 **기준 프로필의 시작 참조**, m02~m14는 "이 UVM 기능이 내부에서 뭘 하는지" 막혔을 때
펼치는 **해설서**(9장 색인). 예외는 단 하나 — 원본이 스파게티라 행위 추출이
안 될 때의 전처리(Phase 0.5)에서만 m02~m08을 경로로 빌려 쓴다.

이 레포의 교육용 관행: expected item을 sequence가 만들어 env의 `expected_ap`로 publish한다
(`uart_tx_sequence.sv`의 `set_expected_port()`). 이는 고정 stimulus와 단순 in-order UART 결과의
ownership 이동을 보여주기 위한 프로필 선택이며 **UVM 표준이 강제하는 단일 방식이 아니다**.
실무에서는 입력 monitor + predictor/reference model, protocol model, 독립 scoreboard 등 여러 구성을 쓴다.
대상이 외부 응답·가변 latency·out-of-order·side effect를 갖는다면 이 레포 방식을 기계적으로
복사하지 말고, 승인된 DUT contract에서 expected 생성 주체와 독립성을 정한다.

---

## 3. 목표 파일 구조 템플릿

DUT 이름이 `<dut>`일 때 (이 레포에서는 `uart_tx`):

```text
<stage>/
├── sim/
│   └── run_xsim.ps1          # 컴파일→시뮬→로그 정량 검사 (6장)
├── tb/
│   ├── test/
│   │   └── <dut>_test.sv
│   └── top/
│       └── tb_top.sv         # clock/reset, interface, DUT, run_test()만
└── uvc/
    └── <dut>/
        ├── <dut>_if.sv
        ├── <dut>_pkg.sv      # 아래 순서로 `include
        ├── <dut>_seq_item.sv
        ├── <dut>_sequence.sv
        ├── <dut>_sequencer.sv
        ├── <dut>_driver.sv
        ├── <dut>_monitor.sv
        ├── <dut>_scoreboard.sv
        ├── <dut>_agent.sv
        └── <dut>_env.sv
```

package의 `` `include `` 순서는 의존성 순서를 따른다 (`uart_tx_pkg.sv` 참조):
seq_item → sequence → sequencer → driver → monitor → scoreboard → agent → env → test.
package 첫머리에 `import uvm_pkg::*;`와 `` `include "uvm_macros.svh" ``를 둔다.

네이밍은 `0_ai/0_global/manuals/RTL_Coding_Conventions.md`를 따른다
(`i_`/`o_`/`r_`/`w_` 신호, `I_` 인스턴스, 한국어 주석).

---

## 4. 필수 관용구 카드 — 실수가 잦은 것만

각 항목의 완전한 문맥은 괄호 안 m15 파일에서 복사한다.

**object와 component의 utils/new 시그니처가 다르다** (`uart_tx_seq_item.sv` vs `uart_tx_driver.sv`):

```systemverilog
// object (seq_item, sequence)
`uvm_object_utils(uart_tx_seq_item)
function new(string name = "uart_tx_seq_item");
    super.new(name);
endfunction

// component (driver, monitor, ...)
`uvm_component_utils(uart_tx_driver)
function new(string name, uvm_component parent);
    super.new(name, parent);
endfunction
```

**이 프로필의 object/component 생성은 factory로** (`uart_tx_agent.sv`의 `build_phase`):

```systemverilog
driver = uart_tx_driver::type_id::create("driver", this);   // component: 부모 전달
seq    = uart_tx_sequence::type_id::create("seq");          // object: 이름만
```

**virtual interface는 config_db로** — top에서 `run_test()` 전에 set, component는 `build_phase`에서 get 실패 시 즉시 fatal (`tb_top_v15.sv`, `uart_tx_driver.sv`):

```systemverilog
// top
uvm_config_db #(virtual uart_tx_if)::set(null, "*", "vif", I_UART_TxIf);
run_test("uart_tx_test");

// component build_phase
if (!uvm_config_db #(virtual uart_tx_if)::get(this, "", "vif", vif))
    `uvm_fatal("NOVIF", "uart_tx_driver requires virtual uart_tx_if")
```

**test의 run_phase는 objection으로 감싼다** (`uart_tx_test.sv`) — 없으면 0시간에 종료된다:

```systemverilog
task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    // ... 케이스 실행 ...
    phase.drop_objection(this);
endtask
```

**driver 루프는 3콜 고정** (`uart_tx_driver.sv`) — `item_done()`을 빼먹으면 두 번째 item에서 hang:

```systemverilog
forever begin
    seq_item_port.get_next_item(req);
    drive_item(req);
    seq_item_port.item_done();
end
```

**scoreboard가 imp를 2개 받으면 suffix 선언이 필요하다** (`uart_tx_scoreboard.sv`):

```systemverilog
`uvm_analysis_imp_decl(_expected)   // write_expected() 콜백 생성
`uvm_analysis_imp_decl(_actual)     // write_actual() 콜백 생성
```

**이 UART/XSim 프로필의 DUT 구동은 vif에 NBA(`<=`)로** 한다
(`uart_tx_driver.sv`의 `drive_item`). 이 예제는 posedge 기준으로 clocking block 없이 구동하므로
원본의 scheduling을 보존하기 위해 blocking(`=`)으로 바꾸지 않는다.
다른 DUT에서는 원본 TB의 clocking block·modport·edge/skew 계약을 우선하며,
NBA를 모든 프로토콜에 일괄 적용하지 않는다.

---

## 5. 변환 레시피

각 Phase는 [작업 → 참조 → 게이트 → 흔한 실수] 순서로 기술한다.
게이트의 실행·검사 방법은 6장의 공통 규격을 따른다.
Phase 0.5는 조건부 단계다 — 수행 조건에 해당할 때만 실행하고, 아니면 건너뛴다.
변환은 한 세션에 끝나지 않는 것을 전제한다: Phase 하나가 세션 하나의 단위이며,
세션 간 상태는 대화 기억이 아니라 **변환 노트 파일**로 인계한다.

### Phase 0 — 원본 분석과 baseline 확보

작업:
1. 원본 pure TB를 그대로 컴파일·시뮬레이션하고 raw 로그를
   `sim/out/conversion_baseline/baseline.log`로 저장한다. 실행 전 `git check-ignore`로
   이 경로가 무시되는지 확인한다. 대상이 현재 `sim/out/` 패턴 밖이면
   먼저 target-specific `.gitignore`를 추가하고, raw 로그를 커밋하지 않는다.
2. 변환 노트(`conversion_notes.md`)를 만들고 원본 코드에서 다음 다섯 가지를 찾아 기록한다.
   각 항목에 원본 파일의 줄 범위를 적는다.
   - **구동 프로토콜**: DUT 입력을 언제 어떻게 바꾸는가 (예: ready 대기 → data/valid 인가 → 1클럭 후 valid 해제)
   - **관측 프로토콜**: DUT 출력을 언제 샘플링하는가 (예: start bit 하강 엣지 → 1.5 baud 대기 → 비트 중앙 샘플링)
   - **판정 규칙**: 무엇과 무엇을 비교하며 pass 조건이 무엇인가
   - **종료 조건**: 시뮬레이션이 언제 끝나는가
   - **케이스 목록**: 몇 개의 시나리오를 몇 건의 트랜잭션으로 돌리는가
3. `verification_deficit_report.md`를 만들고 아래를 따로 기록한다.
   - 승인된 사양/DUT contract와 원본 TB의 모순
   - 원본이 검사하지 않는 타이밍·오류·리셋·파라미터 영역
   - 기존 FAIL·flaky·timeout 케이스와 재현 여부
   - expected와 actual이 같은 데이터/함수에 의존하는 oracle coupling
   - 독립 oracle·부정 시험·coverage 부족으로 아직 증명하지 못한 항목
4. 공개 가능한 `conversion_notes.md`와 `verification_deficit_report.md`에는 repo-relative 경로만 쓴다.
   사용자명·홈/드라이브 절대경로·호스트·라이선스 서버·토큰·내부 URL·고객 payload는
   제거하거나 일반화한다. 상세 원문이 필요하면 ignore된
   `sim/out/conversion_private/`에 두고 공개 노트에는 요약만 남긴다.

게이트: 원본 시뮬레이션이 PASS로 재현되고, 변환 노트에 다섯 항목이 모두 기록되어 있으며,
deficit report가 존재한다. raw 자료는 ignore되고 공개 노트에는 민감 값이 없다.
원본이 PASS하지 않으면 **변환을 시작하지 않고 보고한다**.

흔한 실수: 원본을 안 돌려보고 코드만 읽고 시작하는 것. baseline 없이는 이후 게이트의
비교 기준이 없다. 반대로 baseline PASS를 사양 정확성으로 오인해 deficit report를 생략하는 것도 오류다.

### Phase 0.5 — (조건부) pure SV 안에서 역할 분리 전처리

수행 조건: Phase 0에서 다섯 항목의 행위 추출이 **실패할 때만** 수행한다 —
원본이 initial 블록 하나에 구동·관측·판정이 뒤엉킨 스파게티라서
"이 줄이 driver인지 monitor인지"를 특정할 수 없는 경우다.
행위 추출이 됐다면 이 Phase는 건너뛰고 Phase 1로 간다.

원칙: **패러다임 점프(SV→UVM)와 얽힘 해제(스파게티→역할 분리)를 동시에 하지 않는다.**
같은 패러다임 안의 리팩토링은 행위 보존을 baseline 비교로 즉시 검증할 수 있지만,
둘을 섞으면 게이트가 실패했을 때 원인이 구조 변경인지 이식 실수인지 구분할 수 없다.

작업:
1. UVM 없이, 원본 TB 안에서 구동/관측/판정 코드를 task로 분리한다.
   목표 형태는 m08_role_split이다: send/recv task 추출(m02) → fork 병렬화(m03) →
   판정 분리(m04) → 역할 task 계층(m08) 순서로, **행위 추출이 가능해지는
   수준까지만** 간다. m08 전 단계에서 추출이 되면 거기서 멈춘다.
2. 코드 이동과 task 추출만 한다. 타이밍, 판정 규칙, 로그 내용은 바꾸지 않는다.
3. 분리가 끝나면 Phase 0으로 돌아가 변환 노트의 다섯 항목을 다시 추출한다.

참조: `m02_task`~`m08_role_split`의 tb_top 파일 헤더 주석이
"무엇을 왜 분리하는가"를 단계별로 설명한다.
커리큘럼 전반부가 변환 **경로**에 기여하는 유일한 지점이 이 Phase다 (2장 원칙의 예외).

게이트: 시뮬레이션 결과가 baseline과 동일(같은 PASS 로그, 같은 트랜잭션 수),
그리고 Phase 0의 다섯 항목이 이제 추출된다.

흔한 실수: 이 단계에서 UVM 요소(class, interface, `uvm_*`)를 미리 넣는 것.
"어차피 바꿀 거니까"라며 타이밍 코드를 정리하는 것(규칙 4 위반).
필요 이상으로 진행하는 것 — 이 Phase의 목적은 구조 개선이 아니라 행위 추출이다.

### Phase 1 — interface 도입

작업:
1. DUT 핀 묶음을 `<dut>_if.sv` interface로 감싼다. clock/reset은 interface 포트로 받는다.
2. top에서 interface를 인스턴스하고 DUT 포트를 interface 신호로 연결한다.
3. 원본 TB 코드는 아직 그대로 두되, 핀 접근만 interface 경유로 바꾼다.

참조: `m15_uvm_minimal/uvc/uart_tx/uart_tx_if.sv`, `tb_top_v15.sv`의 DUT 연결부.
interface 도입 개념은 m09가 origin이다.

게이트: 컴파일 통과 + 시뮬레이션 결과가 baseline과 동일(같은 PASS 로그, 같은 트랜잭션 수).

흔한 실수: 이 단계에서 신호 이름까지 바꾸는 것. 구조 변경과 이름 변경을 섞지 않는다.

### Phase 2 — UVM 스켈레톤 구축

작업:
1. 3장의 파일 구조를 만든다. seq_item은 데이터 필드만, 나머지 component는
   utils 매크로 + new + 빈 phase만 가진 **빈 껍데기**로 만든다.
2. agent/env의 `build_phase`/`connect_phase`에서 하위 생성과 port 연결을 완성한다
   (연결할 로직이 아직 없어도 port 연결은 지금 한다).
3. 새 top을 만든다: clock/reset + interface + DUT + `config_db::set` + `run_test()`.
   원본 TB 파일은 삭제하지 말고 남겨둔다 (Phase 3~4에서 코드를 복사해올 원본이다).
4. test의 `run_phase`는 objection을 잡고 reset 해제만 기다렸다 끝나게 한다.

참조: m15의 모든 파일. 이 Phase는 m15의 UART/XSim 구조를 시작점으로 삼고
대상 DUT contract에 맞지 않는 구성은 제거·대체한 뒤, DUT 고유 로직은 아직 비워두는 작업이다.

게이트: `-L uvm` 컴파일 통과 + 시뮬레이션에서
component 계층 build/connect 로그가 나오고 `UVM_ERROR : 0`, `UVM_FATAL : 0`으로 종료.
트랜잭션은 아직 0건이어야 정상이다.

흔한 실수: 스켈레톤 단계에서 로직까지 같이 이식하는 것(규칙 2 위반).
objection 누락으로 0시간 종료(4장 카드 참조) — 이 단계에서 가장 자주 나온다.

### Phase 3 — stimulus 경로 이식 (sequence → sequencer → driver)

작업:
1. 변환 노트의 **구동 프로토콜** 코드를 원본 TB에서 driver의 `drive_item()`으로 복사한다.
   핀 접근을 `vif.` 경유로 치환하는 것 외에는 수정하지 않는다.
2. sequence의 `body()`에서 payload를 item으로 포장해 `start_item/finish_item`으로 보낸다.
3. test에서 케이스 1개(원본의 첫 시나리오)만 sequence로 기동한다.
4. 로그 마커를 넣는다: `[SEQ] sent item/expected:`, `[DRV] driving req:` (6장 규약).

참조: `uart_tx_sequence.sv`, `uart_tx_driver.sv`, `uart_tx_test.sv`의 `run_case`.

게이트: 시뮬레이션에서 `[SEQ]`와 `[DRV]` 마커 수가 케이스의 트랜잭션 수와 정확히 일치,
`UVM_ERROR : 0`, `UVM_FATAL : 0`. 이는 stimulus 경로의 구조·종료 진단이며
monitor가 없으므로 기능 동등성 판정은 아직 하지 않는다.

흔한 실수: driver 타이밍을 "더 좋게" 고치는 것(규칙 4 위반).
`item_done()` 누락 hang(4장 카드). sequence를 `start()`하지 않아 DRV 로그가 0건인 것.

### Phase 4 — 관측·판정 경로 이식 (monitor → scoreboard, expected)

작업:
1. 변환 노트의 **관측 프로토콜** 코드를 monitor의 `run_phase`로 복사한다.
   캡처 결과를 item으로 포장해 `ap.write(item)`한다.
2. 변환 노트의 **판정 규칙**을 scoreboard의 `write_actual()` 비교 로직으로 옮긴다.
3. sequence가 expected item을 `expected_ap.write()`로 publish한다 (2장 고유 관행 참조).
4. 로그 마커를 넣는다: `[MON] captured item:`, `[SB] expected item:`, `[SB] PASS:`,
   `[SB] RESULT: pass=N fail=0`.
5. 같은 stimulus를 원본 TB와 UVM TB에 입력하고, 가능한 최소 단위의 정규화 trace
   (요청·응답·시간 또는 cycle)를 비교한다. trace 추출이 불가능하면 사유를 deficit report에 남긴다.
6. sequence가 만든 expected와 독립된 oracle(승인 사양의 assertion/reference function,
   원본의 독립 판정기, 또는 사람이 승인한 golden trace) 중 하나로 첫 케이스를 교차 확인한다.

참조: `uart_tx_monitor.sv`, `uart_tx_scoreboard.sv`, `uart_tx_env.sv`,
`uart_tx_sequence.sv`의 expected publish 부분.

게이트: 케이스 1개 기준으로 `[SEQ]`=`[DRV]`=`[MON]`=`[SB] PASS:` 마커 수가 모두
트랜잭션 수와 일치, `[SB] RESULT: pass=N fail=0` 출력, `UVM_ERROR : 0`, `UVM_FATAL : 0`.
추가로 정규화 trace 또는 독립 oracle의 교차 확인을 통과한다.
**여기서 baseline과의 행위 보존 증거가 처음 생기지만, 마커 개수나 자체 scoreboard PASS만으로
완전한 기능 동등성을 증명했다고 선언하지 않는다.**

흔한 실수: monitor 샘플링 타이밍 재발명(규칙 4 위반).
expected/actual imp에 `` `uvm_analysis_imp_decl `` 누락(4장 카드).
scoreboard가 비교 외의 일(핀 접근, 데이터 생성)을 하는 것.

### Phase 5 — 케이스 이식과 최종 검증 자동화

작업:
1. 원본의 나머지 케이스를 모두 test로 이식한다. 케이스 시작/종료 마커를 넣는다.
2. `run_xsim.ps1`을 작성한다: `m15_uvm_minimal/sim/run_xsim.ps1`을 복사해
   기대 카운트(케이스 수, 트랜잭션 수, PASS 수)만 이 DUT에 맞게 바꾼다.
3. 스크립트를 실행해 전 진단 게이트를 통과시킨다.
4. 운영자가 소유하고 변환 에이전트가 수정할 수 없는 trusted verifier로
   컴파일·엘라보레이션·시뮬레이션을 다시 실행한다(6장).
5. 최소 1개의 통제된 부정 시험/결함 주입을 수행한다. 예: UART stop bit 오류,
   payload 비트 변조, ready 고정. 원본 TB와 UVM TB가 승인된 결함을 의도대로 탈락시키는지 비교한다.
   실제 RTL을 수정하지 말고 임시 mutation/fixture를 격리된 실행에서 사용한다.

게이트: `run_xsim.ps1`이 예외 없이 완주하고, trusted verifier의 독립 재실행이 같은 결과를 내며,
부정 시험이 의도대로 실패한다. `run_xsim.ps1`은 필수 후보 게이트이지
에이전트와 독립된 최종 판정자가 아니다.
추가로 baseline과 대조: 원본이 검증하던 케이스 수·트랜잭션 수·판정 항목과
가능한 정규화 trace가 새 TB에 보존됐음을 변환 노트에 표로 기록한다 (누락 = 실패).
deficit report의 미해결 항목은 숨기지 않고 잔여 위험으로 인계한다.

흔한 실수: 컴파일만 통과시키고 스크립트의 로그 검사를 지우거나 완화하는 것.
기대 카운트를 로그에 맞춰 역으로 고치는 것 — 카운트는 **변환 노트의 케이스 목록**에서 나와야 한다.

---

## 6. 검증 게이트 공통 규격

검증 증거는 아래 다섯 층으로 쌓는다. Phase 2~3처럼 아직 monitor/oracle가 없는 단계는
해당 Phase에 명시된 구조 진단만 수행하되, **Phase 5 완료는 다섯 층을 모두 요구**한다.

1. **컴파일·엘라보레이션·시뮬레이션** (XSim 기준, `sim/out/`에서 실행):

```powershell
xvlog -sv -L uvm -i <uvc_dir> -i <test_dir> <rtl.sv> <if.sv> <pkg.sv> <top.sv>
xelab TB_Top -L uvm --timescale 1ns/1ps -debug typical -s <snapshot>
xsim <snapshot> -tclbatch run_xsim.tcl -log sim_xsim.log
```

2. **로그 정량 진단** — 마커 문자열을 정확히 센다. 마커 규약:

| 마커 | 찍는 곳 | 기대 수 |
|---|---|---|
| `[SEQ] sent item/expected:` | sequence body | 총 트랜잭션 수 |
| `[DRV] driving req:` | driver drive_item | 총 트랜잭션 수 |
| `[MON] captured item:` | monitor 캡처 직후 | 총 트랜잭션 수 |
| `[SB] expected item:` | scoreboard write_expected | 총 트랜잭션 수 |
| `[SB] PASS:` | scoreboard 비교 성공 | 총 트랜잭션 수 |
| `[SB] RESULT: pass=N fail=0` | scoreboard report_case | 케이스 수 |
| `UVM_ERROR : 0` / `UVM_FATAL : 0` | UVM report summary | 각 1회 존재 |

위 카운트는 reset/drop 없는 단순 in-order profile의 기본값이다. reset abort, 필터링,
retry, 다중 채널이 있으면 역할별 기대값을 DUT contract와 Phase 0 노트에서 따로 정하고
모든 경로의 개수를 인위적으로 같게 맞추지 않는다.

`UVM_ERROR`/`UVM_FATAL` 검사는 "0이 있다"와 "1 이상이 없다"를 **둘 다** 확인한다
(`m15_uvm_minimal/sim/run_xsim.ps1:57-65`가 정확한 구현 예).
마커 카운트는 경로 누락·중복·항·종료 실패를 찾는 **진단**이다.
같은 로직이 expected와 actual을 함께 잘못 만들거나 고정 문자열을 출력해도 개수는 맞을 수 있으므로,
개수 일치만으로 데이터·타이밍·프로토콜 동등성을 선언하지 않는다.

3. **baseline·trace 대조** — 마커 카운트의 기준값은 Phase 0 변환 노트의 케이스 목록이다.
   로그에서 관측된 수를 기준값으로 삼는 역산을 금지한다. 같은 stimulus/seed로 실행한
   원본·UVM TB의 정규화 transaction trace와 종료·PASS/FAIL 결과를 비교한다.

4. **독립 oracle·부정 시험** — sequence expected와 독립된 사양 assertion/reference model/
   승인 golden trace 중 하나로 결과를 교차 검사한다. 그리고 통제된 결함을 주입해
   게이트가 PASS만 하는 것이 아니라 실제로 잘못된 DUT/TB를 탈락시키는지 확인한다.

5. **trusted verifier 재실행** — 변환 에이전트가 수정할 수 없는 운영자/
   CI 소유 runner가 시뮬레이터를 직접 실행한다. 에이전트가 작성한 `run_xsim.ps1`과
   그 스크립트가 생성한 로그만을 독립 판정자로 신뢰하지 않는다.
   변환된 SystemVerilog도 비신뢰 입력일 수 있으므로 verifier는 자격 증명·불필요한 network가
   없는 일회용 sandbox에서 실행하고, 승인된 source/include/dependency closure만 read-only로
   제공하며 새 output만 writable로 둔다. `$system`, DPI/VPI/PLI, 임의 file/network I/O는
   명시적으로 검토·허용하지 않은 한 거부한다.
   trusted verifier는 네이티브 명령의 exit code, 새 run ID/로그 신선도, compile/elaboration/simulation 완주,
   error/fatal 요약, 정규화 결과를 스스로 확인한다. 실행기와 기준값은 변환 대상 디렉터리 밖에 두고
   승인된 변경 절차로만 갱신한다.

---

## 7. 금지 목록

1. 레시피 순서 변경, Phase 건너뛰기, 여러 Phase 동시 진행.
2. 원본 TB·승인된 DUT contract의 근거 없이 타이밍/프로토콜/판정 코드를 새로 작성하는 것.
3. 시뮬레이션 없이 "컴파일 통과"만으로 완료 선언.
4. 검증 스크립트의 검사 항목 삭제·완화, 기대 카운트의 로그 역산.
5. 로그 마커 문자열 임의 변경.
6. `$finish` 직접 호출 (objection으로 종료한다).
7. `#지연`으로 race를 덮는 것. UART 기준 프로필은 clock 엣지 + NBA,
   다른 프로필은 승인된 clocking/scheduling 계약으로 구동한다.
8. config_db `get` 실패를 조용히 넘기는 것 (즉시 `` `uvm_fatal ``).
9. 변환과 무관한 리팩토링(이름 변경, 스타일 정리, RTL 수정)을 같은 Phase에 섞는 것.
10. 원본 TB 파일을 Phase 5 완료·보고 전에 삭제하는 것.
11. 즉시 중단해야 하는 원본 `$fatal`·구성 실패를 `` `uvm_error ``로 낮추는 것.
12. 마커 카운트 일치나 자체 scoreboard PASS만으로 기능 동등성·검증 완전성을 선언하는 것.
13. 변환 에이전트가 수정할 수 있는 스크립트·로그·기준값만으로 최종 판정하는 것.
14. raw baseline/로그/비정제 노트를 커밋하거나 외부 에이전트에 전송하는 것.

---

## 8. 완료 정의 (Definition of Done)

- [ ] Phase 0~5의 게이트를 모두 통과했다 (Phase 0.5를 수행한 경우 그 게이트 포함).
- [ ] `run_xsim.ps1`이 로그 정량 검사 포함 예외 없이 완주한다.
- [ ] 원본 TB의 모든 케이스·트랜잭션·판정 항목이 새 TB에 존재함을 변환 노트 추적표로 확인했다.
- [ ] 원본·UVM TB의 정규화 trace 또는 승인된 독립 oracle로 행위 보존을 교차 확인했다.
- [ ] 최소 1개의 통제된 부정 시험/결함 주입을 원본·UVM TB가 의도대로 탈락시켰다.
- [ ] 에이전트가 수정할 수 없는 trusted verifier가 시뮬레이션·결과 판정을 독립 재실행했다.
- [ ] `UVM_ERROR : 0`, `UVM_FATAL : 0`.
- [ ] 파일 구조가 3장 템플릿과 일치하고 네이밍이 RTL_Coding_Conventions.md를 따른다.
- [ ] 변환 노트에 각 Phase의 게이트 실행 결과(명령, 마커 카운트)가 기록되어 있다.
- [ ] `verification_deficit_report.md`에 사양 모순·미검사 영역·oracle coupling·잔여 위험이 기록되어 있다.
- [ ] raw baseline/상세 노트는 ignore되고, 공개 노트에서 비밀값·사용자명·절대경로·내부 URL을 제거했다.
- [ ] 원본 TB 파일의 보존/삭제 여부를 사람에게 질문으로 남겼다 (임의 삭제 금지).

---

## 9. 커리큘럼 단계 색인 — 언제 어느 단계를 참조하는가

커리큘럼은 경로가 아니라 자료실이다(2장 원칙). 이 표는 어느 순간 어느 서랍을 열지 알려준다.

| 단계 | 가르치는 개념 | 변환 작업 중 참조 시점 |
|---|---|---|
| m01_pure | 클래스 없는 직접 구동·검사 | "원본 pure TB"의 전형 — Phase 0 분석 연습용 |
| m02_task | send/recv task 분리 | Phase 0.5 — 구동/관측 task 추출 |
| m03_fork | driver/monitor 병렬 실행 | Phase 0.5 — 병렬화; run_phase 병렬성이 헷갈릴 때 |
| m04_scoreboard | 판정 분리 | Phase 0.5 — 판정 분리; scoreboard 책임 경계 |
| m05_queue | actual 전달 queue | analysis 경로의 원형 이해 |
| m06_sequence | stimulus ownership 분리 | sequence 책임 경계 |
| m07_expected_path | expected ownership 분리 | 이 레포의 expected 관행 이해 (2장) |
| m08_role_split | test/env/agent 계층 | Phase 0.5의 목표 형태; component 계층이 헷갈릴 때 |
| m09_if_seqitem_sequencer | interface, item, sequencer | Phase 1 개념 배경 |
| m10_uvc_block | UVC 파일 구조 | Phase 2 파일 분리 배경 |
| m11_mailbox_channel | typed mailbox handoff | TLM blocking 전달의 원형 |
| m12_sv_class_uvc | class UVC, virtual if | class 전환 배경 |
| m13_sv_seq_item_port | 수제 get_next_item/item_done | driver handshake 내부 동작 |
| m14_sv_analysis_port | 수제 analysis port/imp | analysis write 콜백 내부 동작 |
| **m15_uvm_minimal** | **실제 UVM 전체** | **UART/XSim 기준 프로필의 구조·관용구 참조 예제** |

---

## 10. 운영자를 위한 메모 — 에이전트에 물리는 방법

에이전트에게 변환 작업을 시킬 때 프롬프트에 아래 한 줄을 포함하거나,
레포 루트의 `CLAUDE.md`/`AGENTS.md`에 같은 문장을 넣어둔다.

> pure TB를 UVM으로 변환할 때는 반드시
> `0_ai/0_global/manuals/UVM_Conversion_Manual.md`를 먼저 전부 읽고,
> 그 레시피의 Phase 순서와 검증 게이트를 따르라.

외부 에이전트/제공자에게는 레포를 통째로 전송하지 않는다. 운영자가 새 export 디렉터리에
**allowlist 기반 clean archive**를 만든다. 기본 allowlist는 이 매뉴얼, 필요한 m15 참조 파일,
승인된 원본 TB/RTL·사양 일부, 정제된 노트만 포함한다.

전송 전에 다음을 모두 확인한다.

1. `.git/`, `.env*`, 자격증명, AI chat/plan/local 파일, `sim/out/`, raw log/baseline,
   파형·coverage 산출물, 호스트 설정, 고객 payload를 제외한다.
2. secret scanner와 수동 검토로 API key/token/private key/credential URL, 전자메일,
   사용자명·절대경로·내부 URL/IP가 없음을 확인한다.
3. 원본 TB/RTL·사양·제3자 코드의 IP 반출 권한, 라이선스, NDA/고객 제약,
   제공자의 데이터 보존·학습·지역 정책을 사람이 승인한다.
4. archive 파일 목록을 다시 출력해 allowlist 밖 파일이 없는지 확인한 뒤 전송한다.

이 검사를 통과하지 못하면 외부 에이전트를 사용하지 않고 로컬/승인된 환경에서 변환한다.
