# Pure TB → UVM 변환 매뉴얼

공용 규칙서 — 사람과 AI 에이전트(Claude, GLM, Codex 등) 공통 적용.
pure SystemVerilog testbench를 UVM testbench로 변환하는 작업은 반드시 이 문서의 절차를 따른다.

이 레포의 `260329_uart/m1_uart_tx/` m01~m15가 이 매뉴얼의 살아있는 예제다.
특히 **m15_uvm_minimal이 목표 형태의 정답 예제**이며, 모든 코드 관용구는 m15에서 복사하는 것을 원칙으로 한다.

---

## 0. 이 문서를 읽는 에이전트와의 계약

너의 임무: 기존 pure TB의 **검증 행위를 그대로 보존**하면서 구조만 UVM으로 바꾸는 것.
새로운 검증 기능을 추가하거나 타이밍 프로토콜을 개선하는 것은 임무가 아니다.

절대 규칙:

1. **계획을 새로 세우지 않는다.** 5장의 레시피를 Phase 0부터 순서대로 수행한다.
2. **한 Phase에서 한 종류의 변경만 한다.** 여러 Phase의 작업을 한 번에 하지 않는다.
3. **검증 게이트를 통과하기 전에는 다음 Phase로 넘어가지 않는다.**
   게이트는 "컴파일 성공"이 아니라 "시뮬레이션 실행 + 로그 정량 확인"이다.
4. **타이밍/프로토콜 코드는 창작하지 않는다.** ready 대기, 비트 샘플링 시점 같은
   코드는 원본 TB에서 그대로 복사한다. 원본이 정답이다.
5. **막히면 추측으로 우회하지 않는다.** 막힌 지점, 시도한 것, 에러 로그를 보고하고 멈춘다.
6. **로그 마커 문자열을 임의로 바꾸지 않는다.** 검증 스크립트가 문자열을 정확히 센다.

---

## 1. 목표 아키텍처

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

| pure TB 구조물 | UVM 치환 | 정답 예제 파일 (m15 기준) | 내부 동작 이해용 중간 단계 |
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
| `$fatal`/`$error` 판정 | `` `uvm_error `` 집계 + `UVM_ERROR : 0` 검사 | `uart_tx_scoreboard.sv` | — |
| `$finish` 종료 | `run_test()` + `phase.raise_objection/drop_objection` | `uart_tx_test.sv`, `tb_top_v15.sv` | — |

원칙 — **커리큘럼은 경로가 아니라 자료실이다.** m01~m15 사다리를 변환 경로로 따라가지 않는다.
m11의 mailbox나 m13~m14의 수제 port bridge 같은 중간 산출물은 UVM 내부 동작을
가르치기 위해서만 존재하는 코드이며, 변환 작업에서 이를 작성하는 것은 곧 버릴 코드를
만드는 것이다. 실전 변환에서는 pure TB에서 **곧바로 UVM 구조(m15 형태)로** 간다.
변환 작업에서 커리큘럼의 역할은 두 가지뿐이다:
m15는 **복사 원본**, m02~m14는 "이 UVM 기능이 내부에서 뭘 하는지" 막혔을 때
펼치는 **해설서**(9장 색인). 예외는 단 하나 — 원본이 스파게티라 행위 추출이
안 될 때의 전처리(Phase 0.5)에서만 m02~m08을 경로로 빌려 쓴다.

이 레포 고유 관행: expected item을 sequence가 만들어 env의 `expected_ap`로 publish한다
(`uart_tx_sequence.sv`의 `set_expected_port()`). 업계 표준은 입력측 monitor가 expected를
만드는 것이지만, 변환 대상 프로젝트에 기존 관행이 없다면 **이 레포 방식을 그대로 복사**한다.
예제 코드와 검증 게이트가 모두 이 방식 기준이다.

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

**생성은 항상 factory로** (`uart_tx_agent.sv`의 `build_phase`):

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

**DUT 구동은 vif에 NBA(`<=`)로** (`uart_tx_driver.sv`의 `drive_item`). blocking(`=`)으로 바꾸지 않는다.

---

## 5. 변환 레시피

각 Phase는 [작업 → 참조 → 게이트 → 흔한 실수] 순서로 기술한다.
게이트의 실행·검사 방법은 6장의 공통 규격을 따른다.
Phase 0.5는 조건부 단계다 — 수행 조건에 해당할 때만 실행하고, 아니면 건너뛴다.
변환은 한 세션에 끝나지 않는 것을 전제한다: Phase 하나가 세션 하나의 단위이며,
세션 간 상태는 대화 기억이 아니라 **변환 노트 파일**로 인계한다.

### Phase 0 — 원본 분석과 baseline 확보

작업:
1. 원본 pure TB를 그대로 컴파일·시뮬레이션하고 로그를 `baseline.log`로 저장한다.
2. 변환 노트(`conversion_notes.md`)를 만들고 원본 코드에서 다음 다섯 가지를 찾아 기록한다.
   각 항목에 원본 파일의 줄 범위를 적는다.
   - **구동 프로토콜**: DUT 입력을 언제 어떻게 바꾸는가 (예: ready 대기 → data/valid 인가 → 1클럭 후 valid 해제)
   - **관측 프로토콜**: DUT 출력을 언제 샘플링하는가 (예: start bit 하강 엣지 → 1.5 baud 대기 → 비트 중앙 샘플링)
   - **판정 규칙**: 무엇과 무엇을 비교하며 pass 조건이 무엇인가
   - **종료 조건**: 시뮬레이션이 언제 끝나는가
   - **케이스 목록**: 몇 개의 시나리오를 몇 건의 트랜잭션으로 돌리는가

게이트: 원본 시뮬레이션이 PASS로 재현되고, 변환 노트에 다섯 항목이 모두 기록되어 있다.
원본이 PASS하지 않으면 **변환을 시작하지 않고 보고한다**.

흔한 실수: 원본을 안 돌려보고 코드만 읽고 시작하는 것. baseline 없이는 이후 게이트의 비교 기준이 없다.

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

참조: m15의 모든 파일. 이 Phase는 사실상 m15 구조를 통째로 복사하고
DUT 고유 로직만 비워두는 작업이다.

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
`UVM_ERROR : 0`. (monitor가 없으므로 기능 판정은 아직 없다.)

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

참조: `uart_tx_monitor.sv`, `uart_tx_scoreboard.sv`, `uart_tx_env.sv`,
`uart_tx_sequence.sv`의 expected publish 부분.

게이트: 케이스 1개 기준으로 `[SEQ]`=`[DRV]`=`[MON]`=`[SB] PASS:` 마커 수가 모두
트랜잭션 수와 일치, `[SB] RESULT: pass=N fail=0` 출력, `UVM_ERROR : 0`.
**여기가 baseline과의 기능 동등성이 처음 증명되는 지점이다.**

흔한 실수: monitor 샘플링 타이밍 재발명(규칙 4 위반).
expected/actual imp에 `` `uvm_analysis_imp_decl `` 누락(4장 카드).
scoreboard가 비교 외의 일(핀 접근, 데이터 생성)을 하는 것.

### Phase 5 — 케이스 이식과 최종 검증 자동화

작업:
1. 원본의 나머지 케이스를 모두 test로 이식한다. 케이스 시작/종료 마커를 넣는다.
2. `run_xsim.ps1`을 작성한다: `m15_uvm_minimal/sim/run_xsim.ps1`을 복사해
   기대 카운트(케이스 수, 트랜잭션 수, PASS 수)만 이 DUT에 맞게 바꾼다.
3. 스크립트를 실행해 전 게이트를 통과시킨다.

게이트: `run_xsim.ps1`이 예외 없이 완주한다. 이 스크립트가 곧 최종 게이트다.
추가로 baseline과 대조: 원본이 검증하던 케이스 수·트랜잭션 수·판정 항목이
모두 새 TB에 존재함을 변환 노트에 표로 기록한다 (누락 = 실패).

흔한 실수: 컴파일만 통과시키고 스크립트의 로그 검사를 지우거나 완화하는 것.
기대 카운트를 로그에 맞춰 역으로 고치는 것 — 카운트는 **변환 노트의 케이스 목록**에서 나와야 한다.

---

## 6. 검증 게이트 공통 규격

모든 게이트는 아래 3단계를 전부 수행한다. 어느 하나라도 생략하면 게이트 통과가 아니다.

1. **컴파일·엘라보레이션·시뮬레이션** (XSim 기준, `sim/out/`에서 실행):

```powershell
xvlog -sv -L uvm -i <uvc_dir> -i <test_dir> <rtl.sv> <if.sv> <pkg.sv> <top.sv>
xelab TB_Top -L uvm --timescale 1ns/1ps -debug typical -s <snapshot>
xsim <snapshot> -tclbatch run_xsim.tcl -log sim_xsim.log
```

2. **로그 정량 검사** — 마커 문자열을 정확히 센다. 마커 규약:

| 마커 | 찍는 곳 | 기대 수 |
|---|---|---|
| `[SEQ] sent item/expected:` | sequence body | 총 트랜잭션 수 |
| `[DRV] driving req:` | driver drive_item | 총 트랜잭션 수 |
| `[MON] captured item:` | monitor 캡처 직후 | 총 트랜잭션 수 |
| `[SB] expected item:` | scoreboard write_expected | 총 트랜잭션 수 |
| `[SB] PASS:` | scoreboard 비교 성공 | 총 트랜잭션 수 |
| `[SB] RESULT: pass=N fail=0` | scoreboard report_case | 케이스 수 |
| `UVM_ERROR : 0` / `UVM_FATAL : 0` | UVM report summary | 각 1회 존재 |

`UVM_ERROR`/`UVM_FATAL` 검사는 "0이 있다"와 "1 이상이 없다"를 **둘 다** 확인한다
(`m15_uvm_minimal/sim/run_xsim.ps1:57-65`가 정확한 구현 예).

3. **baseline 대조** — 마커 카운트의 기준값은 Phase 0 변환 노트의 케이스 목록이다.
   로그에서 관측된 수를 기준값으로 삼는 역산을 금지한다.

---

## 7. 금지 목록

1. 레시피 순서 변경, Phase 건너뛰기, 여러 Phase 동시 진행.
2. 원본 TB의 타이밍/프로토콜/판정 코드를 복사하지 않고 새로 작성하는 것.
3. 시뮬레이션 없이 "컴파일 통과"만으로 완료 선언.
4. 검증 스크립트의 검사 항목 삭제·완화, 기대 카운트의 로그 역산.
5. 로그 마커 문자열 임의 변경.
6. `$finish` 직접 호출 (objection으로 종료한다).
7. `#지연`으로 race를 덮는 것. driver는 clock 엣지 기준 + NBA로 구동한다.
8. config_db `get` 실패를 조용히 넘기는 것 (즉시 `` `uvm_fatal ``).
9. 변환과 무관한 리팩토링(이름 변경, 스타일 정리, RTL 수정)을 같은 Phase에 섞는 것.
10. 원본 TB 파일을 Phase 5 완료·보고 전에 삭제하는 것.

---

## 8. 완료 정의 (Definition of Done)

- [ ] Phase 0~5의 게이트를 모두 통과했다 (Phase 0.5를 수행한 경우 그 게이트 포함).
- [ ] `run_xsim.ps1`이 로그 정량 검사 포함 예외 없이 완주한다.
- [ ] 원본 TB의 모든 케이스·트랜잭션·판정 항목이 새 TB에 존재함을 변환 노트 표로 증명했다.
- [ ] `UVM_ERROR : 0`, `UVM_FATAL : 0`.
- [ ] 파일 구조가 3장 템플릿과 일치하고 네이밍이 RTL_Coding_Conventions.md를 따른다.
- [ ] 변환 노트에 각 Phase의 게이트 실행 결과(명령, 마커 카운트)가 기록되어 있다.
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
| **m15_uvm_minimal** | **실제 UVM 전체** | **모든 Phase의 정답 예제 — 코드는 여기서 복사** |

---

## 10. 운영자를 위한 메모 — 에이전트에 물리는 방법

에이전트에게 변환 작업을 시킬 때 프롬프트에 아래 한 줄을 포함하거나,
레포 루트의 `CLAUDE.md`/`AGENTS.md`에 같은 문장을 넣어둔다.

> pure TB를 UVM으로 변환할 때는 반드시
> `0_ai/0_global/manuals/UVM_Conversion_Manual.md`를 먼저 전부 읽고,
> 그 레시피의 Phase 순서와 검증 게이트를 따르라.

이 레포를 통째로 복사해 다른 에이전트(GLM 등)에게 줄 경우, 이 매뉴얼과
`260329_uart/m1_uart_tx/`의 m15(정답 예제) + 원본 TB만 있으면 레시피가 성립한다.
`sim/out/` 산출물은 복사할 필요 없다.
