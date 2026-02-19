// LLM数据拆分模块
// 处理超过64B的访问请求，拆分为多个64B进行处理
module llm_data_split (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    
    // 输入信号
    input logic [CACHELINE_SIZE-1:0] in_data,
    input logic in_valid,
    output logic in_ready,
    input logic [7:0] req_size,
    input logic [OFFSET_WIDTH-1:0] offset,
    
    // 输出信号
    output logic [CHI_DATA_WIDTH-1:0] out_data,
    output logic out_valid
);
    
    // 导入参数
    import llm_params::*;
    
    // 内部信号
    logic [1:0] split_state;
    logic [CHI_DATA_WIDTH-1:0] data_segment;
    
    // 状态定义
    localparam IDLE = 2'b00;
    localparam SPLIT_FIRST = 2'b01;
    localparam SPLIT_SECOND = 2'b10;
    
    // 数据拆分逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            split_state <= IDLE;
            out_valid <= 1'b0;
            in_ready <= 1'b1;
        end else begin
            case (split_state)
                IDLE:
                    if (in_valid && in_ready) begin
                        if (req_size > CACHELINE_SIZE) begin
                            // 需要拆分：处理第一个64B
                            data_segment <= in_data[CHI_DATA_WIDTH-1:0];
                            out_valid <= 1'b1;
                            split_state <= SPLIT_SECOND;
                            in_ready <= 1'b0;
                        end else begin
                            // 不需要拆分：直接输出
                            data_segment <= in_data[CHI_DATA_WIDTH-1:0];
                            out_valid <= 1'b1;
                            split_state <= IDLE;
                        end
                    end else begin
                        out_valid <= 1'b0;
                    end
                
                SPLIT_SECOND:
                    if (out_valid) begin
                        // 处理第二个64B
                        data_segment <= in_data[CACHELINE_SIZE-1:CHI_DATA_WIDTH];
                        out_valid <= 1'b1;
                        split_state <= IDLE;
                        in_ready <= 1'b1;
                    end else begin
                        out_valid <= 1'b0;
                    end
                
                default:
                    split_state <= IDLE;
            endcase
        end
    end
    
    // 输出数据
    assign out_data = data_segment;
    
endmodule