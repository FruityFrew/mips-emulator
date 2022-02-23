defmodule Program do
  def load(prgm) do
    # data = Registers.fill_with_zeros([], 10000)
    data = [[{:label, :arg}, {:word, 12}]]
    {prgm, data}
  end

  def read_instruction(code, pc) do
    i = div(pc, 4)
    Enum.at(code, i)
  end

  def find_label(code, label, pc) do
    if div(pc, 4) >= length(code) do
      IO.puts "Could not found label \"" <> to_string(label) <> "\""
      {:error, label, pc}
    else
      all_instr = read_instruction(code, pc)

      case all_instr do
        {:label, label} ->
          IO.puts "Found label at pc " <> to_string(pc)
          pc
        something_else ->
          find_label(code, label, pc+4)
      end
    end
  end

  def find_word(mem, label, i) do
    segment = Enum.at(mem, i)

    case segment do
      [{:lable, lable}, {_, val}] ->
        val
      :nil ->
        :nil
      anything_else ->
        find_word(mem, label, i+1)
    end
  end
end


defmodule Registers do
  def new() do
    fill_with_zeros([], 32)
  end

  def fill_with_zeros(list, count) do
    if count == 0 do
      []
    else
      [0 | fill_with_zeros(list, count-1)]
    end
  end


  def read(reg, rd) do
    reg |> Enum.at(rd)
  end

  def write(reg, 0, _) do
    reg     # i.e. do nothing
  end

  def write(reg, rd, val) do
    List.replace_at(reg, rd, val)
  end
end


defmodule Out do
  def put(out, val) when is_list(out) do
    IO.puts "Out: #{val}"
    out ++ [val]
  end

  def new() do
    []
  end
end


defmodule Emulator do
  def main() do
    # Test Script
    program = [ {:addi, 1, 0, 5},
                {:lw, 2, 0, :arg},
                {:add, 4, 2, 1},
                {:addi, 5, 0, 1},
                {:label, :loop},
                {:sub, 4, 4, 5},
                {:out, 4},
                {:bne, 4, 0, :loop},
                :halt
              ]

    run(program)
  end


  def run(prgm) do
    {code, data} = Program.load(prgm)

    data = [[{:label, :arg}, {:word, 12}]]

    out = Out.new()
    reg = Registers.new()
    run(0, code, reg, data, out)
  end

  def run(pc, code, reg, mem, out) do
    next = Program.read_instruction(code, pc)

    eval(next, pc, code, reg, mem, out)
  end


  def eval({:out, rs}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | OUT $#{rs}\n"
    pc = pc + 4
    s = Registers.read(reg, rs)
    out = Out.put(out, s)
    run(pc, code, reg, mem, out)
  end
  
  def eval({:add, rd, rs, rt}, pc, code, reg, mem, out) do
      IO.puts "PC: #{pc}\t | ADD $#{rd}, $#{rs}, $#{rt}"
      pc = pc + 4
      s = Registers.read(reg, rs)
      t = Registers.read(reg, rt)
      r = s + t
      reg = Registers.write(reg, rd, r)
      IO.puts "#{s}($#{rs}) + #{t}($#{rt}) -> #{r}($#{rd})\n"
      run(pc, code, reg, mem, out)
  end

  def eval({:addi, rd, rs, imm}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | ADDI $#{rd}, $#{rs}, #{imm}"
    pc = pc + 4
    s = Registers.read(reg, rs)
    r = s + imm
    reg = Registers.write(reg, rd, r)
    IO.puts "#{s}($#{rs}) + #{imm} -> #{r}($#{rd})\n"
    run(pc, code, reg, mem, out)
  end

  def eval({:sub, rd, rs, rt}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | SUB $#{rd}, $#{rs}, $#{rt}"
    pc = pc + 4
    s = Registers.read(reg, rs)
    t = Registers.read(reg, rt)
    r = s - t
    reg = Registers.write(reg, rd, r)
    IO.puts "#{s}($#{rs}) - #{t}($#{rt}) -> #{r}($#{rd})\n"
    run(pc, code, reg, mem, out)
  end

  def eval({:and, rd, rs, rt}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | AND $#{rd}, $#{rs}, $#{rt}"
    pc = pc + 4
    s = Registers.read(reg, rs)
    t = Registers.read(reg, rt)
    r = Bitwise.and(s, t)
    reg = Registers.write(reg, rd, r)
    IO.puts "#{s}($#{rs}) & #{t}($#{rt}) -> #{r}($#{rd})\n"
    run(pc, code, reg, mem, out)
  end

  def eval({:andi, rd, rs, imm}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | ANDI $#{rd}, $#{rs}, #{imm}"
    pc = pc + 4
    s = Registers.read(reg, rs)
    r = s + imm
    reg = Registers.write(reg, rd, r)
    IO.puts "#{s}($#{rs}) & #{imm} -> #{r}($#{rd})\n"
    run(pc, code, reg, mem, out)
  end

  def eval({:lw, rd, rt, label}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | LW $#{rd}, $#{rt}, #{label}\n"
    pc = pc + 4
    t = Registers.read(reg, rt)
    word = Program.find_word(mem, label, 0)
    run(pc, code, reg, mem, out)
  end

  def eval({:sw, rs, rt, offset}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | SW $#{rs}, (#{offset})$#{rt}\n"
    pc = pc + 4
    s = Registers.read(reg, rs)
    t = Registers.read(reg, rt)
    mem = List.replace_at(mem, t+offset, s)
    run(pc, code, reg, mem, out)
  end


  def eval({:bne, rs, rt, label}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | BNE $#{rs}, $#{rt}, #{label}"
    s = Registers.read(reg, rs)
    t = Registers.read(reg, rt)

    IO.puts "$#{rs}(#{s}) != $#{rt}(#{t}) ?"

    if s != t do
      pc = Program.find_label(code, label, 0)
      IO.puts "BRANCHING TO #{label}(PC=#{pc})\n"
      run(pc, code, reg, mem, out)
    else
      IO.puts "NO BRANCHING\n"
      pc = pc + 4
      run(pc, code, reg, mem, out)
    end
  end

  def eval({:beq, rs, rt, label}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | BEQ $#{rs}, $#{rt}, #{label}"
    s = Registers.read(reg, rs)
    t = Registers.read(reg, rt)

    IO.puts "$#{rs}(#{s}) == $#{rt}(#{t}) ?"

    if s == t do
      pc = Program.find_label(code, label, 0)
      IO.puts "BRACHING TO #{label}(PC=#{pc})\n"
      run(pc, code, reg, mem, out)
    else
      IO.puts "NO BRANCHING\n"
      pc = pc + 4
      run(pc, code, reg, mem, out)
    end
  end


  def eval({:label, label}, pc, code, reg, mem, out) do
    IO.puts "PC: #{pc}\t | LABEL #{label}\n"
    pc = pc + 4
    run(pc, code, reg, mem, out)
  end

  def eval(expr, pc, code, reg, mem, out) do
    {:error, "Failed to evaluate an expression",
            {:expression, expr},
            {:registers, reg},
            {:out, out}
    }
  end
end


defmodule Loader do
  def read_file(file_name) do
    case File.read(file_name) do
      {:ok, content} ->
        IO.puts content

      {:error, msg} -> 
        {:error, msg}
    end
  end

  @spec load(String.t) :: list | {atom, String.t}
  def load(file_name) do
    case File.read(file_name) do
      {:ok, content} ->
        filter_script(content)
      
      {:error, msg} ->
        IO.puts "Could not load file \'#{file_name}\'." 
        {:error, msg}

    end
  end

  @spec filter_script(String.t) :: list
  def filter_script(content) do
    content 
    |> String.replace(",", " ")
    |> String.split("\n", trim: true)
    |> Enum.map(fn s -> String.trim(s) end)
    |> Enum.map(fn s -> String.split(s, " ", trim: true) end)
    |> parse_instructions()
  end

  @spec parse_instructions(list) :: list
  def parse_instructions(raw_instructions) do
    all_instr = []
    process_instruction(raw_instructions, all_instr)
  end

  @spec process_instruction([[string]], [tuple]) :: list
  def process_instruction([], all_instr) do all_instr end
  def process_instruction([[_] | rest], all_instr) do
    process_instruction(rest, all_instr)    # Reffers to block types (i.e. .text, .data, etc); ignored for now
  end
  
  def process_instruction([["label", target] | rest], all_instr) do 
    all_instr ++ [{:label, String.to_atom(target)}]
    process_instruction(rest, all_instr)
  end

  def process_instruction([[instr, p] | rest], all_instr) do
    all_instr = all_instr ++ [{String.to_atom(instr), Integer.parse(p)}]
    process_instruction(rest, all_instr)
  end

  def process_instruction([[instr, p, q, r] | rest], all_instr) do
    all_instr = all_instr ++ [{String.to_atom(instr), Integer.parse(p), Integer.parse(q), Integer.parse(r)}]
    process_instruction(rest, all_instr)
  end 
end