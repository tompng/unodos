require 'matrix'
class Infinite < Enumerator
  class Base
    attr_reader :name, :cost, :proc
    def initialize(name, cost, &block)
      @name = name
      @cost = cost
      @proc = block
    end
    def differential_level
      0
    end
  end
  class DifferentialBase
    attr_reader :differential_level
    def initialize(level)
      @differential_level = level
    end
    def cost
      DIFFERENTIAL_BASE_COST
    end
    def name
      "a[i-#{differential_level}]"
    end
  end
  NAMED_BASES = [
    Base.new('1', 1) { |_| 1 },
    Base.new('i', 2) { |i| i },
    Base.new('i**2', 2) { |i| i**2 },
    Base.new('i**3', 2) { |i| i**3 },
    Base.new('i**4', 2) { |i| i**4 },
    Base.new('2**i', 2) { |i| 2**i },
    Base.new('3**i', 2) { |i| 3**i },
    Base.new('4**i', 2) { |i| 4**i },
    Base.new('1/2**i', 3) { |i| 1.0/2**i },
    Base.new('1/3**i', 3) { |i| 1.0/3**i },
    Base.new('1/4**i', 3) { |i| 1.0/4**i }
  ]
  TOLERANCE = 1e-12
  DIFFERENTIAL_BASE_COST = 1
  DIFFERENTIAL_LEVEL_COST = 3

  def lup_solve(lup, b)
    size = b.size
    m = b.values_at(*lup.pivots)
    matl = lup.l
    matu = lup.u
    size.times do |k|
      (k+1).upto(size-1) do |i|
        m[i] -= m[k] * matl[i,k]
      end
    end
    (size-1).downto(0) do |k|
      next if m[k] == 0
      return nil if matu[k,k].zero?
      m[k] = m[k].quo matu[k,k]
      k.times do |i|
        m[i] -= m[k] * matu[i,k]
      end
    end
    m
  end

  def initialize(list)
    @list = list
    min_cost = Float::INFINITY
    result = nil
    list.size.times do |level|
      min_cost, res = solve list, level, min_cost
      result = res || result
    end
    @elements = result.select { |_, v| v != 0 }.map do |(_, _, base), v|
      v = v.to_i if (v.to_i - v).abs < TOLERANCE
      [base, v]
    end
  end

  def inspect
    es = @elements.map.with_index do |(base, v), i|
      v = v.to_i if v.to_i == v
      sgn = v < 0 ? '-' : i == 0 ? '' : '+'
      v = v.abs
      name = base.name
      if name == '1'
        name = nil
      elsif v == 1
        v = nil
      end
      sgn + [*v, *name].join('*')
    end
    "a[i]=#{es.join}"
  end

  def each(&block)
    level = @elements.map(&:first).map(&:differential_level).max
    Enumerator.new do |y|
      differential = [0] * level
      (0..).each do |i|
        v = if i < level
          @list[i]
        else
          @elements.sum do |base, v|
            if base.differential_level > 0
              v * differential[(i - base.differential_level) % level]
            else
              v * base.proc.call(i)
            end
          end
        end
        differential[i % level] = v if level > 0
        y << v
      end
    end.each(&block)
  end

  def solve(list, differential_level, min_cost)
    differential_cost = differential_level * DIFFERENTIAL_LEVEL_COST
    return [min_cost, nil] if differential_cost >= min_cost
    result = nil
    vector_with_info = NAMED_BASES.map do |base|
      vector = list.size.times.map do |i|
        i < differential_level ? 0 : base.proc.call(i)
      end
      [vector, vector.max, base]
    end
    (1..differential_level).each do |level|
      vector = [0] * differential_level + list.take(list.size - level).drop(differential_level - level)
      vector_with_info.unshift [vector, vector.max, DifferentialBase.new(level)]
    end
    list = [0] * differential_level + list.drop(differential_level) if differential_level > 0
    vector_with_info.combination list.size do |combination|
      vectors = combination.map(&:first)
      mat = Matrix[*vectors.transpose]
      vs = lup_solve mat.lup, list
      next unless vs
      rs = combination.zip vs
      rs.each { |r| r[1] = 0 if (r[0][1] * r[1]).abs < TOLERANCE }
      next if differential_level > 0 && rs[0][1] == 0
      cost = rs.sum { |(_, _, base), v| v == 0 ? 0 : base.cost } + differential_cost
      if cost < min_cost
        min_cost = cost
        result = rs
      end
    end
    [min_cost, result]
  end
end

p Infinite.new([1,1,2])
p Infinite.new([1.2,4.4,9.6])
p Infinite.new([1.2,4.4,9.6]).take(10)
p Infinite.new([1,1,2,3,5,8])
p Infinite.new([1,1,2,3,5,8]).take(20)

binding.irb