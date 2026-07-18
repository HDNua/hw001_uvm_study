# hw001 UVM Study

UART TX를 시작으로 RTL 검증 구조를 단계별로 확장하는 학습용 프로젝트입니다. 직접 구동·검사에서 역할 분리와 queue handoff를 거쳐, `m06_sequence`에서는 stimulus 생성 책임을 sequence로 분리합니다.

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
- `uart_tx_demo.html`: UART TX의 동작을 살펴보는 공용 인터랙티브 데모
- `stage_flow_demo.html`: 공통 템플릿에 단계별 `STAGE` 데이터만 정의하는 검증 흐름 설명

## 필요 환경

- AMD Vivado/XSim 2025.2 또는 호환 버전
- PowerShell

공식 시뮬레이션 흐름은 XSim 기준입니다. Vivado/XSim이 `PATH`에 없다면 스크립트의 `-VivadoBin` 인수로 실행 파일 디렉터리를 지정할 수 있습니다.
Vivado/XSim은 macOS를 지원하지 않으므로 이 흐름은 Windows 또는 Vivado가 지원되는 Linux 환경에서 실행해야 합니다.

## 시뮬레이션 실행

저장소 루트에서 실행할 단계의 `sim` 디렉터리로 이동합니다. 예를 들어 `m06_sequence`는 다음과 같이 실행합니다.

```powershell
cd .\260329_uart\m1_uart_tx\m06_sequence\sim
.\run_xsim.ps1
```

Vivado 실행 파일 경로를 직접 지정하는 예시는 다음과 같습니다.

```powershell
$env:VIVADO_BIN = '<xvlog, xelab, xsim이 있는 디렉터리>'
.\run_xsim.ps1 -VivadoBin $env:VIVADO_BIN
```

성공하면 m06 로그에 sequence queue 5건, driver 구동 5건, scoreboard PASS 5건과 `[SB] RESULT: pass=5 fail=0`이 출력됩니다. 파형 데이터와 로그를 포함한 모든 시뮬레이션 산출물은 `sim/out/`에 생성되며 Git에서 제외됩니다.

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

각 데모는 외부 웹 폰트 없이 로컬 시스템 글꼴만 사용합니다.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포됩니다.
