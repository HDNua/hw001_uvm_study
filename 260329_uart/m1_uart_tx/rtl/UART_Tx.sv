`timescale 1ns/1ps

// =============================================================================
// UART_Tx.sv — UART 송신기 (Transmitter)
//
// -----------------------------------------------------------------------------
// UART (Universal Asynchronous Receiver Transmitter) 개요
// -----------------------------------------------------------------------------
//
// UART는 주로 서로 다른 장치 간 데이터 통신을 위해 사용되는
// 비동기 직렬 통신 프로토콜이며, 그 프로토콜을 구현하는 하드웨어
// 블록도 UART라고 부른다.
//
// 실무적으로는 같은 칩 내부의 AXI/APB 같은 on-chip bus 보다는,
// 칩/보드/PC처럼 물리적으로 떨어진 통신 상대와 적은 선으로 연결할 때
// 더 자연스럽게 등장한다.
//
// 여기서 "장치(device)"는 통신 상대 전체를 뜻하는 넓은 표현이다.
// 상황에 따라 칩 하나일 수도 있고, 보드 하나일 수도 있고, PC 전체일 수도 있다.
//
// UART는 클럭 선 없이 미리 약속한 속도(baud rate)로
// 1비트씩 직렬로 데이터를 주고받는다.
//
// "비동기(Asynchronous)"의 의미:
//   - SPI/I2C처럼 클럭 선을 공유하지 않는다.
//   - 대신 송신측과 수신측이 동일한 baud rate를 사전에 약속한다.
//   - 수신측은 start bit의 하강 엣지를 감지한 뒤, 약속된 간격으로 비트를 샘플링한다.
//
// 이 파일은 UART TX(송신기)만 구현한다.
// 실제 시스템의 반대편에는 Receiver Device 내부의 UART RX가 있어
// start/data/stop 비트를 읽고 다시 1바이트로 조립한다.
// 참고로 tb_top.sv의 monitor는 실제 UART RX가 아니라,
// 그 수신 동작을 흉내 내는 검증용 블록이다.
//
// -----------------------------------------------------------------------------
// 프레임 구조
// -----------------------------------------------------------------------------
//
//  idle  START  D0  D1  D2  D3  D4  D5  D6  D7  STOP  idle
//   1  [  0  ][ LSB                        MSB][  1  ]  1
//
//  - idle  : 전송 없을 때 선은 HIGH(1)를 유지
//  - START : 1비트, 항상 LOW(0). "데이터 전송 시작" 신호
//  - DATA  : 8비트, LSB(D0)부터 MSB(D7) 순서로 전송
//  - STOP  : 1비트, 항상 HIGH(1). "이 1바이트 프레임 전송 완료" 신호
//            선을 idle 상태로 복귀시킨다.
//
// 수신측 샘플링 타이밍:
//   START 하강 엣지 감지 → 1.5 baud 후 D0 샘플 → 이후 1 baud 간격으로 D1~D7 샘플
//
// -----------------------------------------------------------------------------
// Baud Rate 와 CLKS_PER_BIT
// -----------------------------------------------------------------------------
//
//  baud rate    = 초당 전송 비트 수
//  CLKS_PER_BIT = 시스템 클럭 주파수 / baud rate
//
//  예) CLK_FREQ=50MHz, BAUD_RATE=115200
//      CLKS_PER_BIT = 50_000_000 / 115_200 = 434 사이클
//      → 1비트를 434 클럭 사이클 동안 유지
//
// -----------------------------------------------------------------------------
// FSM 동작 흐름
// -----------------------------------------------------------------------------
//
//  IDLE ──(i_TxValid=1)──▶ START ──(baud 완료)──▶ DATA ──(8비트 완료)──▶ STOP ──▶ IDLE
//
//  - IDLE  : o_TxSerial=1, o_TxReady=1. i_TxValid 감지 시 i_TxData를 r_ShiftReg에 래치
//  - START : o_TxSerial=0 (start bit). CLKS_PER_BIT 카운트 후 DATA 로 전이
//  - DATA  : r_ShiftReg[r_BitIdx] 를 o_TxSerial 에 출력 (LSB first).
//            CLKS_PER_BIT 마다 r_BitIdx 증가. 7 완료 시 STOP 으로 전이
//  - STOP  : o_TxSerial=1 (stop bit). CLKS_PER_BIT 카운트 후 IDLE 복귀, o_TxReady=1
//
// -----------------------------------------------------------------------------
// 파라미터
// -----------------------------------------------------------------------------
//   CLK_FREQ  : 시스템 클럭 주파수 (Hz, 기본 50MHz)
//   BAUD_RATE : 전송 속도 (기본 115200)
//
// -----------------------------------------------------------------------------
// 네이밍 규칙 (0_ai/0_global/manuals/RTL_Coding_Conventions.md 참조)
// -----------------------------------------------------------------------------
//   i_Clk / i_Rsn       : clock 숫자를 모를 때
//   i_Clk### / i_Rsn### : clock 숫자를 알 때 (예: i_Clk50 / i_Rsn50)
//   i_*                  : 입력 포트 ( i_TxValid )
//   o_*                  : 출력 포트 ( o_TxReady )
//   r_*                  : reg value
//   w_*                  : wire value
// =============================================================================

module UART_Tx #(
    parameter int CLK_FREQ  = 50_000_000,
    parameter int BAUD_RATE = 115_200
) (
    input  logic       i_Clk,
    input  logic       i_Rsn,

    // CPU 인터페이스
    input  logic [7:0] i_TxData,    // 전송할 1바이트 데이터
    input  logic       i_TxValid,   // 1사이클 pulse: 전송 시작 요청
    output logic       o_TxReady,   // HIGH: 새 데이터 수신 가능 (idle 상태)

    // 직렬 출력
    output logic       o_TxSerial   // UART TX 직렬 출력 선 (idle=1)
);

    // -------------------------------------------------------------------------
    // Baud rate 분주: 1비트를 유지할 클럭 사이클 수
    // -------------------------------------------------------------------------
    localparam int CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;
    localparam int BAUD_CNT_W   = (CLKS_PER_BIT > 1) ? $clog2(CLKS_PER_BIT) : 1;
    localparam logic [BAUD_CNT_W-1:0] BAUD_CNT_LAST = BAUD_CNT_W'(CLKS_PER_BIT - 1);

    // -------------------------------------------------------------------------
    // FSM 상태 정의
    // -------------------------------------------------------------------------
    typedef enum logic [2:0] {
        IDLE  = 3'd0,   // 대기. 선 idle(1), 새 전송 요청 감시
        START = 3'd1,   // start bit 출력 (o_TxSerial=0)
        DATA  = 3'd2,   // 데이터 8비트 직렬 출력 (LSB first)
        STOP  = 3'd3    // stop bit 출력 (o_TxSerial=1), idle 복귀
    } state_t;

    // -------------------------------------------------------------------------
    // 내부 레지스터 (r_*)
    // -------------------------------------------------------------------------
    state_t                            r_State;      // 현재 FSM 상태
    logic [BAUD_CNT_W-1:0]            r_BaudCnt;   // baud 클럭 카운터 (0 ~ CLKS_PER_BIT-1)
    logic [2:0]                        r_BitIdx;    // 현재 전송 중인 비트 인덱스 (0~7)
    logic [7:0]                        r_ShiftReg;  // TX 시프트 레지스터 (i_TxData 래치)

    // -------------------------------------------------------------------------
    // FSM + 데이터패스
    // -------------------------------------------------------------------------
    always_ff @(posedge i_Clk or negedge i_Rsn) begin
        if (!i_Rsn) begin
            r_State    <= IDLE;
            r_BaudCnt  <= '0;
            r_BitIdx   <= '0;
            r_ShiftReg <= '0;
            o_TxSerial <= 1'b1;   // 리셋 시 idle 상태로
            o_TxReady  <= 1'b1;
        end else begin
            case (r_State)

                // -------------------------------------------------------------
                // IDLE: 전송 요청 대기
                // i_TxValid pulse 감지 시 데이터 래치 후 START 로 전이
                // -------------------------------------------------------------
                IDLE: begin
                    r_BaudCnt  <= '0;
                    r_BitIdx   <= '0;
                    if (i_TxValid) begin
                        r_ShiftReg <= i_TxData;   // 전송 데이터 래치
                        o_TxReady  <= 1'b0;      // 전송 중 → 새 요청 불가
                        o_TxSerial <= 1'b1;
                        r_State    <= START;
                    end else begin
                        o_TxReady  <= 1'b1;
                        o_TxSerial <= 1'b1;
                    end
                end

                // -------------------------------------------------------------
                // START: start bit (LOW) 출력
                // CLKS_PER_BIT 사이클 유지 후 DATA 로 전이
                // -------------------------------------------------------------
                START: begin
                    o_TxSerial <= 1'b0;
                    if (r_BaudCnt == BAUD_CNT_LAST) begin
                        r_BaudCnt <= '0;
                        r_State   <= DATA;
                    end else begin
                        r_BaudCnt <= r_BaudCnt + 1;
                    end
                end

                // -------------------------------------------------------------
                // DATA: 8비트 직렬 출력 (LSB first)
                // r_BitIdx 0→7 순서로 r_ShiftReg 비트를 1비트씩 출력
                // 마지막 비트(7) 완료 후 STOP 으로 전이
                // -------------------------------------------------------------
                DATA: begin
                    o_TxSerial <= r_ShiftReg[r_BitIdx];
                    if (r_BaudCnt == BAUD_CNT_LAST) begin
                        r_BaudCnt <= '0;
                        if (r_BitIdx == 3'd7) begin
                            r_BitIdx <= '0;
                            r_State  <= STOP;
                        end else begin
                            r_BitIdx <= r_BitIdx + 1;
                        end
                    end else begin
                        r_BaudCnt <= r_BaudCnt + 1;
                    end
                end

                // -------------------------------------------------------------
                // STOP: stop bit (HIGH) 출력
                // CLKS_PER_BIT 사이클 유지 후 IDLE 로 복귀, o_TxReady=1
                // -------------------------------------------------------------
                STOP: begin
                    o_TxSerial <= 1'b1;
                    if (r_BaudCnt == BAUD_CNT_LAST) begin
                        r_BaudCnt <= '0;
                        r_State   <= IDLE;
                        o_TxReady <= 1'b1;
                    end else begin
                        r_BaudCnt <= r_BaudCnt + 1;
                    end
                end

                default: r_State <= IDLE;

            endcase
        end
    end

endmodule
