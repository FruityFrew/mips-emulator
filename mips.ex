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
      instr = read_instruction(code, pc)

      case instr do
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

    case next do
      :halt ->
        {:ok, {:out, out}, {:reg, reg}, {:mem, mem}}

      {:out, rs} ->
        IO.puts "PC: #{pc}\t | OUT $#{rs}\n"
        pc = pc + 4
        s = Registers.read(reg, rs)
        out = Out.put(out, s)
        run(pc, code, reg, mem, out)


      {:add, rd, rs, rt} ->
        IO.puts "PC: #{pc}\t | ADD $#{rd}, $#{rs}, $#{rt}"
        pc = pc + 4
        s = Registers.read(reg, rs)
        t = Registers.read(reg, rt)
        d = s + t
        reg = Registers.write(reg, rd, d)
        IO.puts "#{s}($#{rs}) + #{t}($#{rt}) -> #{d}($#{rd})\n"
        run(pc, code, reg, mem, out)


      {:addi, rd, rs, imm} ->
        IO.puts "PC: #{pc}\t | ADDI $#{rd}, $#{rs}, #{imm}"
        pc = pc + 4
        s = Registers.read(reg, rs)
        d = s + imm
        reg = Registers.write(reg, rd, d)
        IO.puts "#{s}($#{rs}) + #{imm} -> #{d}($#{rd})\n"
        run(pc, code, reg, mem, out)


      {:sub, rd, rs, rt} ->
        IO.puts "PC: #{pc}\t | SUB $#{rd}, $#{rs}, $#{rt}"
        pc = pc + 4
        s = Registers.read(reg, rs)
        t = Registers.read(reg, rt)
        d = s - t
        reg = Registers.write(reg, rd, d)
        IO.puts "#{s}($#{rs}) - #{t}($#{rt}) -> #{d}($#{rd})\n"
        run(pc, code, reg, mem, out)


      {:and, rd, rs, rt} ->
        IO.puts "PC: #{pc}\t | AND $#{rd}, $#{rs}, $#{rt}"
        pc = pc + 4
        s = Registers.read(reg, rs)
        t = Registers.read(reg, rt)
        d = Bitwise.and(s, t)
        reg = Registers.write(reg, rd, d)
        IO.puts "#{s}($#{rs}) & #{t}($#{rt}) -> #{d}($#{rd})\n"
        run(pc, code, reg, mem, out)

      {:andi, rd, rs, imm} ->
        IO.puts "PC: #{pc}\t | ANDI $#{rd}, $#{rs}, #{imm}"
        pc = pc + 4
        s = Registers.read(reg, rs)
        d = s + imm
        reg = Registers.write(reg, rd, d)
        IO.puts "#{s}($#{rs}) & #{imm} -> #{d}($#{rd})\n"
        run(pc, code, reg, mem, out)

      {:lw, rd, rt, label} ->
        IO.puts "PC: #{pc}\t | LW $#{rd}, $#{rt}, #{label}\n"
        pc = pc + 4
        t = Registers.read(reg, rt)
        word = Program.find_word(mem, label, 0)
        run(pc, code, reg, mem, out)


      {:sw, rs, rt, offset} ->
        IO.puts "PC: #{pc}\t | SW $#{rs}, (#{offset})$#{rt}\n"
        pc = pc + 4
        s = Registers.read(reg, rs)
        t = Registers.read(reg, rt)
        mem = List.replace_at(mem, t+offset, s)
        run(pc, code, reg, mem, out)


      {:bne, rs, rt, label} ->
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


      {:beq, rs, rt, label} ->
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


      {:label, label} ->
        IO.puts "PC: #{pc}\t | LABEL #{label}\n"
        pc = pc + 4
        run(pc, code, reg, mem, out)


      anything_else ->
        {:error, "Failed to evaluate an expression",
                {:expression, anything_else},
                {:registers, reg},
                {:out, out}
              }
    end
  end
end
