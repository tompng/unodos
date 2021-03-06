require_relative 'base'
module Unodos::Solver
  TOLERANCE = 1e-12
  NAMED_BASES = [
    Unodos::NamedBase.new('1') { |_| 1 },
    Unodos::NamedBase.new('n') { |n| n },
    Unodos::NamedBase.new('n**2') { |n| n**2 },
    Unodos::NamedBase.new('n**3') { |n| n**3 },
    Unodos::NamedBase.new('n**4') { |n| n**4 },
    Unodos::NamedBase.new('n**5') { |n| n**5 }
  ]

  def self.lup_solve(lup, b)
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

  def self.solve(list, differential_level, min_cost)
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
        vector_max_bases.unshift [vector, vector.map(&:abs).max, Unodos::DifferentialBase.new(level)]
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

  def self.match_vector(vector, bvector)
    v, b = vector.zip(bvector).max_by { |a,| a.abs }
    a = b.quo v
    err = vector.zip(bvector).map { |v, b| (v * a - b).abs }.max
    a if err < TOLERANCE
  end

  def self.find_solve(vectors, bvector, &block)
    (1...vectors.size).each do |i|
      least_square_solve [vectors[0], vectors[i]], bvector do |vs, pos|
        block.call vs, pos.map { |c| c == 1 ? i : 0 }
      end
    end
  end

  def self.select_solve(vectors, bvector, max_items, first_required, &block)
    if first_required && max_items == 1
      a = match_vector vectors[0], bvector
      block.call [a], [0] if a
    elsif vectors.size < bvector.size
      least_square_solve vectors, bvector, &block
    elsif first_required && max_items == 2
      find_solve vectors, bvector, &block
    else
      recursive_solve vectors, bvector, first_required, &block
    end
  end

  def self.least_square_solve(vectors, bvector, &block)
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

  def self.recursive_solve(vectors, bvector, first_required, &block)
    size = vectors.size
    out_size = bvector.size
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
