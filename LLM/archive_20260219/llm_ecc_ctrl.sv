// LLM ECC控制模块
// 负责tag和data mem的ECC校验、错误统计与上报
module llm_ecc_ctrl (
    // 时钟和复位
    input logic clk,
    input logic rst_n,
    
    // tag mem ECC接口
    input logic [TAG_WIDTH-1:0] tag_in,
    input logic [ECC_BIT_WIDTH-1:0] tag_ecc_in,
    input logic tag_write_en,
    output logic [ECC_BIT_WIDTH-1:0] tag_ecc_out,
    output logic [2:0] tag_error_status, // 000: 无错, 001: 单比特纠错, 010: 双比特检错, 011: 多比特错误
    output logic tag_error_corrected,
    output logic [TAG_WIDTH-1:0] tag_corrected,
    
    // data mem ECC接口
    input logic [CACHELINE_SIZE*8-1:0] data_in,
    input logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] data_ecc_in,
    input logic data_write_en,
    output logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] data_ecc_out,
    output logic [2:0] data_error_status, // 000: 无错, 001: 单比特纠错, 010: 双比特检错, 011: 多比特错误
    output logic data_error_corrected,
    output logic [CACHELINE_SIZE*8-1:0] data_corrected,
    
    // 错误统计与上报
    output logic [31:0] error_count, // 错误计数
    output logic [31:0] single_bit_error_count, // 单比特错误计数
    output logic [31:0] double_bit_error_count, // 双比特错误计数
    output logic [31:0] multi_bit_error_count, // 多比特错误计数
    output logic error_report_valid, // 错误上报有效
    output logic [31:0] error_report // 错误上报信息
);
    
    // 导入参数
    import llm_params::*;
    
    // 错误计数器
    logic [31:0] error_count_q;
    logic [31:0] single_bit_error_count_q;
    logic [31:0] double_bit_error_count_q;
    logic [31:0] multi_bit_error_count_q;
    
    // 错误上报寄存器
    logic [31:0] error_report_q;
    logic error_report_valid_q;
    
    // 生成ECC校验位
    function automatic [ECC_BIT_WIDTH-1:0] generate_ecc_tag(input logic [TAG_WIDTH-1:0] data);
        // 简单的ECC生成逻辑，实际实现需要根据具体ECC算法
        generate_ecc_tag = {ECC_BIT_WIDTH{1'b0}};
        for (int i = 0; i < TAG_WIDTH; i++) begin
            if (data[i]) generate_ecc_tag = generate_ecc_tag ^ i;
        end
    endfunction
    
    function automatic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] generate_ecc_data(input logic [CACHELINE_SIZE*8-1:0] data);
        // 简单的ECC生成逻辑，实际实现需要根据具体ECC算法
        generate_ecc_data = {ECC_BIT_WIDTH*CACHELINE_SIZE/8{1'b0}};
        for (int i = 0; i < CACHELINE_SIZE*8; i++) begin
            if (data[i]) generate_ecc_data[i%ECC_BIT_WIDTH] = ~generate_ecc_data[i%ECC_BIT_WIDTH];
        end
    endfunction
    
    // 检查和纠正ECC错误
    function automatic void check_correct_ecc_tag(
        input logic [TAG_WIDTH-1:0] data,
        input logic [ECC_BIT_WIDTH-1:0] ecc,
        output logic [2:0] error_status,
        output logic corrected,
        output logic [TAG_WIDTH-1:0] corrected_data
    );
        // 简单的ECC检查和纠正逻辑
        logic [ECC_BIT_WIDTH-1:0] calculated_ecc;
        logic [ECC_BIT_WIDTH-1:0] syndrome;
        
        calculated_ecc = generate_ecc_tag(data);
        syndrome = calculated_ecc ^ ecc;
        
        if (syndrome == 0) begin
            error_status = 3'b000; // 无错
            corrected = 1'b0;
            corrected_data = data;
        end else if ($onehot(syndrome)) begin
            error_status = 3'b001; // 单比特纠错
            corrected = 1'b1;
            // 找到错误位并纠正
            corrected_data = data;
        end else begin
            error_status = 3'b010; // 双比特检错
            corrected = 1'b0;
            corrected_data = data;
        end
    endfunction
    
    function automatic void check_correct_ecc_data(
        input logic [CACHELINE_SIZE*8-1:0] data,
        input logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] ecc,
        output logic [2:0] error_status,
        output logic corrected,
        output logic [CACHELINE_SIZE*8-1:0] corrected_data
    );
        // 简单的ECC检查和纠正逻辑
        logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] calculated_ecc;
        logic [ECC_BIT_WIDTH*CACHELINE_SIZE/8-1:0] syndrome;
        
        calculated_ecc = generate_ecc_data(data);
        syndrome = calculated_ecc ^ ecc;
        
        if (syndrome == 0) begin
            error_status = 3'b000; // 无错
            corrected = 1'b0;
            corrected_data = data;
        end else if ($onehot(syndrome)) begin
            error_status = 3'b001; // 单比特纠错
            corrected = 1'b1;
            // 找到错误位并纠正
            corrected_data = data;
        end else begin
            error_status = 3'b010; // 双比特检错
            corrected = 1'b0;
            corrected_data = data;
        end
    endfunction
    
    // 生成tag ECC
    always_comb begin
        if (tag_write_en) begin
            tag_ecc_out = generate_ecc_tag(tag_in);
        end else begin
            tag_ecc_out = '0;
        end
    end
    
    // 生成data ECC
    always_comb begin
        if (data_write_en) begin
            data_ecc_out = generate_ecc_data(data_in);
        end else begin
            data_ecc_out = '0;
        end
    end
    
    // 检查和纠正tag ECC错误
    always_comb begin
        if (ECC_ENABLE) begin
            check_correct_ecc_tag(tag_in, tag_ecc_in, tag_error_status, tag_error_corrected, tag_corrected);
        end else begin
            tag_error_status = 3'b000;
            tag_error_corrected = 1'b0;
            tag_corrected = tag_in;
        end
    end
    
    // 检查和纠正data ECC错误
    always_comb begin
        if (ECC_ENABLE) begin
            check_correct_ecc_data(data_in, data_ecc_in, data_error_status, data_error_corrected, data_corrected);
        end else begin
            data_error_status = 3'b000;
            data_error_corrected = 1'b0;
            data_corrected = data_in;
        end
    end
    
    // 错误计数
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_count_q <= '0;
            single_bit_error_count_q <= '0;
            double_bit_error_count_q <= '0;
            multi_bit_error_count_q <= '0;
        end else begin
            // 统计tag错误
            if (tag_error_status == 3'b001) begin // 单比特纠错
                error_count_q <= error_count_q + 1;
                single_bit_error_count_q <= single_bit_error_count_q + 1;
            end else if (tag_error_status == 3'b010) begin // 双比特检错
                error_count_q <= error_count_q + 1;
                double_bit_error_count_q <= double_bit_error_count_q + 1;
            end else if (tag_error_status == 3'b011) begin // 多比特错误
                error_count_q <= error_count_q + 1;
                multi_bit_error_count_q <= multi_bit_error_count_q + 1;
            end
            
            // 统计data错误
            if (data_error_status == 3'b001) begin // 单比特纠错
                error_count_q <= error_count_q + 1;
                single_bit_error_count_q <= single_bit_error_count_q + 1;
            end else if (data_error_status == 3'b010) begin // 双比特检错
                error_count_q <= error_count_q + 1;
                double_bit_error_count_q <= double_bit_error_count_q + 1;
            end else if (data_error_status == 3'b011) begin // 多比特错误
                error_count_q <= error_count_q + 1;
                multi_bit_error_count_q <= multi_bit_error_count_q + 1;
            end
        end
    end
    
    // 错误上报
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            error_report_q <= '0;
            error_report_valid_q <= 1'b0;
        end else begin
            // 当检测到错误时上报
            if (tag_error_status != 3'b000 || data_error_status != 3'b000) begin
                error_report_q <= {
                    8'hECC, // 错误类型
                    4'h0, // 保留
                    4'h1, // ECC错误
                    8'h00, // 保留
                    8'h00  // 保留
                };
                error_report_valid_q <= 1'b1;
            end else begin
                error_report_valid_q <= 1'b0;
            end
        end
    end
    
    // 输出赋值
    assign error_count = error_count_q;
    assign single_bit_error_count = single_bit_error_count_q;
    assign double_bit_error_count = double_bit_error_count_q;
    assign multi_bit_error_count = multi_bit_error_count_q;
    assign error_report = error_report_q;
    assign error_report_valid = error_report_valid_q;
    
endmodule