`timescale 1ns/1ps

module reset_tb;

    // ============ 参数 ============
    localparam CLK_PERIOD = 10;      // 100 MHz
    localparam RST_HOLD   = 25;      // 复位保持时间

    // ============ 信号 ============
    reg  clk;
    reg  arst_n;
    wire rst_n;

    // ============ DUT ============
    rx_reset u_dut (
        .clk     (clk),
        .arst_n  (arst_n),
        .rst_n   (rst_n)
    );

    // ============ 时钟生成 ============
    initial clk = 1'b0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // ============ 复位激励 ============
    initial begin
        arst_n = 1'b0;                    // 上电即异步复位
        #RST_HOLD;
        arst_n = 1'b1;                    // 异步释放（本模块内部同步）
        #(CLK_PERIOD * 60);               // 等足够长时间观察同步释放
        $display("[%0t] Simulation finished.", $time);
        $stop;
    end

    // ============ 监控 ============
    initial begin
        $display(" time | clk arst_n sync  wcnt  rst_n");
        $display("------+-------------------------------");
        $monitor("%5t |  %b   %b    %b   %2d    %b",
                 $time, clk, arst_n, u_dut.sync, u_dut.wait_count, rst_n);
    end

    // ============ 自动检查 ============
    // 记录 arst_n 释放的时刻，验证 rst_n 在 34 拍后释放
    integer release_time;
    integer release_edge_count;
    reg     arst_n_d;

    always @(posedge clk) begin
        arst_n_d <= arst_n;

        // arst_n 上升沿
        if (arst_n && !arst_n_d) begin
            release_time = $time;
            release_edge_count = 0;
            $display("[%0t] arst_n deasserted. Expect rst_n high after ~34 clk.", $time);
        end

        if (arst_n && !arst_n_d) release_edge_count = 0;
        else if (arst_n)         release_edge_count = release_edge_count + 1;

        // 检查 rst_n 释放时机
        if (rst_n && release_edge_count > 0 && release_edge_count < 34) begin
            $display("[%0t] ERROR: rst_n released too early (%0d clocks).",
                     $time, release_edge_count);
        end
    end

    

endmodule