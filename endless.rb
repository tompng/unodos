require 'matrix'
class Infinite < Enumerator
  NAMED_BASES = [
    ['1', 1, ->i{1}],
    ['i', 2, ->i{i}],
    ['i**2', 2, ->i{i**2}],
    ['i**3', 2, ->i{i**3}],
    ['i**4', 2, ->i{i**4}],
    ['2**i', 2, ->i{2**i}],
    ['3**i', 2, ->i{3**i}],
    ['4**i', 2, ->i{4**i}],
    ['1/2**i', 3, ->i{1.0/2**i}],
    ['1/3**i', 3, ->i{1.0/3**i}],
    ['1/4**i', 3, ->i{1.0/4**i}]
  ]

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
    @elements = solve(list)
  end

  def inspect
    es = @elements.map.with_index do |((name), v), i|
      v = v.to_i if v.to_i == v
      sgn = v < 0 ? '-' : i == 0 ? '' : '+'
      v = v.abs
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
    Enumerator.new do |y|
      (1..).each do |i|
        y << @elements.sum do |(_, _, proc), v|
          v * proc.call(i)
        end
      end
    end.each(&block)
  end

  def solve(list)
    min_cost = Float::INFINITY
    result = nil
    vector_with_info = NAMED_BASES.map do |item|
      proc = item.last
      vector = list.size.times.map(&proc)
      [vector, vector.max, item]
    end
    vector_with_info.combination list.size do |combination|
      vectors = combination.map(&:first)
      mat = Matrix[*vectors.transpose]
      vs = lup_solve mat.lup, list
      next unless vs
      rs = combination.zip vs
      rs.each { |r| r[1] = 0 if (r[0][1] * r[1]).abs < 1e-12 }
      cost = rs.sum { |(_, c, _), v| v == 0 ? 0 : c }
      if cost < min_cost
        min_cost = cost
        result = rs
      end
    end
    elements = result.select { |_, v| v != 0 }.map do |(_, _, info), v|
      v = v.to_i if (v.to_i - v).abs < 1e-12
      [info, v]
    end
  end
end
