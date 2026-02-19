// LLM PCQ（调度处理模块）
// 负责调度处理来自cmd_ctrl的命令
module llm_pcq (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    
    // 配置接口
    input logic [PRIORITY_WIDTH-1:0] req_priority,
    input logic [4:0] pcq_threshold,
    output logic pcq_congestion,
    output logic out_of_order_en,
    
    // 与cmd_ctrl的接口
    input logic [CHI_ADDR_WIDTH-1:0] pcq_addr,
    input logic [CHI_DATA_WIDTH-1:0] pcq_data,
    input logic [7:0] pcq_size,
    input logic pcq_valid,
    input logic pcq_snp,
    input logic [3:0] pcq_type,
    input logic [31:0] pcq_pld,
    input logic [PRIORITY_WIDTH-1:0] pcq_priority,
    output logic pcq_ready,
    
    // 与data_ctrl的接口
    output logic [CHI_ADDR_WIDTH-1:0] dc_addr,
    output logic [CHI_DATA_WIDTH-1:0] dc_data,
    output logic [7:0] dc_size,
    output logic dc_valid,
    output logic dc_snp,
    output logic [3:0] dc_type,
    output logic [31:0] dc_pld,
    output logic [PRIORITY_WIDTH-1:0] dc_priority,
    input logic dc_ready,
    
    // 与其他模块的接口
    output logic [CHI_ADDR_WIDTH-1:0] curr_addr,
    output logic [CHI_DATA_WIDTH-1:0] curr_data,
    output logic [7:0] curr_size,
    output logic curr_snp,
    output logic [3:0] curr_type,
    output logic [31:0] curr_pld,
    output logic [PRIORITY_WIDTH-1:0] curr_priority,
    output logic curr_valid,
    input logic curr_ready
);
    
    // 导入参数
    import llm_params::*;
    
    // PCQ队列深度
    parameter int PCQ_DEPTH = 32;
    parameter int PCQ_PTR_WIDTH = $clog2(PCQ_DEPTH);
    
    // PCQ队列结构
    typedef struct packed {
        logic [CHI_ADDR_WIDTH-1:0] addr;
        logic [CHI_DATA_WIDTH-1:0] data;
        logic [7:0] size;
        logic snp;
        logic [3:0] type;
        logic [31:0] pld;
        logic [PRIORITY_WIDTH-1:0] priority;
        logic [PCQ_PTR_WIDTH-1:0] seq_id;
        logic valid;
    } pcq_entry_t;
    
    // PCQ队列
    pcq_entry_t pcq_queue [PCQ_DEPTH];
    logic [PCQ_PTR_WIDTH-1:0] wr_ptr;
    logic [PCQ_PTR_WIDTH-1:0] rd_ptr;
    logic [PCQ_PTR_WIDTH:0] count;
    logic [PCQ_PTR_WIDTH-1:0] seq_id_counter;
    logic pcq_full;
    logic pcq_empty;
    
    // 乱序执行相关
    logic [PCQ_PTR_WIDTH-1:0] exec_ptr;
    logic [PCQ_PTR_WIDTH-1:0] commit_ptr;
    logic [PCQ_DEPTH-1:0] exec_mask;
    logic [PCQ_DEPTH-1:0] commit_mask;
    
    // 内部状态
    logic [2:0] state;
    logic [2:0] next_state;
    
    // 状态定义
    localparam IDLE = 3'b000;
    localparam ENQUEUE = 3'b001;
    localparam SCHEDULE = 3'b010;
    localparam EXECUTE = 3'b011;
    localparam COMMIT = 3'b100;
    localparam WAIT_READY = 3'b101;
    
    // 计算PCQ状态
    assign pcq_full = (count == PCQ_DEPTH);
    assign pcq_empty = (count == 0);
    assign pcq_ready = !pcq_full;
    assign pcq_congestion = (count >= pcq_threshold);
    assign out_of_order_en = 1'b1; // 默认启用乱序执行
    
    // 寻找最高优先级的命令
    function automatic [PCQ_PTR_WIDTH-1:0] find_highest_priority();
        logic [PRIORITY_WIDTH-1:0] max_priority;
        logic [PCQ_PTR_WIDTH-1:0] max_priority_ptr;
        
        max_priority = '0;
        max_priority_ptr = '0;
        
        for (int i = 0; i < PCQ_DEPTH; i++) begin
            if (pcq_queue[i].valid && (pcq_queue[i].priority > max_priority) && !exec_mask[i]) begin
                max_priority = pcq_queue[i].priority;
                max_priority_ptr = i;
            end
        end
        
        return max_priority_ptr;
    endfunction
    
    // 状态机逻辑
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            wr_ptr <= 0;
            rd_ptr <= 0;
            exec_ptr <= 0;
            commit_ptr <= 0;
            count <= 0;
            seq_id_counter <= 0;
            exec_mask <= '0;
            commit_mask <= '0;
            // 初始化队列
            for (int i = 0; i < PCQ_DEPTH; i++) begin
                pcq_queue[i] <= '0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE:
                    if (pcq_valid && !pcq_full) begin
                        // 入队
                        pcq_queue[wr_ptr].addr <= pcq_addr;
                        pcq_queue[wr_ptr].data <= pcq_data;
                        pcq_queue[wr_ptr].size <= pcq_size;
                        pcq_queue[wr_ptr].snp <= pcq_snp;
                        pcq_queue[wr_ptr].type <= pcq_type;
                        pcq_queue[wr_ptr].pld <= pcq_pld;
                        pcq_queue[wr_ptr].priority <= pcq_priority;
                        pcq_queue[wr_ptr].seq_id <= seq_id_counter;
                        pcq_queue[wr_ptr].valid <= 1'b1;
                        wr_ptr <= wr_ptr + 1;
                        count <= count + 1;
                        seq_id_counter <= seq_id_counter + 1;
                    end
                
                ENQUEUE:
                    if (pcq_valid && !pcq_full) begin
                        // 入队
                        pcq_queue[wr_ptr].addr <= pcq_addr;
                        pcq_queue[wr_ptr].data <= pcq_data;
                        pcq_queue[wr_ptr].size <= pcq_size;
                        pcq_queue[wr_ptr].snp <= pcq_snp;
                        pcq_queue[wr_ptr].type <= pcq_type;
                        pcq_queue[wr_ptr].pld <= pcq_pld;
                        pcq_queue[wr_ptr].priority <= pcq_priority;
                        pcq_queue[wr_ptr].seq_id <= seq_id_counter;
                        pcq_queue[wr_ptr].valid <= 1'b1;
                        wr_ptr <= wr_ptr + 1;
                        count <= count + 1;
                        seq_id_counter <= seq_id_counter + 1;
                    end
                
                SCHEDULE:
                    if (!pcq_empty) begin
                        // 调度最高优先级的命令
                        exec_ptr <= find_highest_priority();
                        exec_mask[exec_ptr] <= 1'b1;
                    end
                
                EXECUTE:
                    if (dc_ready) begin
                        // 执行完成，标记为可提交
                        commit_mask[exec_ptr] <= 1'b1;
                        exec_mask[exec_ptr] <= 1'b0;
                    end
                
                COMMIT:
                    if (commit_mask[commit_ptr]) begin
                        // 顺序提交
                        commit_mask[commit_ptr] <= 1'b0;
                        pcq_queue[commit_ptr].valid <= 1'b0;
                        commit_ptr <= commit_ptr + 1;
                        count <= count - 1;
                    end
                
                default:
                    // 其他状态
                    ;
            endcase
        end
    end
    
    // 下一状态逻辑
    always_comb begin
        next_state = state;
        case (state)
            IDLE:
                if (pcq_valid && !pcq_full) begin
                    next_state = ENQUEUE;
                end else if (!pcq_empty) begin
                    next_state = SCHEDULE;
                end
            
            ENQUEUE:
                next_state = SCHEDULE;
            
            SCHEDULE:
                next_state = EXECUTE;
            
            EXECUTE:
                if (dc_ready) begin
                    next_state = COMMIT;
                end
            
            COMMIT:
                if (!pcq_empty) begin
                    next_state = SCHEDULE;
                end else begin
                    next_state = IDLE;
                end
            
            default:
                next_state = IDLE;
        endcase
    end
    
    // 输出信号逻辑
    always_comb begin
        // 默认值
        dc_valid = 1'b0;
        curr_valid = 1'b0;
        
        case (state)
            SCHEDULE:
                if (!pcq_empty) begin
                    // 选择最高优先级的命令执行
                    dc_addr = pcq_queue[exec_ptr].addr;
                    dc_data = pcq_queue[exec_ptr].data;
                    dc_size = pcq_queue[exec_ptr].size;
                    dc_snp = pcq_queue[exec_ptr].snp;
                    dc_type = pcq_queue[exec_ptr].type;
                    dc_pld = pcq_queue[exec_ptr].pld;
                    dc_priority = pcq_queue[exec_ptr].priority;
                    dc_valid = 1'b1;
                    
                    curr_addr = pcq_queue[exec_ptr].addr;
                    curr_data = pcq_queue[exec_ptr].data;
                    curr_size = pcq_queue[exec_ptr].size;
                    curr_snp = pcq_queue[exec_ptr].snp;
                    curr_type = pcq_queue[exec_ptr].type;
                    curr_pld = pcq_queue[exec_ptr].pld;
                    curr_priority = pcq_queue[exec_ptr].priority;
                    curr_valid = 1'b1;
                end
            
            EXECUTE:
                if (dc_ready) begin
                    dc_valid = 1'b0;
                    curr_valid = 1'b0;
                end
            
            default:
                dc_valid = 1'b0;
                curr_valid = 1'b0;
        endcase
    end
    
endmodule