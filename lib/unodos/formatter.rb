module Unodos::Formatter
  def self.format_rational(n, wrap: false)
    return '0' if n == 0
    return n.inspect unless n.is_a? Rational
    return n.numerator.inspect if n.denominator == 1
    s = "#{n.numerator.abs}/#{n.denominator}"
    s = "(#{s})" if wrap
    s = '-' + s if n < 0
    s
  end

  def self.format(n, wrap: false)
    return '0' if n == 0
    if n.imag == 0
      format_rational n.real, wrap: wrap
    elsif n.real == 0
      format_rational(n.imag, wrap: true) + 'i'
    else
      r = format_rational(n.real)
      i = format_rational(n.imag, wrap: true)
      s = r + (n.imag > 0 ? '+' : '') + i + 'i'
      s = "(#{s})" if wrap
      s
    end
  end
end
