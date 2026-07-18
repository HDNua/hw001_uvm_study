# RTL 코딩 컨벤션

공용 규칙서 — Claude, Codex, Antigravity 등 모든 AI 도구에 공통 적용

---

## 1. 포트 네이밍

| 종류 | 접두사 | 예시 |
|---|---|---|
| clock | `i_Clk###` | `i_Clk`, `i_Clk50` |
| reset (active low) | `i_Rsn###` | `i_Rsn`, `i_Rsn50` |
| input | `i_` | `i_TxData`, `i_TxValid` |
| output | `o_` | `o_TxReady`, `o_TxSerial` |

- clock 숫자를 모르면 `###`를 생략하여 `i_Clk`, `i_Rsn`으로 사용한다.
- clock 숫자를 알면 `i_Clk50`, `i_Rsn50`처럼 숫자를 붙인다.

## 2. 내부 신호 네이밍

| 종류 | 접두사 | 예시 |
|---|---|---|
| reg value | `r_` | `r_State`, `r_BaudCnt`, `r_ShiftReg` |
| wire value | `w_` | `w_NextState`, `w_Sum` |

## 3. 모듈 및 인스턴스 네이밍

| 종류 | 규칙 | 예시 |
|---|---|---|
| 모듈 이름 | 파스칼 케이스 + 언더스코어 구분 | `UART_Tx`, `I2C_Master` |
| 인스턴스 이름 | `I_` 접두사 | `I_UART_Tx`, `I_I2C_Master` |

## 4. 주석

- 기본적으로 **한국어**로 작성
