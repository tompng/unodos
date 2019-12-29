require 'matrix'
class Infinite < Enumerator
  class Base
    attr_reader :name, :proc
    def initialize(name, &block)
      @name = name
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
    def name
      "a[n-#{differential_level}]"
    end
  end
  NAMED_BASES = [
    Base.new('1') { |_| 1 },
    Base.new('n') { |n| n },
    Base.new('n**2') { |n| n**2 },
    Base.new('n**3') { |n| n**3 },
    Base.new('n**4') { |n| n**4 },
    Base.new('n**5') { |n| n**5 },
    Base.new('2**n') { |n| 2**n },
  ]
  TOLERANCE = 1e-12

  def lup_solve(lup, b)
    size = b.size
    m = b.values_at(*lup.pivots)
    mat_l = lup.l
    mat_u = lup.u
    size.times do |k|
      (k + 1).upto(size - 1) do |i|
        m[i] -= m[k] * mat_l[i, k]
      end
    end
    (size - 1).downto(0) do |k|
      next if m[k] == 0
      return nil if mat_u[k, k].zero?
      m[k] = m[k].quo mat_u[k, k]
      k.times do |i|
        m[i] -= m[k] * mat_u[i, k]
      end
    end
    m
  end

  attr_reader :cost
  def initialize(list)
    @list = list
    min_cost = list.size + 1
    result = nil
    list.size.times do |level|
      cost, res = solve list, level, min_cost
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
  end

  def self.[](*list)
    new(list)
  end

  def inspect
    es = @elements.map.with_index do |(base, v), i|
      name = base.name
      if name == '1'
        name = nil
      elsif v == 1
        v = ''
      elsif v == -1
        v = '-'
      end
      s = [*v&.inspect, *name].join('*')
      i == 0 || '-+'[s[0]] ? s : '+' + s
    end
    "a[n]=#{es.join}"
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
    base_cost = differential_level
    max_items = min_cost - base_cost - 1
    return nil if max_items <= 0
    result = nil
    vector_max_bases = NAMED_BASES.map do |base|
      vector = (differential_level..list.size-1).map do |i|
        base.proc.call(i)
      end
      [vector, vector.map(&:abs).max, base]
    end
    if differential_level > 0
      (1..differential_level).each do |level|
        vector = list.take(list.size - level).drop(differential_level - level)
        vector_max_bases.unshift [vector, vector.map(&:abs).max, DifferentialBase.new(level)]
      end
      list = list.drop differential_level
    end
    select_solve vector_max_bases.map(&:first), list, max_items, differential_level > 0 do |vs, pos|
      rs = vector_max_bases.values_at(*pos).zip(vs)
      rs.each { |r| r[1] = 0 if (r[0][1] * r[1]).abs < TOLERANCE }
      next if differential_level > 0 && rs[0][1] == 0
      cost = rs.sum { |(_, _, base), v| v == 0 ? 0 : 1 } + base_cost
      if cost < min_cost
        min_cost = cost
        result = rs
      end
    end
    [min_cost, result] if result
  end

  def match_vector(vector, bvector)
    vv = vb = bb = 0
    vector.zip(bvector).each do |v, b|
      vv += v * v
      vb += v * b
      bb += b * b
    end
    return nil if vv == 0
    a = vb.quo vv
    err = vv * a * a + bb - 2 * a * vb
    [a, err]
  end

  def find_solve(vectors, bvector, &block)
    (1...vectors.size).each do |i|
      least_square_solve [vectors[0], vectors[i]], bvector do |vs, pos|
        block.call vs, pos.map { |c| c == 1 ? i : 0 }
      end
    end
  end

  def select_solve(vectors, bvector, max_items, first_required, &block)
    if first_required && max_items == 1
      a, err = match_vector vectors[0], bvector
      block.call [a], [0] if a && err < TOLERANCE
    elsif vectors.size < bvector.size
      least_square_solve vectors, bvector, &block
    elsif first_required && max_items == 2
      find_solve vectors, bvector, &block
    elsif
      recursive_solve vectors, bvector, first_required, &block
    end
  end

  def least_square_solve(vectors, bvector, &block)
    mat = Matrix[*vectors.transpose]
    tmat = mat.transpose
    m = tmat * mat
    b = tmat * Vector[*bvector]
    vs = lup_solve m.lup, b.to_a
    return unless vs
    max_diff = bvector.each_with_index.map do |bv, i|
      (vectors.zip(vs).sum { |a, v| v * a[i] } - bv).abs
    end.max
    block.call vs, (0...vectors.size).to_a if max_diff < TOLERANCE
  end

  def recursive_solve(vectors, bvector, first_required, &block)
    return least_square_solve vectors, bvector, &block if vectors.size < bvector.size
    size = vectors.size
    out_size = bvector.size
    skip_size = size - out_size
    lup = Matrix[*vectors.transpose].lup
    mat_l = lup.l
    mat_u = lup.u.to_a
    bvector = bvector.values_at(*lup.pivots)
    out_size.times do |k|
      (k + 1).upto(out_size - 1) do |i|
        bvector[i] -= bvector[k] * mat_l[i, k]
      end
    end
    solved = lambda do |u, selected|
      b = bvector.dup
      (selected.size - 1).downto 0 do |i|
        j = selected[i]
        next if b[i] == 0
        return if u[i][j] == 0
        b[i] = b[i].quo u[i][j]
        i.times do |k|
          b[k] -= b[i] * u[k][j]
        end
      end
      block.call b, selected
    end
    solve = lambda do |u, selected, index|
      return solved.call u, selected if selected.size == out_size
      j = selected.size
      restore_index = (j .. [index, out_size - 1].min).max_by do |k|
        u[k][index].abs
      end
      u[j], u[restore_index] = u[restore_index], u[j]
      bvector[j], bvector[restore_index] = bvector[restore_index], bvector[j]
      restore = (j + 1 .. [index, out_size - 1].min).map do |k|
        v = u[j][index] == 0 ? 0 : u[k][index].quo(u[j][index])
        (index + 1 ... size).each do |l|
          u[k][l] -= v * u[j][l]
        end
        bvector[k] -= v * bvector[j]
        [k, v]
      end
      selected.push index
      solve.call u, selected, index + 1
      selected.pop
      restore.reverse_each do |k, v|
        (index + 1 ... size).each do |l|
          u[k][l] += v * u[j][l]
        end
        bvector[k] += v * bvector[j]
      end
      u[j], u[restore_index] = u[restore_index], u[j]
      bvector[j], bvector[restore_index] = bvector[restore_index], bvector[j]
      solve.call u, selected, index + 1 if size - index > out_size - selected.size
    end
    if first_required
      solve.call mat_u, [0], 1
    else
      solve.call mat_u, [], 0
    end
  end
end

p Infinite.new([1,1,2])
p Infinite.new([1.2,4.4,9.6])
p Infinite.new([1.2,4.4,9.6]).take(10)
p Infinite.new([1,1,2,3,5,8])
p Infinite.new([1,1,2,3,5,8]).take(20)
p Infinite.new([1,2,0,1,3])
time = Time.now
10.times { p Infinite.new([1,2,0,1,3,5,9,7,1]) }
# a[i]=97/31*a[i-1]+110165/992-33983/248*i+19303/186*i**2-2927/124*i**3+4261/1488*i**4-918/31*2**i+1025/2976*3**i
p Time.now - time # 5.2
binding.irb
