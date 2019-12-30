require_relative 'formatter'
require_relative 'solver'

class Unodos::Infinite < Enumerator
  attr_reader :cost, :elements, :differential_level, :initial
  def initialize(list)
    min_cost = list.size + 1
    result = nil
    list.size.times do |level|
      cost, res = Unodos::Solver.solve list, level, min_cost
      if cost && cost < min_cost
        min_cost = cost
        result = res
      end
    end
    @cost = min_cost
    @elements = result.map do |(_, _, base), v|
      v = v.real.to_i if v.real.to_i == v
      [base, v] if v != 0
    end.compact
    @differential_level = @elements.map(&:first).map(&:differential_level).max
    @initial = list.take(@differential_level)
  end

  def rule
    es = @elements.map.with_index do |(base, v), i|
      sign = i != 0
      name = base.to_s
      s = if name == '1'
        Unodos::Formatter.format v
      elsif v == 1
        name
      elsif v == -1
        '-' + name
      else
        Unodos::Formatter.format(v, wrap: true) + '*' + name
      end
      i == 0 || '-+'.include?(s[0]) ? s : '+' + s
    end
    "a[n]=#{es.join}"
  end

  def inspect
    if differential?
      "[#{[*initial, rule].join(', ')}]"
    else
      rule
    end
  end

  def differential?
    differential_level > 0
  end

  def each(&block)
    Enumerator.new do |y|
      differential = [0] * differential_level
      (0..).each do |i|
        v = if i < differential_level
          initial[i]
        else
          elements.sum do |base, v|
            if base.differential_level > 0
              v * differential[(i - base.differential_level) % differential_level]
            else
              v * base.proc.call(i)
            end
          end
        end
        differential[i % differential_level] = v if differential?
        y << v
      end
    end.each(&block)
  end
end
