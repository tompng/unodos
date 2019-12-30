module Unodos
  class NamedBase
    attr_reader :name, :proc

    def initialize(name, &block)
      @name = name
      @proc = block
    end

    def differential_level
      0
    end

    alias to_s name
    alias inspect name
  end

  class DifferentialBase
    attr_reader :differential_level
    def initialize(level)
      @differential_level = level
    end

    def to_s
      "a[n-#{differential_level}]"
    end

    alias inspect to_s
  end
end