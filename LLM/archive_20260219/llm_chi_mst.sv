// LLM CHI主设备模块
// 向下游SN接口发起CHI请求，处理miss数据回填
module llm_chi_mst (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    input logic clk_en, // 时钟门控使能
    
    // 配置接口
    input logic [15:0] req_timeout,
    input logic [2:0] max_parallel_req, // 最大并行请求数（1-8）
    output logic [15:0] req_retrans_cnt,
    output logic [15:0] sn_resp_latency,
    
    // 与cmd_ctrl的接口
    input logic [CHI_ADDR_WIDTH-1:0] mst_addr,
    input logic [7:0] mst_size,
    input logic mst_valid,
    input logic mst_snp,
    input logic [PRIORITY_WIDTH-1:0] mst_priority,
    output logic mst_ready,
    
    // SN CHI-H协议接口
    // 请求通道
    output logic [CHI_ADDR_WIDTH-1:0] sn_chi_req_addr,
    output logic [511:0] sn_chi_req_data, // 扩展至512位，支持256B请求
    output logic [7:0] sn_chi_req_size,
    output logic sn_chi_req_valid,
    output logic [1:0] sn_chi_req_snp, // SNP请求类型（00: 无 / 01: 读 / 10: 写 / 11: 失效）
    output logic [63:0] sn_chi_req_pld, // 扩展至64位，支持CHI-H v2.0
    output logic [PRIORITY_WIDTH-1:0] sn_chi_req_priority,
    input logic sn_chi_req_ready,
    
    // 响应通道
    input logic [511:0] sn_chi_resp_data, // 扩展至512位，支持256B响应
    input logic sn_chi_resp_valid,
    input logic [1:0] sn_chi_resp_error, // 响应错误（00: 无错 / 01:ECC 错 / 10: 协议错 / 11: 超时）
    input logic [63:0] sn_chi_resp_pld, // 扩展至64位，支持CHI-H v2.0
    input logic sn_chi_resp_ready,
    
    // 与data_ctrl的接口
    output logic [511:0] fetch_data, // 扩展至512位，支持256B响应
    output logic fetch_valid,
    output logic [1:0] fetch_error, // 扩展至2位错误码
    input logic fetch_ready
);
    
    // 导入参数
    import llm_params::*;
    
    // 最大并行请求数
    parameter int MAX_PARALLEL_REQS = 8;
    
    // 内部状态
    logic [2:0] state;
    logic [2:0] next_state;
    
    // 状态定义
    localparam IDLE = 3'b000;
    localparam PROCESS_REQ = 3'b001;
    localparam SEND_REQ = 3'b010;
    localparam WAIT_RESP = 3'b011;
    localparam PROCESS_RESP = 3'b100;
    localparam SEND_DATA = 3'b101;
    localparam HANDLE_TIMEOUT = 3'b110;
    
    // 请求队列结构
    typedef struct packed {
        logic [CHI_ADDR_WIDTH-1:0] addr;
        logic [7:0] size;
        logic snp;
        logic [PRIORITY_WIDTH-1:0] priority;
        logic [15:0] timeout_cnt;
        logic valid;
    } req_entry_t;
    
    // 请求队列
    req_entry_t req_queue [MAX_PARALLEL_REQS];
    logic [2:0] req_wr_ptr;
    logic [2:0] req_rd_ptr;
    logic [3:0] req_count;
    
    // 响应数据缓存
    logic [511:0] resp_data [MAX_PARALLEL_REQS]; // 扩展至512位，支持256B响应
    logic [MAX_PARALLEL_REQS-1:0] resp_valid;
    logic [MAX_PARALLEL_REQS-1:0] resp_error;
    
    // 内部信号
    logic [CHI_ADDR_WIDTH-1:0] curr_addr;
    logic [7:0] curr_size;
    logic curr_snp;
    logic [PRIORITY_WIDTH-1:0] curr_priority;
    logic [15:0] timeout_counter;
    logic req_timeout_detected;
    
    // 计算待处理请求数
    assign pending_req_count = req_count;
    
    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            req_wr_ptr <= '0;
            req_rd_ptr <= '0;
            req_count <= '0;
            timeout_counter <= '0;
            resp_valid <= '0;
            
            // 初始化请求队列
            for (int i = 0; i < MAX_PARALLEL_REQS; i++) begin
                req_queue[i].valid <= 1'b0;
                resp_data[i] <= '0;
                resp_error[i] <= 1'b0;
            end
        end else begin
            state <= next_state;
            
            // 更新超时计数器
            if (state == WAIT_RESP) begin
                for (int i = 0; i < MAX_PARALLEL_REQS; i++) begin
                    if (req_queue[i].valid) begin
                        req_queue[i].timeout_cnt <= req_queue[i].timeout_cnt + 1;
                        if (req_queue[i].timeout_cnt >= req_timeout) begin
                            req_timeout_detected <= 1'b1;
                        end
                    end
                end
            end
            
            // 处理请求入队
            if (state == PROCESS_REQ && mst_valid && req_count < MAX_PARALLEL_REQS) begin
                req_queue[req_wr_ptr].addr <= mst_addr;
                req_queue[req_wr_ptr].size <= mst_size;
                req_queue[req_wr_ptr].snp <= mst_snp;
                req_queue[req_wr_ptr].priority <= mst_priority;
                req_queue[req_wr_ptr].timeout_cnt <= 0;
                req_queue[req_wr_ptr].valid <= 1'b1;
                req_wr_ptr <= req_wr_ptr + 1;
                req_count <= req_count + 1;
            end
            
            // 处理请求出队
            if (state == PROCESS_RESP && sn_chi_resp_valid) begin
                req_queue[req_rd_ptr].valid <= 1'b0;
                req_rd_ptr <= req_rd_ptr + 1;
                req_count <= req_count - 1;
                resp_data[req_rd_ptr] <= sn_chi_resp_data;
                resp_error[req_rd_ptr] <= sn_chi_resp_error;
                resp_valid[req_rd_ptr] <= 1'b1;
            end
            
            // 处理超时重传
            if (state == HANDLE_TIMEOUT && req_timeout_detected) begin
                // 重新发送超时的请求
                for (int i = 0; i < MAX_PARALLEL_REQS; i++) begin
                    if (req_queue[i].timeout_cnt >= req_timeout) begin
                        req_queue[i].timeout_cnt <= 0;
                    end
                end
                req_timeout_detected <= 1'b0;
            end
        end
    end
    
    // 下一状态逻辑
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (mst_valid && req_count < MAX_PARALLEL_REQS) begin
                    next_state = PROCESS_REQ;
                end else if (req_timeout_detected) begin
                    next_state = HANDLE_TIMEOUT;
                end
            
            PROCESS_REQ:
                next_state = SEND_REQ;
            
            SEND_REQ:
                if (sn_chi_req_ready) begin
                    next_state = WAIT_RESP;
                end
            
            WAIT_RESP:
                if (sn_chi_resp_valid) begin
                    next_state = PROCESS_RESP;
                end else if (req_timeout_detected) begin
                    next_state = HANDLE_TIMEOUT;
                end
            
            PROCESS_RESP:
                next_state = SEND_DATA;
            
            SEND_DATA:
                if (fetch_ready) begin
                    next_state = IDLE;
                end
            
            HANDLE_TIMEOUT:
                next_state = SEND_REQ;
            
            default:
                next_state = IDLE;
        endcase
    end
    
    // 输出信号逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位输出信号
            mst_ready <= 1'b0;
            sn_chi_req_valid <= 1'b0;
            sn_chi_resp_ready <= 1'b0;
            fetch_valid <= 1'b0;
        end else begin
            case (state)
                IDLE:
                    if (mst_valid && req_count < MAX_PARALLEL_REQS) begin
                        mst_ready <= 1'b1;
                    end else begin
                        mst_ready <= 1'b0;
                    end
                
                PROCESS_REQ:
                    mst_ready <= 1'b0;
                
                SEND_REQ:
                    // 向下游SN发送读请求（选择最高优先级的请求）
                    for (int i = 0; i < MAX_PARALLEL_REQS; i++) begin
                        if (req_queue[i].valid) begin
                            sn_chi_req_addr <= req_queue[i].addr;
                            sn_chi_req_data <= '0; // 读请求不需要数据
                            sn_chi_req_size <= req_queue[i].size;
                            sn_chi_req_valid <= 1'b1;
                            sn_chi_req_snp <= req_queue[i].snp;
                            sn_chi_req_pld <= {8'h01, 8'h00, 8'h00, 8'h00}; // 读请求Pld
                            sn_chi_req_priority <= req_queue[i].priority;
                            break;
                        end
                    end
                
                WAIT_RESP:
                    if (sn_chi_req_ready) begin
                        sn_chi_req_valid <= 1'b0;
                    end
                    // 准备接收响应
                    sn_chi_resp_ready <= 1'b1;
                
                PROCESS_RESP:
                    if (sn_chi_resp_valid) begin
                        // 接收来自下游SN的响应
                        sn_chi_resp_ready <= 1'b0;
                    end
                
                SEND_DATA:
                    // 将获取的数据发送给其他模块
                    for (int i = 0; i < MAX_PARALLEL_REQS; i++) begin
                        if (resp_valid[i]) begin
                            fetch_data <= resp_data[i];
                            fetch_valid <= 1'b1;
                            fetch_error <= resp_error[i];
                            resp_valid[i] <= 1'b0;
                            break;
                        end
                    end
                    
                    if (fetch_ready) begin
                        fetch_valid <= 1'b0;
                    end
                
                HANDLE_TIMEOUT:
                    // 超时重传处理
                    sn_chi_req_valid <= 1'b1;
                
                default:
                    // 默认状态
                    mst_ready <= 1'b0;
                    sn_chi_req_valid <= 1'b0;
                    sn_chi_resp_ready <= 1'b0;
                    fetch_valid <= 1'b0;
            endcase
        end
    end
    
endmodule