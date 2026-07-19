# hw001 UVM Study

UART TX를 시작으로 RTL 검증 구조를 단계별로 확장하는 학습용 프로젝트입니다. 직접 구동·검사에서 역할 분리와 순수 SystemVerilog UVC bridge를 거쳐, `m15_uvm_minimal`에서는 실제 UVM object, component, phase와 TLM port로 전환합니다. `m2_uart_tx_verif`부터는 완성된 UVM 구조를 고정하고 자극과 체킹의 깊이를 단계별로 확장합니다.

## 프로젝트 구조

```text
260329_uart/m1_uart_tx/
├── index.html
├── stage_flow.css
├── stage_flow.js
├── m00_rtl/
│   └── UART_Tx.sv
├── m01_pure/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v1.sv
│   └── stage_flow_demo.html
├── m02_task/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v2.sv
│   └── stage_flow_demo.html
├── m03_fork/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v3.sv
│   └── stage_flow_demo.html
├── m04_scoreboard/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v4.sv
│   └── stage_flow_demo.html
├── m05_queue/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v5.sv
│   └── stage_flow_demo.html
├── m06_sequence/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v6.sv
│   └── stage_flow_demo.html
├── m07_expected_path/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v7.sv
│   └── stage_flow_demo.html
├── m08_role_split/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v8.sv
│   └── stage_flow_demo.html
├── m09_if_seqitem_sequencer/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── if/
│   │   │   └── uart_tx_if.sv
│   │   ├── pkg/
│   │   │   └── uart_tx_pkg.sv
│   │   └── top/
│   │       └── tb_top_v9.sv
│   └── stage_flow_demo.html
├── m10_uvc_block/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top_v10.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       ├── uart_tx_agent.sv
│   │       ├── uart_tx_driver.sv
│   │       ├── uart_tx_env.sv
│   │       ├── uart_tx_if.sv
│   │       ├── uart_tx_monitor.sv
│   │       ├── uart_tx_pkg.sv
│   │       ├── uart_tx_scoreboard.sv
│   │       ├── uart_tx_seq_item.sv
│   │       ├── uart_tx_sequence.sv
│   │       └── uart_tx_sequencer.sv
│   └── stage_flow_demo.html
├── m11_mailbox_channel/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top_v11.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       ├── uart_tx_agent.sv
│   │       ├── uart_tx_driver.sv
│   │       ├── uart_tx_env.sv
│   │       ├── uart_tx_if.sv
│   │       ├── uart_tx_monitor.sv
│   │       ├── uart_tx_pkg.sv
│   │       ├── uart_tx_scoreboard.sv
│   │       ├── uart_tx_seq_item.sv
│   │       ├── uart_tx_sequence.sv
│   │       └── uart_tx_sequencer.sv
│   └── stage_flow_demo.html
├── m12_sv_class_uvc/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top_v12.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       ├── uart_tx_agent.sv
│   │       ├── uart_tx_driver.sv
│   │       ├── uart_tx_env.sv
│   │       ├── uart_tx_if.sv
│   │       ├── uart_tx_monitor.sv
│   │       ├── uart_tx_pkg.sv
│   │       ├── uart_tx_scoreboard.sv
│   │       ├── uart_tx_seq_item.sv
│   │       ├── uart_tx_sequence.sv
│   │       └── uart_tx_sequencer.sv
│   ├── stage_flow_demo.html
│   └── uart_tx_uvc_flow_demo.html
├── m13_sv_seq_item_port/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top_v13.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       ├── uart_tx_agent.sv
│   │       ├── uart_tx_driver.sv
│   │       ├── uart_tx_env.sv
│   │       ├── uart_tx_if.sv
│   │       ├── uart_tx_monitor.sv
│   │       ├── uart_tx_pkg.sv
│   │       ├── uart_tx_scoreboard.sv
│   │       ├── uart_tx_seq_item.sv
│   │       ├── uart_tx_seq_item_port.sv
│   │       ├── uart_tx_sequence.sv
│   │       └── uart_tx_sequencer.sv
│   └── stage_flow_demo.html
├── m14_sv_analysis_port/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top_v14.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       ├── uart_tx_agent.sv
│   │       ├── uart_tx_analysis_port.sv
│   │       ├── uart_tx_driver.sv
│   │       ├── uart_tx_env.sv
│   │       ├── uart_tx_if.sv
│   │       ├── uart_tx_monitor.sv
│   │       ├── uart_tx_pkg.sv
│   │       ├── uart_tx_scoreboard.sv
│   │       ├── uart_tx_seq_item.sv
│   │       ├── uart_tx_seq_item_port.sv
│   │       ├── uart_tx_sequence.sv
│   │       └── uart_tx_sequencer.sv
│   └── stage_flow_demo.html
├── m15_uvm_minimal/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top_v15.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       ├── uart_tx_agent.sv
│   │       ├── uart_tx_driver.sv
│   │       ├── uart_tx_env.sv
│   │       ├── uart_tx_if.sv
│   │       ├── uart_tx_monitor.sv
│   │       ├── uart_tx_pkg.sv
│   │       ├── uart_tx_scoreboard.sv
│   │       ├── uart_tx_seq_item.sv
│   │       ├── uart_tx_sequence.sv
│   │       └── uart_tx_sequencer.sv
│   └── stage_flow_demo.html
└── uart_tx_demo.html
```

- `m00_rtl`: 단계들이 공통으로 사용하는 UART TX RTL
- `index.html`: UART TX 동작 데모와 현재 검증 단계를 연결하는 커리큘럼 목차
- `stage_flow.css`, `stage_flow.js`: 모든 단계 흐름 데모가 공유하는 화면 형식과 상호작용
- `m01_pure`: 클래스나 UVM 없이 작성한 첫 번째 검증 단계
- `m02_task`: 구동과 수신 동작을 `send_byte`/`recv_byte` task로 분리한 단계
- `m03_fork`: driver와 monitor를 `fork/join`으로 병렬 실행하는 단계
- `m04_scoreboard`: monitor는 수신, scoreboard는 비교와 결과 집계를 담당하도록 분리한 단계
- `m05_queue`: monitor가 actual을 queue에 넣고 scoreboard가 순서대로 꺼내 비교하는 단계
- `m06_sequence`: sequence가 stimulus를 driver queue에 적재하고 driver가 이를 꺼내 구동하는 단계
- `m07_expected_path`: sequence가 stimulus와 expected queue를 함께 채우고 scoreboard는 비교만 담당하는 단계
- `m08_role_split`: test, env, agent가 하위 task를 계층적으로 관리하도록 상위 역할을 드러내는 단계
- `m09_if_seqitem_sequencer`: 구형 TB hierarchy 안에서 interface와 sequence item wrapper를 도입하고 raw byte를 sequencer put/get API로 전달하는 단계
- `m10_uvc_block`: UART TX 역할 task를 파일별로 분리하고 세 가지 sequence case에서 같은 UVC 블록을 재사용하는 단계
- `m11_mailbox_channel`: queue와 event를 typed mailbox로 치환해 sequence item 객체를 stimulus, expected와 actual 경로에 전달하는 단계
- `m12_sv_class_uvc`: mailbox 경로를 유지하면서 UVC 역할을 plain SystemVerilog class로 전환하고 virtual interface와 constructor로 객체를 연결하는 단계
- `m13_sv_seq_item_port`: class UVC를 유지하면서 driver의 sequencer 직접 참조를 `get_next_item(req)`와 `item_done()`을 제공하는 순수 SV port bridge로 바꾸는 단계
- `m14_sv_analysis_port`: m13의 request/expected 경로를 유지하면서 monitor의 actual 전달을 순수 SV analysis port/imp와 scoreboard `write()` callback으로 바꾸는 단계
- `m15_uvm_minimal`: m14의 역할과 데이터 ownership을 실제 UVM factory, component phase, config DB, seq-item port와 expected/actual analysis port로 치환하는 단계
- `uart_tx_demo.html`: UART TX의 동작을 살펴보는 공용 인터랙티브 데모
- `stage_flow_demo.html`: 공통 템플릿에 단계별 `STAGE` 데이터만 정의하는 검증 흐름 설명

`260329_uart/m2_uart_tx_verif/`는 검증 심화 모듈입니다. m1의 최종 UVM 구조를 복사해 시작하며, 각 단계는 구조가 아니라 자극과 체킹의 깊이를 확장합니다.

```text
260329_uart/m2_uart_tx_verif/
├── index.html
├── stage_flow.css
├── stage_flow.js
├── m00_rtl/
│   └── UART_Tx.sv
├── m01_seed_param/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   ├── test/
│   │   │   └── uart_tx_test.sv
│   │   └── top/
│   │       └── tb_top.sv
│   ├── uvc/
│   │   └── uart_tx/
│   │       └── (m1/m15와 같은 역할 구성)
│   └── stage_flow_demo.html
├── m02_rand_constraint/
│   └── (m01과 같은 단계 구성)
├── m03_corner/
│   └── (m01과 같은 단계 구성)
├── m04_mid_reset/
│   └── (m01과 같은 단계 구성)
└── m05_sva/
    └── (m01과 같은 단계 구성)
```

- `m01_seed_param`: seed와 자극 byte 수를 `+SEED`, `+NUM_BYTES` plusarg로 받아 랜덤 재현성을 확보하고, 실행 스크립트를 고정 건수 일치 대신 경로 불변식 검사로 전환한 단계
- `m02_rand_constraint`: sequence item에 `rand` data·idle_gap과 constraint(dist 가중치, 간격 범위)를 도입하고, random case를 test의 `$urandom_range` 대신 `item.randomize()`로 생성하며 driver가 랜덤 간격으로 구동하는 단계
- `m03_corner`: back-to-back(idle_gap=0)과 전송 중 valid 주입 corner case를 추가해 "busy 중 valid는 조용히 무시·유실된다"는 핸드셰이크 규약을 자극과 체킹으로 확정하고 RTL 헤더에 규약 절을 기록한 단계
- `m04_mid_reset`: test가 프레임 중간에 리셋을 주입하는 case를 추가해 monitor의 capture abort·재동기화, scoreboard의 in-flight expected 제외(on_reset), driver의 리셋 해제 대기까지 복구 경로를 검증하는 단계 (`NUM_BYTES >= 2` 필요)
- `m05_sva`: interface가 idle serial, start/stop bit 폭, ready 프레임 타이밍 속성 4개를 SVA로 상시 감시하고 monitor framing 검사를 error로 승격한 단계. scoreboard(데이터 값)와 SVA(프로토콜 파형)가 상보적 감시망을 이룬다

## 필요 환경

- AMD Vivado/XSim 2025.2 또는 호환 버전과 내장 UVM 라이브러리
- PowerShell

공식 시뮬레이션 흐름은 XSim 기준입니다. Vivado/XSim이 `PATH`에 없다면 스크립트의 `-VivadoBin` 인수로 실행 파일 디렉터리를 지정할 수 있습니다.
Vivado/XSim은 macOS를 지원하지 않으므로 이 흐름은 Windows 또는 Vivado가 지원되는 Linux 환경에서 실행해야 합니다.
`m15_uvm_minimal` 실행 스크립트는 XSim의 내장 UVM 1.2 라이브러리를 `-L uvm`으로 연결합니다.

## 시뮬레이션 실행

저장소 루트에서 실행할 단계의 `sim` 디렉터리로 이동합니다. 예를 들어 `m15_uvm_minimal`은 다음과 같이 실행합니다.

```powershell
cd .\260329_uart\m1_uart_tx\m15_uvm_minimal\sim
.\run_xsim.ps1
```

Vivado 실행 파일 경로를 직접 지정하는 예시는 다음과 같습니다.

```powershell
$env:VIVADO_BIN = '<xvlog, xelab, xsim이 있는 디렉터리>'
.\run_xsim.ps1 -VivadoBin $env:VIVADO_BIN
```

성공하면 m15 로그에 UVM component/TLM 연결, smoke·pattern·random 세 case, sequence·driver·expected analysis·monitor 처리 각 15건과 scoreboard PASS 15건이 출력됩니다. 각 case는 `[SB] RESULT: pass=5 fail=0`으로 끝나고 UVM report summary는 `UVM_ERROR : 0`, `UVM_FATAL : 0`을 보여줍니다. 파형 데이터와 로그를 포함한 모든 시뮬레이션 산출물은 `sim/out/`에 생성되며 Git에서 제외됩니다.

`m2_uart_tx_verif`의 단계는 seed와 자극 byte 수를 스크립트 인자로 받을 수 있습니다.

```powershell
cd .\260329_uart\m2_uart_tx_verif\m01_seed_param\sim
.\run_xsim.ps1 -Seed 7 -NumBytes 8
```

같은 seed는 같은 random payload를 재현합니다. m2 실행 스크립트는 고정 건수 일치 대신 sequence, driver, monitor와 scoreboard PASS 건수의 일치, case별 `fail=0`과 config echo를 검사하고 성공 시 `PASS: seed=... num_bytes=... items=... cases=...`를 출력합니다. case 수는 단계에 따라 다릅니다(m01·m02는 3개, m03은 corner를 더해 4개, m04부터 reset을 더해 5개).

파형을 GUI에서 열려면 시뮬레이션 완료 후 다음 명령을 실행합니다.

```powershell
.\view_xsim.ps1
```

## 동작 데모

브라우저에서 다음 파일을 직접 열 수 있습니다.

- `260329_uart/m1_uart_tx/index.html`
- `260329_uart/m1_uart_tx/uart_tx_demo.html`
- `260329_uart/m1_uart_tx/m01_pure/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m02_task/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m03_fork/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m04_scoreboard/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m05_queue/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m06_sequence/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m07_expected_path/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m08_role_split/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m09_if_seqitem_sequencer/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m10_uvc_block/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m11_mailbox_channel/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m12_sv_class_uvc/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m12_sv_class_uvc/uart_tx_uvc_flow_demo.html`
- `260329_uart/m1_uart_tx/m13_sv_seq_item_port/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m14_sv_analysis_port/stage_flow_demo.html`
- `260329_uart/m1_uart_tx/m15_uvm_minimal/stage_flow_demo.html`
- `260329_uart/m2_uart_tx_verif/index.html`
- `260329_uart/m2_uart_tx_verif/m01_seed_param/stage_flow_demo.html`
- `260329_uart/m2_uart_tx_verif/m02_rand_constraint/stage_flow_demo.html`
- `260329_uart/m2_uart_tx_verif/m03_corner/stage_flow_demo.html`
- `260329_uart/m2_uart_tx_verif/m04_mid_reset/stage_flow_demo.html`
- `260329_uart/m2_uart_tx_verif/m05_sva/stage_flow_demo.html`

각 데모는 외부 웹 폰트 없이 로컬 시스템 글꼴만 사용합니다.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포됩니다.
