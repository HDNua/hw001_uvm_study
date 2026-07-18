# hw001 UVM Study

UART TX를 시작으로 RTL 검증 구조를 단계별로 확장하는 학습용 프로젝트입니다. 현재 공개된 첫 단계는 SystemVerilog 테스트벤치가 DUT의 직렬 출력을 직접 비교하는 `m01_pure`입니다.

## 프로젝트 구조

```text
260329_uart/m1_uart_tx/
├── m00_rtl/
│   └── UART_Tx.sv
├── m01_pure/
│   ├── sim/
│   │   ├── run_xsim.ps1
│   │   └── view_xsim.ps1
│   ├── tb/
│   │   └── tb_top_v1.sv
│   └── stage_flow_demo.html
└── uart_tx_demo.html
```

- `m00_rtl`: 단계들이 공통으로 사용하는 UART TX RTL
- `m01_pure`: 클래스나 UVM 없이 작성한 첫 번째 검증 단계
- `uart_tx_demo.html`: UART TX의 동작을 살펴보는 공용 인터랙티브 데모
- `stage_flow_demo.html`: `m01_pure`의 검증 흐름 설명

## 필요 환경

- AMD Vivado/XSim 2025.2 또는 호환 버전
- PowerShell

공식 시뮬레이션 흐름은 XSim 기준입니다. Vivado/XSim이 `PATH`에 없다면 스크립트의 `-VivadoBin` 인수로 실행 파일 디렉터리를 지정할 수 있습니다.
Vivado/XSim은 macOS를 지원하지 않으므로 이 흐름은 Windows 또는 Vivado가 지원되는 Linux 환경에서 실행해야 합니다.

## 시뮬레이션 실행

저장소 루트에서 다음 명령을 실행합니다.

```powershell
cd .\260329_uart\m1_uart_tx\m01_pure\sim
.\run_xsim.ps1
```

Vivado 실행 파일 경로를 직접 지정하는 예시는 다음과 같습니다.

```powershell
$env:VIVADO_BIN = '<xvlog, xelab, xsim이 있는 디렉터리>'
.\run_xsim.ps1 -VivadoBin $env:VIVADO_BIN
```

성공하면 로그에 `PASS: captured=0x48`이 출력됩니다. 파형 데이터와 로그를 포함한 모든 시뮬레이션 산출물은 `sim/out/`에 생성되며 Git에서 제외됩니다.

파형을 GUI에서 열려면 시뮬레이션 완료 후 다음 명령을 실행합니다.

```powershell
.\view_xsim.ps1
```

## 동작 데모

브라우저에서 다음 파일을 직접 열 수 있습니다.

- `260329_uart/m1_uart_tx/uart_tx_demo.html`
- `260329_uart/m1_uart_tx/m01_pure/stage_flow_demo.html`

두 데모는 외부 웹 폰트 없이 로컬 시스템 글꼴만 사용합니다.

## 라이선스

이 프로젝트는 [MIT License](LICENSE)로 배포됩니다.
