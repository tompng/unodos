require "test_helper"

def assert_numbers(format, n: 5, start: nil, cost: nil, &block)
  a = [*start]
  check = 4
  unless block
    code = format.gsub(/\//, 'r/').gsub(/\)i/, ').i')
    block = eval "->(n,a){#{code}}"
  end
  (n + check).times { |i| a[i] ||= block.call i, a }
  inf = Unodos[*a.take(n)]
  b = inf.take(a.size)
  assert_equal "a[n]=#{format}", inf.rule if format
  assert_equal a, b
  assert_equal cost, inf.cost if cost
end

def assert_fnumbers(n, &block)
  check = 4
  arr = (n + check).times.map(&block)
  arr2 = Unodos[*arr.take(n)].take(n + check)
  max_diff = arr.zip(arr2).map { |a, b| (a - b).abs }.max
  assert max_diff < 1e-8
end

class UnodosTest < Minitest::Test
  def test_level0
    assert_numbers '3', n: 1, cost: 1
    assert_numbers '4*n', n: 2, cost: 1
    assert_numbers '3*n**2', cost: 1
    assert_numbers '3*2**n', cost: 1
    assert_numbers '3+4*n', n: 3, cost: 2
    assert_numbers '5-3*2**n', n: 3, cost: 2
    assert_numbers '2*n**5+3*2**n', cost: 2
    assert_numbers '2*n**5+3*2**n', cost: 2
    assert_numbers '3*n**2-2*n**3', cost: 2
    assert_numbers '2+4*n-n**2', cost: 3
    assert_numbers '1-n**2+3*2**n', cost: 3
    assert_numbers '3*n**2+4*n**5-2**n', cost: 3
  end

  def test_level1
    assert_numbers '3*a[n-1]', start: [2], cost: 2
    assert_numbers '4*a[n-1]', start: [1], cost: 2
    assert_numbers '3*a[n-1]-5', start: [2], cost: 3
    assert_numbers 'a[n-1]-n**2', start: [1], cost: 3
    assert_numbers '3*a[n-1]+3-n**2', start: [2], cost: 4
    assert_numbers 'a[n-1]-3*n**2+2**n', start: [1], cost: 4
  end

  def test_level2
    assert_numbers '3*a[n-2]', start: [2, 1], cost: 3
    assert_numbers 'a[n-2]+a[n-1]', start: [1, 2], cost: 4
    assert_numbers 'a[n-2]-n**3', start: [1, 0], cost: 4
    assert_numbers '3*a[n-2]-2**n', start: [2, 1], cost: 4
    assert_numbers '5*a[n-2]-2*a[n-1]+3*n**2', n: 6, start: [2, 1], cost: 5
    assert_numbers '3*a[n-2]+2-n**5', n: 6, start: [2, 1], cost: 5
  end

  def test_cycle
    assert_equal [1, 2].cycle.take(10), Unodos[1, 2, 1, 2, 1].take(10)
    assert_equal [1, 2, 3].cycle.take(10), Unodos[1, 2, 3, 1, 2].take(10)
    assert_equal [1, 9, 5, 1, 3, 8].cycle.take(10), Unodos[1, 9, 5, 1, 3, 8, 1, 9].take(10)
    assert_equal [1, 9, 5, 1, 3, 8, 2, 18, 10, 2].cycle.take(10), Unodos[1, 9, 5, 1, 3, 8, 2, 18].take(10)
  end

  def test_worst_case
    [4, 8, 16].each do |n|
      assert_equal n, Unodos[*n.times.map { rand }].cost
    end
  end

  def test_rational
    assert_numbers '(1/2)*n**4', cost: 1
    assert_numbers '(1/2)*n+(3/4)*n**2', cost: 2
    assert_numbers 'a[n-1]+(1/3)*n+(3/4)*n**5', start: [1], cost: 4
    assert_numbers '(3/2)*a[n-1]', start: [1], cost: 2
    assert_numbers '(5/2)*a[n-1]-5/3', start: [2], cost: 3
    assert_numbers '(4/3)*a[n-2]-n**3-(4/5)*n**4', n: 20, start: [2, 1], cost: 5
  end

  def test_complex
    assert_numbers '2i*n', cost: 1
    assert_numbers '(1+(1/2)i)*a[n-1]', start: [1], cost: 2
    assert_numbers '2i*a[n-1]+3/2+4i+(2/3+4i)*n**2', start: [1], cost: 4
    assert_numbers '3+2i+(1+2i)*n', n: 20, cost: 2
  end

  def test_float
    assert_fnumbers(12) { |i| (i + i ** 2) * 0.98 ** i + i ** 3 }
    assert_fnumbers(12) { |i| Math.sin(i) + 0.96 ** i * Math.cos(2.3 * i) }
  end

  def test_minimize
    assert_numbers 'n**4', n: 20, cost: 1
    assert_numbers '2-3*n', n: 20, cost: 2
    assert_numbers '2*n**5-2**n', n: 20, cost: 2
    assert_numbers '-3*n**3+2*n**5', n: 20, cost: 2
    assert_numbers '3-n**4+2**n', n: 20, cost: 3
    assert_numbers '2+n-n**5+2**n', n: 20, cost: 4
    assert_numbers '1+n+n**2+n**3+n**4+n**5+2**n', n: 20, cost: 7
  end

  def test_level1_minimize
    assert_numbers '3*a[n-1]', n: 20, start: [1], cost: 2
    assert_numbers 'a[n-1]+n**4', n: 20, start: [1], cost: 3
    assert_numbers '3*a[n-1]+2*n**2-2**n', n: 20, start: [1], cost: 4
  end

  def test_level2_minimize
    assert_numbers '3*a[n-2]', n: 20, start: [1, 2], cost: 3
    assert_numbers 'a[n-2]+a[n-1]', n: 20, start: [1, 1], cost: 4
    assert_numbers '3*a[n-2]+2*n', n: 20, start: [1, 2], cost: 4
    assert_numbers 'a[n-2]-a[n-1]+n**4', n: 20, start: [1, 0], cost: 5
    assert_numbers '3*a[n-2]+1+n**2', n: 20, start: [2, 1], cost: 5
  end
end
