// LLM CHI从设备模块
// 接收RN接口的AMBA CHI命令请求，并根据req\crsp\srsp\wdata\rdata\snp进行分类处理
module llm_chi_slv (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    input logic clk_en, // 时钟门控使能
    
    // 配置接口
    input logic [1:0] chi_h_version,
    output logic [7:0] snp_resp_latency,
    output logic [31:0] error_report,
    
    // RN CHI-H协议接口
    // 请求通道
    input logic [CHI_ADDR_WIDTH-1:0] rn_chi_req_addr,
    input logic [511:0] rn_chi_req_data, // 扩展至512位，支持256B请求
    input logic [7:0] rn_chi_req_size,
    input logic rn_chi_req_valid,
    input logic [1:0] rn_chi_req_snp, // SNP请求类型（00: 无 / 01: 读 / 10: 写 / 11: 失效）
    input logic [63:0] rn_chi_req_pld, // 扩展至64位，支持CHI-H v2.0
    input logic [PRIORITY_WIDTH-1:0] rn_chi_req_priority,
    output logic rn_chi_req_ready,
    
    // 响应通道
    output logic [511:0] rn_chi_resp_data, // 扩展至512位，支持256B响应
    output logic rn_chi_resp_valid,
    output logic [1:0] rn_chi_resp_error, // 响应错误（00: 无错 / 01:ECC 错 / 10: 协议错 / 11: 超时）
    output logic [63:0] rn_chi_resp_pld, // 扩展至64位，支持CHI-H v2.0
    output logic [PRIORITY_WIDTH-1:0] rn_chi_resp_priority,
    input logic rn_chi_resp_ready,
    
    // 与其他模块的接口
    // 输出到cmd_ctrl的信号
    output logic [CHI_ADDR_WIDTH-1:0] cmd_addr,
    output logic [CHI_DATA_WIDTH-1:0] cmd_data,
    output logic [7:0] cmd_size,
    output logic cmd_valid,
    output logic cmd_snp,
    output logic [3:0] cmd_type, // 0: req, 1: crsp, 2: srsp, 3: wdata, 4: rdata, 5: snp
    output logic [31:0] cmd_pld,
    output logic [PRIORITY_WIDTH-1:0] cmd_priority,
    input logic cmd_ready,
    
    // 输入来自其他模块的信号
    input logic [CHI_DATA_WIDTH-1:0] rsp_data,
    input logic rsp_valid,
    input logic rsp_error,
    input logic [31:0] rsp_pld,
    input logic [PRIORITY_WIDTH-1:0] rsp_priority,
    output logic rsp_ready,
    
    // 与ecc_ctrl的接口
    input logic error_report_valid,
    input logic [31:0] ecc_error_report
);
    
    // 导入参数
    import llm_params::*;
    
    // CHI命令类型定义
    localparam CMD_REQ = 4'b0001;
    localparam CMD_CRSP = 4'b0010;
    localparam CMD_SRSP = 4'b0100;
    localparam CMD_WDATA = 4'b1000;
    localparam CMD_RDATA = 4'b1001;
    localparam CMD_SNP = 4'b1010;
    
    // SNP命令子类型
    localparam SNP_LD = 3'b001;
    localparam SNP_ST = 3'b010;
    localparam SNP_INV = 3'b100;
    
    // 内部状态
    logic [2:0] state;
    logic [2:0] next_state;
    
    // 状态定义
    localparam IDLE = 3'b000;
    localparam RECEIVE_REQ = 3'b001;
    localparam PROCESS_REQ = 3'b010;
    localparam PROCESS_SNP = 3'b011;
    localparam SEND_RSP = 3'b100;
    localparam WAIT_RSP_READY = 3'b101;
    
    // 内部信号
    logic [3:0] decoded_cmd_type;
    logic [7:0] req_type_field;
    logic [2:0] snp_opcode;
    logic [PRIORITY_WIDTH-1:0] decoded_priority;
    logic [31:0] snp_latency_cnt;
    
    // 解码命令类型
    assign req_type_field = rn_chi_req_pld[31:24];
    assign snp_opcode = rn_chi_req_pld[15:13];
    
    // 解码优先级
    always_comb begin
        case (chi_h_version)
            2'b01: // CHI-H v1.0
                decoded_priority = rn_chi_req_pld[7:5];
            2'b10: // CHI-H v2.0
                decoded_priority = rn_chi_req_pld[11:9];
            default:
                decoded_priority = '0;
        endcase
    end
    
    // 解码命令类型
    always_comb begin
        case (req_type_field)
            8'h01: decoded_cmd_type = CMD_REQ;     // 请求
            8'h02: decoded_cmd_type = CMD_CRSP;    // 完成响应
            8'h03: decoded_cmd_type = CMD_SRSP;    // 从响应
            8'h04: decoded_cmd_type = CMD_WDATA;   // 写数据
            8'h05: decoded_cmd_type = CMD_RDATA;   // 读数据
            8'h06: decoded_cmd_type = CMD_SNP;     // SNP请求
            default: decoded_cmd_type = CMD_REQ;
        endcase
    end
    
    // Pld语段处理
    always_comb begin
        case (chi_h_version)
            2'b01: // CHI-H v1.0
                cmd_pld = rn_chi_req_pld[31:0];
            2'b10: // CHI-H v2.0
                cmd_pld = rn_chi_req_pld[63:32]; // 使用高32位作为Pld信息
            default:
                cmd_pld = rn_chi_req_pld[31:0];
        endcase
    end
    
    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            snp_latency_cnt <= '0;
        end else begin
            state <= next_state;
            
            // 统计SNP响应延迟
            if (decoded_cmd_type == CMD_SNP && rn_chi_req_valid) begin
                snp_latency_cnt <= 0;
            end else if (state == PROCESS_SNP) begin
                snp_latency_cnt <= snp_latency_cnt + 1;
            end else if (state == SEND_RSP && decoded_cmd_type == CMD_SNP) begin
                snp_resp_latency <= snp_latency_cnt;
            end
        end
    end
    
    // 下一状态逻辑
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (rn_chi_req_valid) begin
                    if (decoded_cmd_type == CMD_SNP) begin
                        next_state = PROCESS_SNP;
                    end else begin
                        next_state = RECEIVE_REQ;
                    end
                end
            
            RECEIVE_REQ:
                if (cmd_ready) begin
                    next_state = PROCESS_REQ;
                end
            
            PROCESS_REQ:
                if (rsp_valid) begin
                    next_state = SEND_RSP;
                end
            
            PROCESS_SNP:
                // SNP请求快速处理路径
                if (rsp_valid) begin
                    next_state = SEND_RSP;
                end
            
            SEND_RSP:
                if (rn_chi_resp_ready) begin
                    next_state = IDLE;
                end
            
            WAIT_RSP_READY:
                if (rn_chi_resp_ready) begin
                    next_state = IDLE;
                end
            
            default:
                next_state = IDLE;
        endcase
    end
    
    // 输出信号逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // 复位输出信号
            rn_chi_req_ready <= 1'b0;
            rn_chi_resp_valid <= 1'b0;
            rn_chi_resp_error <= 1'b0;
            rn_chi_resp_data <= '0;
            rn_chi_resp_pld <= '0;
            rn_chi_resp_priority <= '0;
            
            cmd_valid <= 1'b0;
            cmd_addr <= '0;
            cmd_data <= '0;
            cmd_size <= '0;
            cmd_snp <= 1'b0;
            cmd_type <= '0;
            cmd_pld <= '0;
            cmd_priority <= '0;
            
            rsp_ready <= 1'b0;
            error_report <= '0;
        end else begin
            // 处理错误报告
            if (error_report_valid) begin
                error_report <= ecc_error_report;
            end
            
            case (state)
                IDLE:
                    if (rn_chi_req_valid) begin
                        // 准备接收请求
                        rn_chi_req_ready <= 1'b1;
                        cmd_valid <= 1'b1;
                        cmd_addr <= rn_chi_req_addr;
                        cmd_data <= rn_chi_req_data;
                        cmd_size <= rn_chi_req_size;
                        cmd_snp <= rn_chi_req_snp;
                        cmd_type <= decoded_cmd_type;
                        cmd_pld <= rn_chi_req_pld;
                        cmd_priority <= decoded_priority;
                    end else begin
                        rn_chi_req_ready <= 1'b0;
                        cmd_valid <= 1'b0;
                    end
                
                RECEIVE_REQ:
                    if (cmd_ready) begin
                        // 请求已被cmd_ctrl接收
                        rn_chi_req_ready <= 1'b0;
                        cmd_valid <= 1'b0;
                    end
                
                PROCESS_REQ:
                    if (rsp_valid) begin
                        // 收到来自其他模块的响应
                        rsp_ready <= 1'b1;
                        rn_chi_resp_valid <= 1'b1;
                        rn_chi_resp_error <= rsp_error;
                        rn_chi_resp_data <= rsp_data;
                        rn_chi_resp_pld <= rsp_pld;
                        rn_chi_resp_priority <= rsp_priority;
                    end else begin
                        rsp_ready <= 1'b0;
                    end
                
                PROCESS_SNP:
                    // SNP请求快速处理
                    if (rsp_valid) begin
                        rsp_ready <= 1'b1;
                        rn_chi_resp_valid <= 1'b1;
                        rn_chi_resp_error <= rsp_error;
                        rn_chi_resp_data <= rsp_data;
                        rn_chi_resp_pld <= rsp_pld;
                        rn_chi_resp_priority <= rsp_priority;
                    end else begin
                        rsp_ready <= 1'b0;
                    end
                
                SEND_RSP:
                    if (rn_chi_resp_ready) begin
                        // 响应已发送
                        rn_chi_resp_valid <= 1'b0;
                        rsp_ready <= 1'b0;
                    end
                
                WAIT_RSP_READY:
                    if (rn_chi_resp_ready) begin
                        rn_chi_resp_valid <= 1'b0;
                    end
                
                default:
                    // 默认状态
                    rn_chi_req_ready <= 1'b0;
                    rn_chi_resp_valid <= 1'b0;
                    cmd_valid <= 1'b0;
                    rsp_ready <= 1'b0;
            endcase
        end
    end
    
endmodule