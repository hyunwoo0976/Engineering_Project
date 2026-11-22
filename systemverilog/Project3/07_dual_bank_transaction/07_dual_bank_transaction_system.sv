interface account_if(input logic clk);
    logic reset;
    logic valid;
    logic [2:0]cmd;
    logic [1:0] src_id;
    logic [1:0] dst_id;
    logic [15:0]amount;

    logic result_valid;
    logic success;          
    logic [2:0]error_code;
    logic [15:0]src_balance;
    logic [15:0]dst_balance;
    logic [7:0]transaction_id;

    clocking cb @(posedge clk);
        default input #1step output #0;
        output reset, valid, cmd, src_id, dst_id, amount;
        input result_valid, success, error_code, src_balance, dst_balance, transaction_id;
    endclocking

    modport DUT_account_bank_in(
        input reset, valid, cmd, src_id, dst_id, amount,clk
    );

    modport DUT_account_bank_out(
        output result_valid, success, error_code, src_balance, dst_balance, transaction_id
    );

    modport TB(
        clocking cb
    );
endinterface

module account_bank(
    account_if.DUT_account_bank_in bus_in,
    account_if.DUT_account_bank_out bus_out
);
    logic [15:0]current_account[0:3];
    logic [15:0]next_account[0:3];
    logic current_locked[0:3];
    logic next_locked[0:3];
    logic [7:0]current_transaction_id;

    logic next_success;
    logic next_result_valid;
    logic [7:0]next_transaction_id;
    logic [2:0]next_error_code;
    logic [15:0]next_src_balance;
    logic [15:0]next_dst_balance;

    detailed_account_bank u_detailed_account_bank(
        .bus_in(bus_in),
        .current_account(current_account),
        .current_locked(current_locked),
        .current_transaction_id(current_transaction_id),
        .next_account(next_account),
        .next_locked(next_locked),
        .error_code(next_error_code),
        .success(next_success),
        .result_valid(next_result_valid),
        .transaction_id(next_transaction_id),
        .src_balance(next_src_balance),
        .dst_balance(next_dst_balance)
    );

    always_ff @(posedge bus_in.clk) begin
        if(bus_in.reset)begin
            current_account[0] <= 16'd100;
            current_account[1] <= 16'd200;
            current_account[2] <= 16'd300;
            current_account[3] <= 16'd400;

            for(int i=0; i<4; i++)begin
                current_locked[i] <= 1'b0;
            end

            current_transaction_id <= 8'd0;
            bus_out.src_balance <= 16'd0;
            bus_out.dst_balance <= 16'd0;
            bus_out.error_code <= 3'b000;
            bus_out.success <= 1'b0;
            bus_out.result_valid <= 1'b0;
            bus_out.transaction_id <= 8'd0;
        end
        else begin
            for(int i=0; i<4; i++)begin
                current_account[i] <= next_account[i];
                current_locked[i] <= next_locked[i];
            end

            current_transaction_id <= next_transaction_id;
            bus_out.src_balance <= next_src_balance;
            bus_out.dst_balance <= next_dst_balance;
            bus_out.error_code <= next_error_code;
            bus_out.success <= next_success;
            bus_out.result_valid <= next_result_valid;
            bus_out.transaction_id <= next_transaction_id;
        end
    end
endmodule

module detailed_account_bank(
    account_if.DUT_account_bank_in bus_in,
    input logic [15:0]current_account[0:3],
    input logic current_locked[0:3],
    input logic [7:0]current_transaction_id,
    output logic [15:0]next_account[0:3],
    output logic next_locked[0:3],
    output logic [2:0]error_code,
    output logic success,
    output logic result_valid,
    output logic [7:0]transaction_id,
    output logic [15:0]src_balance,
    output logic [15:0]dst_balance
);
    logic [16:0]sum;
    logic interest_overflow;
    logic state_changed;

    always_comb begin
        for(int i=0; i<4; i++)begin
            next_account[i] = current_account[i];
            next_locked[i] = current_locked[i];
        end

        error_code = 3'b000;
        result_valid = bus_in.valid;
        success = 1'b0;
        transaction_id = current_transaction_id;
        sum = 17'd0;
        interest_overflow = 1'b0;
        state_changed = 1'b0;

        if(bus_in.valid)begin
            case(bus_in.cmd)
                3'b000:begin
                    if(current_locked[bus_in.src_id])begin
                        error_code = 3'b010;
                    end
                    else begin
                        sum = {1'b0, current_account[bus_in.src_id]} + {1'b0, bus_in.amount};
                        if(sum[16])begin
                            error_code = 3'b011;
                        end
                        else begin
                            next_account[bus_in.src_id] = sum[15:0];
                            state_changed = 1'b1;
                        end
                    end
                end

                3'b001:begin
                    if(current_locked[bus_in.src_id])begin
                        error_code = 3'b010;
                    end
                    else if(current_account[bus_in.src_id] < bus_in.amount)begin
                        error_code = 3'b001;
                    end
                    else begin
                        next_account[bus_in.src_id] = current_account[bus_in.src_id] - bus_in.amount;
                        state_changed = 1'b1;
                    end
                end

                3'b010:begin
                    if(bus_in.src_id == bus_in.dst_id)begin
                        error_code = 3'b100;
                    end
                    else if(current_locked[bus_in.src_id] || current_locked[bus_in.dst_id])begin
                        error_code = 3'b010;
                    end
                    else if(current_account[bus_in.src_id] < bus_in.amount)begin
                        error_code = 3'b001;
                    end
                    else begin
                        sum = {1'b0, current_account[bus_in.dst_id]} + {1'b0, bus_in.amount};
                        if(sum[16])begin
                            error_code = 3'b011;
                        end
                        else begin
                            next_account[bus_in.src_id] = current_account[bus_in.src_id] - bus_in.amount;
                            next_account[bus_in.dst_id] = sum[15:0];
                            state_changed = 1'b1;
                        end
                    end
                end

                3'b011:begin
                    if(current_locked[bus_in.src_id])begin
                        error_code = 3'b101;
                    end
                    else begin
                        next_locked[bus_in.src_id] = 1'b1;
                        state_changed = 1'b1;
                    end
                end

                3'b100:begin
                    if(!current_locked[bus_in.src_id])begin
                        error_code = 3'b101;
                    end
                    else begin
                        next_locked[bus_in.src_id] = 1'b0;
                        state_changed = 1'b1;
                    end
                end

                3'b101:begin
                    state_changed = 1'b0;
                end

                3'b110:begin
                    for(int i=0; i<4; i++)begin
                        if(!current_locked[i])begin
                            sum = {1'b0, current_account[i]} + {1'b0, current_account[i] >> 4};
                            if(sum[16])begin
                                next_account[i] = 16'hffff;
                                interest_overflow = 1'b1;
                            end
                            else begin
                                next_account[i] = sum[15:0];
                            end
                        end
                    end
                    error_code = interest_overflow ? 3'b011 : 3'b000;
                    state_changed = !interest_overflow;
                end

                3'b111:begin
                    error_code = 3'b110;
                end

                default:begin
                    error_code = 3'b110;
                end
            endcase

            success = (error_code == 3'b000);
            if(success && state_changed)begin
                transaction_id = current_transaction_id + 1'b1;
            end
        end

        src_balance = next_account[bus_in.src_id];
        dst_balance = next_account[bus_in.dst_id];
    end
endmodule

class Transaction;
    rand bit valid;
    rand bit [2:0]cmd;
    rand bit [1:0] src_id;
    rand bit [1:0] dst_id;
    rand bit [15:0]amount;

    constraint rand_Trans{
        valid dist{1'b1 :/ 9, 1'b0 :/ 1};
        cmd dist{[3'b000 : 3'b110] :/ 9, 3'b111 :/ 1};
        amount dist{[16'd0 : 16'd500] :/ 7, [16'd501 : 16'hffff] :/ 3};
    }

    function void print();
        $display("valid: %b, cmd: %b, src_id: %b, dst_id: %b, amount :%0d", valid, cmd, src_id, dst_id, amount);
    endfunction
    
endclass

class Observation;
    logic success;          
    logic [2:0]error_code;
    logic [15:0]src_balance;
    logic [15:0]dst_balance;
    logic [7:0]transaction_id;
    logic result_valid;
endclass

class Generator;
    mailbox #(Transaction)gen2dri;
    Transaction handle;

    function new(mailbox #(Transaction)gen2dri);
        this.gen2dri = gen2dri;
    endfunction

    task run(input int count);
        begin
            repeat(count)begin
                handle = new();
                if(!handle.randomize())begin
                    $fatal(1,"ERROR");
                end
                gen2dri.put(handle);
            end
        end
    endtask
endclass

class Driver;
    virtual account_if.TB vir;
    Transaction handle;
    mailbox #(Transaction)gen2dri;
    mailbox #(Transaction)dri2src;

    function new(virtual account_if.TB vir, mailbox #(Transaction)gen2dri, mailbox #(Transaction)dri2src);
        this.vir = vir;
        this.gen2dri = gen2dri;
        this.dri2src = dri2src;
    endfunction

    task run(input int count);
        begin
            repeat(count)begin
                gen2dri.get(handle);
                vir.cb.valid <= handle.valid;
                vir.cb.cmd <= handle.cmd;
                vir.cb.src_id <= handle.src_id;
                vir.cb.dst_id <= handle.dst_id;
                vir.cb.amount <= handle.amount;
                @(vir.cb);
                dri2src.put(handle);
            end

            vir.cb.valid <= 1'b0;
        end
    endtask

    task reset;
        begin
            vir.cb.reset <= 1;
            vir.cb.valid <= 0;
            vir.cb.cmd <= 0;
            vir.cb.src_id <= 0;
            vir.cb.dst_id <= 0;
            vir.cb.amount <= 0;
            @(vir.cb); @(vir.cb);
            vir.cb.reset <= 0;
        end
    endtask
endclass

class Monitor;
    Observation obs;
    mailbox #(Observation) mon2src;
    virtual account_if.TB vir;

    function new(mailbox #(Observation) mon2src, virtual account_if.TB vir);
        this.mon2src = mon2src;
        this.vir = vir;
    endfunction

    task run(input int count);
        int received;
        begin
            received = 0;

            // The DUT response is registered. Skip the empty pipeline slot
            // that exists before the first driven transaction returns.
            @(vir.cb);
            while(received < count)begin
                @(vir.cb);
                obs = new();
                obs.result_valid = vir.cb.result_valid;
                obs.error_code = vir.cb.error_code;
                obs.success = vir.cb.success;
                obs.src_balance = vir.cb.src_balance;
                obs.dst_balance = vir.cb.dst_balance;
                obs.transaction_id = vir.cb.transaction_id;
                mon2src.put(obs);
                received++;
            end
        end
    endtask
endclass

class Scoreboard;
    Observation obs;
    Transaction tra;
    mailbox #(Observation) mon2src;
    mailbox #(Transaction)dri2src;
    virtual account_if.TB vir;

    logic [15:0]account[0:3];
    logic locked[0:3];
    logic before_locked[0:3];
    logic [2:0]error_code;
    logic [15:0]src_balance, dst_balance;
    logic success;
    logic result_valid;
    logic [7:0]transaction_id;
    logic [16:0]sum;
    logic interest_overflow;
    logic state_changed;

    int PASS = 0;

    function new(mailbox #(Observation) mon2src, mailbox #(Transaction)dri2src, virtual account_if.TB vir);
        this.mon2src = mon2src;
        this.dri2src = dri2src;
        this.vir = vir;
    endfunction

    task run(input int count);
        begin
            for(int i=0; i<4; i++)begin
                locked[i] = 0;
            end

            account[0] = 100;
            account[1] = 200;
            account[2] = 300;
            account[3] = 400;
            error_code = 0;
            success = 0;
            result_valid = 0;
            transaction_id = 0;

            repeat(count)begin
                mon2src.get(obs);
                dri2src.get(tra);

                for(int j=0; j<4; j++)begin
                    before_locked[j] = locked[j];
                end

                error_code = 3'b000;
                success = 1'b0;
                result_valid = tra.valid;
                sum = 17'd0;
                interest_overflow = 1'b0;
                state_changed = 1'b0;

                if(tra.valid)begin
                    case(tra.cmd)
                        3'b000:begin
                            if(locked[tra.src_id])begin
                                error_code = 3'b010;
                            end
                            else begin
                                sum = {1'b0, account[tra.src_id]} + {1'b0, tra.amount};
                                if(sum[16])begin
                                    error_code = 3'b011;
                                end
                                else begin
                                    account[tra.src_id] = sum[15:0];
                                    state_changed = 1'b1;
                                end
                            end
                        end

                        3'b001:begin
                            if(locked[tra.src_id])begin
                                error_code = 3'b010;
                            end
                            else if(account[tra.src_id] < tra.amount) begin
                                error_code = 3'b001;
                            end
                            else begin
                                account[tra.src_id] = account[tra.src_id] - tra.amount;
                                state_changed = 1'b1;
                            end
                        end

                        3'b010:begin
                            if(tra.dst_id == tra.src_id)begin
                                error_code = 3'b100;
                            end
                            else if(locked[tra.src_id] || locked[tra.dst_id])begin
                                error_code = 3'b010;
                            end
                            else if(account[tra.src_id] < tra.amount)begin
                                error_code= 3'b001;
                            end
                            else begin
                                sum = {1'b0, account[tra.dst_id]} + {1'b0, tra.amount};
                                if(sum[16])begin
                                    error_code = 3'b011;
                                end
                                else begin
                                    account[tra.src_id] = account[tra.src_id] - tra.amount;
                                    account[tra.dst_id] = sum[15:0];
                                    state_changed = 1'b1;
                                end
                            end
                        end

                        3'b011:begin
                            if(locked[tra.src_id])begin
                                error_code = 3'b101;
                            end
                            else begin
                                locked[tra.src_id] = 1;
                                state_changed = 1'b1;
                            end
                        end

                        3'b100:begin
                            if(!locked[tra.src_id])begin
                                error_code = 3'b101;
                            end
                            else begin
                                locked[tra.src_id] = 0;
                                state_changed = 1'b1;
                            end
                        end

                        3'b101:begin
                            state_changed = 1'b0;
                        end

                        3'b110:begin
                            for(int x=0; x<4; x++)begin
                                if(locked[x] == 0)begin
                                    sum = {1'b0, account[x]} + {1'b0, account[x] >> 4};
                                    if(sum[16])begin
                                        account[x] = 16'hffff;
                                        interest_overflow = 1'b1;
                                    end
                                    else begin
                                        account[x] = sum[15:0];
                                    end
                                end
                            end
                            error_code = interest_overflow ? 3'b011 : 3'b000;
                            state_changed = !interest_overflow;
                        end

                        3'b111:begin
                            error_code = 3'b110;
                        end

                        default:;
                    endcase

                    success = (error_code == 3'b000);
                    if(success && state_changed)begin
                        transaction_id = transaction_id + 1'b1;
                    end
                end

                src_balance = account[tra.src_id];
                dst_balance = account[tra.dst_id];

                if(obs.result_valid === result_valid &&
                   obs.src_balance === src_balance &&
                   obs.dst_balance === dst_balance &&
                   obs.error_code === error_code &&
                   obs.success === success &&
                   obs.transaction_id === transaction_id)begin
                    PASS++;
                end
                else begin
                    tra.print();
                    $display("%0d passed", PASS);
                    $display("before_locked || accout[0]: %b, accout[1]: %b, accout[2]: %b, accout[3]: %b", before_locked[0], before_locked[1], before_locked[2], before_locked[3]);
                    $display("after_locked || accout[0]: %b, accout[1]: %b, accout[2]: %b, accout[3]: %b", locked[0], locked[1], locked[2], locked[3]);
                    $display("actual: result_valid = %b || expected: result_valid = %b", obs.result_valid, result_valid);
                    $display("actual: success = %b, transaction_id = %0d || expected: success = %b, transaction_id = %0d", obs.success, obs.transaction_id, success, transaction_id);
                    $fatal(1,"actual: src_balance = %0d, dst_balance = %0d, error_code = %b || expect: src_balance = %0d, dst_balance = %0d, error_code = %b", obs.src_balance, obs.dst_balance, obs.error_code, src_balance, dst_balance, error_code);
                end
            end
            $display("PASS: %0d", PASS);
        end
    endtask
endclass

module Top;
    localparam int TEST_COUNT = 200;

    mailbox #(Transaction)gen2dri = new();
    mailbox #(Transaction)dri2src = new();
    mailbox #(Observation) mon2src = new();

    Generator gen;
    Driver dri;
    Monitor mon;
    Scoreboard scr;

    logic clk = 0;
    always #5 clk = ~clk;
    account_if bus(clk);

    account_bank u_account_bank(.bus_in(bus), .bus_out(bus));

    initial begin
        gen = new(gen2dri);
        dri = new(bus, gen2dri, dri2src);
        mon = new(mon2src, bus);
        scr = new(mon2src, dri2src, bus);

        dri.reset();
        fork
            gen.run(TEST_COUNT);
            dri.run(TEST_COUNT);
            mon.run(TEST_COUNT);
            scr.run(TEST_COUNT);
        join
        $finish;
    end
endmodule






